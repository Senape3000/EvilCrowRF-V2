#ifndef StateCommands_h
#define StateCommands_h

#include "core/ble/CommandHandler.h"
#include "DeviceTasks.h"
#include "core/ble/ControllerAdapter.h"
#include "core/ble/Request.h"
#include "esp_log.h"
#include "config.h"
#include "ConfigManager.h"
#include "BinaryMessages.h"
#include "core/ble/ClientsManager.h"
#include <SD.h>

#if NRF_MODULE_ENABLED
#include "modules/nrf/NrfModule.h"
#include "modules/nrf/NrfJammer.h"
#endif

#if BATTERY_MODULE_ENABLED
#include "modules/battery/BatteryModule.h"
#endif

class StateCommands {
public:
    // Registering all state commands
    static void registerCommands(CommandHandler& handler) {
        ESP_LOGI("StateCommands", "Registering state commands");
        
        handler.registerCommand(0x01, handleGetState);
        handler.registerCommand(0x02, handleRequestScan);
        handler.registerCommand(0x03, handleRequestIdle);
        handler.registerCommand(0x13, handleSetTime);
        handler.registerCommand(0x17, handleSetDeviceName);
        handler.registerCommand(0x15, handleReboot);
        handler.registerCommand(0x16, handleFactoryReset);
        handler.registerCommand(0xC1, handleSettingsUpdate);
        
        ESP_LOGI("StateCommands", "State commands registered successfully");
    }
    
private:
    // Get state — also sends SettingsSync to keep app in sync
    static bool handleGetState(const uint8_t* data, size_t len) {
        ESP_LOGI("StateCommands", "GetState");
        
        Device::TaskGetState task(true);
        ControllerAdapter::sendTask(std::move(task));
        
        // Send current settings to the app (piggybacks on state request)
        sendSettingsSync();

        // Send firmware version so the app can compare for OTA updates
        sendVersionInfo();

        // Send device name to the app
        sendDeviceName();

        // Send battery status if module is enabled
#if BATTERY_MODULE_ENABLED
        if (BatteryModule::isInitialized()) {
            BatteryModule::sendBatteryStatus();
        }
#endif

        // Send HW button config so the app can sync button states
        sendHwButtonStatus();

        // Send SD card storage info
        sendSdStatus();

        // Send nRF24 module status
        sendNrfStatus();
        
        return true;
    }
    
    // Request scan
    static bool handleRequestScan(const uint8_t* data, size_t len) {
        if (len != sizeof(RequestScan)) {
            ESP_LOGW("StateCommands", "Invalid payload size for requestScan");
            return false;
        }
        
        RequestScan request;
        memcpy(&request, data, sizeof(RequestScan));
        
        if (!moduleExists(request.module)) {
            ESP_LOGE("StateCommands", "Invalid module number: %d", request.module);
            return false;
        }
        
        ESP_LOGI("StateCommands", "RequestScan: module=%d, minRssi=%d", request.module, request.minRssi);
        
        Device::TaskDetectSignalBuilder taskBuilder;
        taskBuilder.setModule(request.module);
        taskBuilder.setMinRssi(request.minRssi);
        
        Device::TaskDetectSignal task = taskBuilder.build();
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Request idle
    static bool handleRequestIdle(const uint8_t* data, size_t len) {
        if (len < 1) {
            ESP_LOGW("StateCommands", "Insufficient data for requestIdle");
            return false;
        }
        
        uint8_t module = data[0];
        
        if (!moduleExists(module)) {
            ESP_LOGE("StateCommands", "Invalid module number: %d", module);
            return false;
        }
        
        ESP_LOGI("StateCommands", "RequestIdle: module=%d", module);
        
        Device::TaskIdle task(module);
        ControllerAdapter::sendTask(std::move(task));
        
        return true;
    }
    
    // Set time (Unix timestamp in seconds, 4 bytes little-endian)
    static bool handleSetTime(const uint8_t* data, size_t len) {
        if (len < 4) {
            ESP_LOGW("StateCommands", "Insufficient data for setTime");
            return false;
        }
        
        // Read Unix timestamp (little-endian)
        uint32_t timestamp = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
        
        // Set global time
        extern uint32_t deviceTime;
        deviceTime = timestamp;
        
        ESP_LOGI("StateCommands", "Time set to: %lu (Unix timestamp)", (unsigned long)timestamp);
        
        return true;
    }
    
    // Reboot device
    static bool handleReboot(const uint8_t* data, size_t len) {
        ESP_LOGI("StateCommands", "Rebooting device");
        ESP.restart();
        return true;
    }
    
    // Set BLE device name — payload is the raw ASCII name (1-20 bytes).
    // Takes effect after reboot. Sends confirmation via VersionInfo.
    static bool handleSetDeviceName(const uint8_t* data, size_t len) {
        if (len < 1 || len > MAX_DEVICE_NAME_LEN) {
            ESP_LOGW("StateCommands", "Invalid device name length: %u (must be 1-%u)",
                     (unsigned)len, (unsigned)MAX_DEVICE_NAME_LEN);
            return false;
        }
        if (!ConfigManager::setDeviceName(reinterpret_cast<const char*>(data), len)) {
            ESP_LOGE("StateCommands", "Failed to set device name");
            return false;
        }
        ESP_LOGI("StateCommands", "Device name set to: %s", ConfigManager::settings.deviceName);

        // Send confirmation: reply with command success including the new name
        uint8_t resp[2 + MAX_DEVICE_NAME_LEN];
        resp[0] = 0xF2;  // MSG_COMMAND_SUCCESS
        resp[1] = 0x17;  // echo command ID
        size_t nameLen = strlen(ConfigManager::settings.deviceName);
        memcpy(resp + 2, ConfigManager::settings.deviceName, nameLen);
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::State,
            resp, 2 + nameLen);
        return true;
    }

    // Factory reset — erase all LittleFS data and reboot.
    // Payload: [0x46][0x52] ('FR') as confirmation guard.
    static bool handleFactoryReset(const uint8_t* data, size_t len) {
        // Require 2-byte confirmation payload 'FR' to prevent accidental resets
        if (len < 2 || data[0] != 0x46 || data[1] != 0x52) {
            ESP_LOGW("StateCommands", "Factory reset rejected: missing confirmation bytes 'FR'");
            return false;
        }
        ESP_LOGW("StateCommands", "FACTORY RESET confirmed via BLE/serial");

        // Notify clients before reset
        uint8_t resp[2] = { 0xF2, 0x16 };  // CMD_SUCCESS + cmd id
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::State, resp, sizeof(resp));

        // Give BLE time to send notification, then reset
        vTaskDelay(pdMS_TO_TICKS(300));
        ConfigManager::factoryReset();  // This will reboot
        return true;  // unreachable
    }
    
    // Receive settings update from app and persist
    // Payload: [scannerRssi:int8][bruterPower:u8][delayLo:u8][delayHi:u8][bruterRepeats:u8][radioPowerMod1:int8][radioPowerMod2:int8][cpuTempOffsetLo:u8][cpuTempOffsetHi:u8]
    static bool handleSettingsUpdate(const uint8_t* data, size_t len) {
        if (len < 5) {
            ESP_LOGW("StateCommands", "Insufficient data for settingsUpdate (%u < 5)", (unsigned)len);
            return false;
        }
        if (!ConfigManager::updateFromBle(data, len)) {
            ESP_LOGE("StateCommands", "Failed to update settings from BLE");
            return false;
        }
        ESP_LOGI("StateCommands", "Settings updated from app: rssi=%d power=%d delay=%d reps=%d",
                 ConfigManager::settings.scannerRssi, ConfigManager::settings.bruterPower,
                 ConfigManager::settings.bruterDelay, ConfigManager::settings.bruterRepeats);
        // Echo back the new settings to confirm sync
        sendSettingsSync();
        return true;
    }
    
    // Send firmware version info to all BLE clients.
    // Payload: [0xC2][major][minor][patch] — 4 bytes total.
    static void sendVersionInfo() {
        BinaryVersionInfo vInfo;
        vInfo.major = FIRMWARE_VERSION_MAJOR;
        vInfo.minor = FIRMWARE_VERSION_MINOR;
        vInfo.patch = FIRMWARE_VERSION_PATCH;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::VersionInfo,
            reinterpret_cast<const uint8_t*>(&vInfo), sizeof(vInfo));
        ESP_LOGI("StateCommands", "VersionInfo sent: %d.%d.%d",
                 vInfo.major, vInfo.minor, vInfo.patch);
    }

    // Send current persistent settings to all BLE clients.
    static void sendSettingsSync() {
        uint8_t payload[10];
        ConfigManager::buildSyncPayload(payload);
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SettingsSync, payload, sizeof(payload));
        ESP_LOGI("StateCommands", "SettingsSync sent: rssi=%d power=%d delay=%d reps=%d mod1=%d mod2=%d tempOff=%d",
                 ConfigManager::settings.scannerRssi, ConfigManager::settings.bruterPower,
                 ConfigManager::settings.bruterDelay, ConfigManager::settings.bruterRepeats,
                 ConfigManager::settings.radioPowerMod1, ConfigManager::settings.radioPowerMod2,
                 ConfigManager::settings.cpuTempOffsetDeciC);
    }

    // Send current BLE device name to all clients.
    // Payload: [0xC7][nameLen:1][name...]
    static void sendDeviceName() {
        const char* name = ConfigManager::getDeviceName();
        size_t nameLen = strlen(name);
        uint8_t payload[2 + MAX_DEVICE_NAME_LEN];
        payload[0] = MSG_DEVICE_NAME;
        payload[1] = (uint8_t)nameLen;
        memcpy(payload + 2, name, nameLen);
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::State, payload, 2 + nameLen);
        ESP_LOGI("StateCommands", "DeviceName sent: %s", name);
    }
    
    // Check module existence
    static bool moduleExists(uint8_t module) {
        return module < CC1101_NUM_MODULES;
    }

    // Send HW button configuration to all BLE clients.
    // Allows app to sync button states on connect.
    static void sendHwButtonStatus() {
        BinaryHwButtonStatus status;
        status.btn1Action   = ConfigManager::settings.button1Action;
        status.btn2Action   = ConfigManager::settings.button2Action;
        status.btn1PathType = ConfigManager::settings.button1SignalPathType;
        status.btn2PathType = ConfigManager::settings.button2SignalPathType;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SettingsSync,
            reinterpret_cast<const uint8_t*>(&status), sizeof(status));
        ESP_LOGI("StateCommands", "HwButtonStatus sent: btn1=%d btn2=%d",
                 status.btn1Action, status.btn2Action);
    }

    // Send SD card storage info to all BLE clients.
    static void sendSdStatus() {
        BinarySdStatus status;
        uint64_t totalBytes = SD.totalBytes();
        uint64_t usedBytes  = SD.usedBytes();
        if (totalBytes > 0) {
            status.mounted = 1;
            status.totalMB = (uint16_t)(totalBytes / (1024ULL * 1024ULL));
            status.freeMB  = (uint16_t)((totalBytes - usedBytes) / (1024ULL * 1024ULL));
        } else {
            status.mounted = 0;
            status.totalMB = 0;
            status.freeMB  = 0;
        }
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::State,
            reinterpret_cast<const uint8_t*>(&status), sizeof(status));
        ESP_LOGI("StateCommands", "SdStatus sent: mounted=%d total=%dMB free=%dMB",
                 status.mounted, status.totalMB, status.freeMB);
    }

    // Send nRF24 module status to all BLE clients.
    static void sendNrfStatus() {
        BinaryNrfStatus status;
#if NRF_MODULE_ENABLED
        status.present     = NrfModule::isPresent() ? 1 : 0;
        status.initialized = NrfModule::isInitialized() ? 1 : 0;
        // Determine active state: 0=idle, 1=jamming, 2=scanning, 3=attacking, 4=spectrum
        if (NrfJammer::isRunning()) {
            status.activeState = 1;  // Jamming
        } else {
            status.activeState = 0;  // Idle (scan/attack states set elsewhere)
        }
#else
        status.present     = 0;
        status.initialized = 0;
        status.activeState = 0;
#endif
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::State,
            reinterpret_cast<const uint8_t*>(&status), sizeof(status));
        ESP_LOGI("StateCommands", "NrfStatus sent: present=%d init=%d state=%d",
                 status.present, status.initialized, status.activeState);
    }
};

#endif
