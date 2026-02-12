#ifndef TransmitterCommands_h
#define TransmitterCommands_h

#include "StringBuffer.h"
#include "core/ble/CommandHandler.h"
#include "core/ble/ControllerAdapter.h"
#include "DeviceTasks.h"
#include "StringHelpers.h"
#include "core/ble/ClientsManager.h"
#include "config.h"
#include "modules/CC1101_driver/CC1101_Worker.h"
#include "cstring"

/**
 * Transmission commands using static buffers
 */
class TransmitterCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x06, handleTransmitBinary);
        handler.registerCommand(0x07, handleTransmitFromFile);
        handler.registerCommand(0x11, handleFrequencySearch);
        handler.registerCommand(0x12, handleStartJam); // 0x12 for jamming
    }
    
private:
    
    // Transmit from file
    static bool handleTransmitFromFile(const uint8_t* data, size_t len) {
        ESP_LOGD("TransmitterCommands", "handleTransmitFromFile START, len=%zu", len);
        if (len < 2) {
            uint8_t errBuffer[2] = {MSG_SIGNAL_SEND_ERROR, 1}; // 1=insufficient data
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
            return false;
        }
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        if (len < 2 + pathLength) {
            uint8_t errBuffer[2] = {MSG_SIGNAL_SEND_ERROR, 2}; // 2=path length mismatch
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
            return false;
        }
        std::string filename(reinterpret_cast<const char*>(data + 2), pathLength);
        int module = -1;
        if (len > 2 + pathLength) {
            module = static_cast<int>(data[2 + pathLength]);
        }
        ESP_LOGD("TransmitterCommands", "Parsed filename='%s', pathType=%d, module=%d", filename.c_str(), pathType, module);
        
        // If module not specified, find first idle module
        if (module < 0 || module >= CC1101_NUM_MODULES) {
            module = CC1101Worker::findFirstIdleModule();
            if (module < 0) {
                ESP_LOGW("TransmitterCommands", "No idle module available for transmission");
                uint8_t errBuffer[2] = {MSG_SIGNAL_SEND_ERROR, 4}; // 4=no idle module
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            ESP_LOGI("TransmitterCommands", "Auto-selected idle module %d", module);
        } else {
            // Check if specified module is idle
            if (CC1101Worker::getState(module) != CC1101State::Idle) {
                ESP_LOGW("TransmitterCommands", "Module %d is not idle (state: %d)", module, static_cast<int>(CC1101Worker::getState(module)));
                uint8_t errBuffer[2] = {MSG_SIGNAL_SEND_ERROR, 5}; // 5=module not idle
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
        }
        
        Device::TaskTransmissionBuilder builder(Device::TransmissionType::File);
        builder.setFilename(filename);
        builder.setModule(module);
        builder.setRepeat(1);
        builder.setPathType(pathType);
        Device::TaskTransmission task = builder.build();
        ESP_LOGD("TransmitterCommands", "Queue Device::TaskTransmission: file=%s, module=%d, pathType=%d", filename.c_str(), module, pathType);
        bool sent = ControllerAdapter::sendTask(std::move(task));
        if (!sent) {
            uint8_t errBuffer[260];
            errBuffer[0] = MSG_SIGNAL_SEND_ERROR;
            errBuffer[1] = 3; // 3=failed to post task
            errBuffer[2] = (uint8_t)std::min((size_t)255, filename.length());
            memcpy(errBuffer + 3, filename.c_str(), errBuffer[2]);
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 3 + errBuffer[2]);
        }
        return sent;
    }
    
    // Frequency search
    static bool handleFrequencySearch(const uint8_t* data, size_t len) {
        if (len < 3) {
            return false;
        }
        
        uint8_t module = data[0];
        uint8_t minRssiRaw = data[1];
        uint8_t isBackgroundRaw = data[2];
        
        // Convert RSSI
        int16_t minRssi = minRssiRaw > 100 ? minRssiRaw - 256 : minRssiRaw;
        bool isBackground = isBackgroundRaw == 1;
        
        // Create task
        Device::TaskDetectSignal task = Device::TaskDetectSignalBuilder()
            .setModule(module)
            .setMinRssi(minRssi)
            .setIsBackground(isBackground)
            .build();
        
        ControllerAdapter::sendTask(std::move(task));
        return true;
    }
    
    // Binary data transmission
    static bool handleTransmitBinary(const uint8_t* data, size_t len) {
        // TODO: Implement binary transmission
        return true;
    }
    
    // Start jamming
    // Format: module(1) + frequency(4) + power(1) + patternType(1) + maxDurationMs(4) + cooldownMs(4) + [customPatternLen(1) + customPattern]
    static bool handleStartJam(const uint8_t* data, size_t len) {
        if (len < 15) {
            ESP_LOGW("TransmitterCommands", "Insufficient data for startJam: %zu bytes (need at least 15)", len);
            return false;
        }
        
        int offset = 0;
        uint8_t module = data[offset++];
        if (module >= CC1101_NUM_MODULES) {
            ESP_LOGW("TransmitterCommands", "Invalid module: %d", module);
            return false;
        }
        
        float frequency;
        memcpy(&frequency, data + offset, 4);
        offset += 4;
        
        uint8_t power = data[offset++];
        if (power > 7) {
            ESP_LOGW("TransmitterCommands", "Invalid power: %d (max 7)", power);
            power = 7;
        }
        
        uint8_t patternTypeRaw = data[offset++];
        Device::JamPatternType patternType = static_cast<Device::JamPatternType>(patternTypeRaw);
        if (patternTypeRaw > 3) {
            ESP_LOGW("TransmitterCommands", "Invalid patternType: %d, using Random", patternTypeRaw);
            patternType = Device::JamPatternType::Random;
        }
        
        uint32_t maxDurationMs;
        memcpy(&maxDurationMs, data + offset, 4);
        offset += 4;
        
        uint32_t cooldownMs;
        memcpy(&cooldownMs, data + offset, 4);
        offset += 4;
        
        Device::TaskJamBuilder builder;
        builder.setModule(module)
               .setFrequency(frequency)
               .setPower(power)
               .setPatternType(patternType)
               .setMaxDuration(maxDurationMs)
               .setCooldown(cooldownMs);
        
        // If custom pattern
        if (patternType == Device::JamPatternType::Custom && len > offset) {
            if (len < offset + 1) {
                ESP_LOGW("TransmitterCommands", "Custom pattern length missing");
                return false;
            }
            uint8_t patternLen = data[offset++];
            if (len < offset + patternLen) {
                ESP_LOGW("TransmitterCommands", "Custom pattern data incomplete: need %d bytes, have %zu", patternLen, len - offset);
                return false;
            }
            std::vector<uint8_t> customPattern(data + offset, data + offset + patternLen);
            builder.setCustomPattern(customPattern);
        }
        
        Device::TaskJam task = builder.build();
        ESP_LOGI("TransmitterCommands", "StartJam: module=%d, freq=%.2f, power=%d, pattern=%d, maxDur=%lu, cooldown=%lu",
                 module, frequency, power, patternTypeRaw, maxDurationMs, cooldownMs);
        
        bool sent = ControllerAdapter::sendTask(std::move(task));
        if (!sent) {
            ESP_LOGE("TransmitterCommands", "Failed to queue jam task");
        }
        return sent;
    }
};

#endif // TransmitterCommands_h
