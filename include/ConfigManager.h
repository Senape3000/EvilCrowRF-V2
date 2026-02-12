#ifndef ConfigManager_h
#define ConfigManager_h

#include <LittleFS.h>
#include "esp_log.h"
#include <cstring>

// Maximum length for BLE device name (NimBLE limit is ~29, keep it safe)
static constexpr size_t MAX_DEVICE_NAME_LEN = 20;
static constexpr const char* DEFAULT_DEVICE_NAME = "EvilCrow_RF2";

// Persistent device settings stored in /config.txt on LittleFS.
// WiFi parameters removed — this project uses BLE only.
struct DeviceSettings {
    int serialBaudRate;
    int8_t scannerRssi;       // Scanner RSSI threshold (e.g. -80)
    uint8_t bruterPower;      // Bruter TX power 0-7
    uint16_t bruterDelay;     // Inter-frame gap ms
    uint8_t bruterRepeats;    // Repetitions per code
    int8_t radioPowerMod1;    // CC1101 Module 1 TX power in dBm (-30 to 10)
    int8_t radioPowerMod2;    // CC1101 Module 2 TX power in dBm (-30 to 10)
    // HW Button actions persisted across reboots
    uint8_t button1Action;    // HwButtonAction enum index (0-6)
    uint8_t button2Action;    // HwButtonAction enum index (0-6)
    // NRF24 settings
    uint8_t nrfPaLevel;       // nRF24 PA level: 0=MIN, 1=LOW, 2=HIGH, 3=MAX
    uint8_t nrfDataRate;      // nRF24 data rate: 0=1MBPS, 1=2MBPS, 2=250KBPS
    uint8_t nrfChannel;       // nRF24 default channel (0-125)
    uint8_t nrfAutoRetransmit;// nRF24 auto-retransmit count (0-15)
    // BLE device name (user-configurable, persisted)
    char deviceName[MAX_DEVICE_NAME_LEN + 1];  // null-terminated
};

// Internal flash filesystem for configuration and state.
// All user data (recordings, signals) resides on the SD card.
class ConfigManager
{
  public:
    /// In-memory copy of persistent settings (loaded at boot).
    static inline DeviceSettings settings = {
        .serialBaudRate = 115200,
        .scannerRssi    = -80,
        .bruterPower    = 7,
        .bruterDelay    = 10,
        .bruterRepeats  = 4,
        .radioPowerMod1 = 10,
        .radioPowerMod2 = 10,
        .button1Action  = 0,
        .button2Action  = 0,
        .nrfPaLevel     = 3,   // MAX by default
        .nrfDataRate    = 0,   // 1MBPS default
        .nrfChannel     = 76,  // Default channel 76
        .nrfAutoRetransmit = 5,
        .deviceName     = "EvilCrow_RF2",
    };

    /// Load settings from /config.txt into the in-memory struct.
    /// If the file does not exist, it is created with defaults.
    static void loadSettings()
    {
        if (!LittleFS.exists("/config.txt")) {
            saveSettings();  // Create with defaults
            ESP_LOGI("ConfigManager", "Created default /config.txt");
            return;
        }
        // Parse key=value pairs
        File f = LittleFS.open("/config.txt", "r");
        if (!f) return;
        while (f.available()) {
            String line = f.readStringUntil('\n');
            line.trim();
            if (line.isEmpty() || line.startsWith("#")) continue;
            int eq = line.indexOf('=');
            if (eq < 0) continue;
            String key = line.substring(0, eq);
            String val = line.substring(eq + 1);
            key.trim(); val.trim();

            if (key == "serial_baud_rate")  settings.serialBaudRate = val.toInt();
            else if (key == "scanner_rssi") settings.scannerRssi   = (int8_t)val.toInt();
            else if (key == "bruter_power") settings.bruterPower   = (uint8_t)val.toInt();
            else if (key == "bruter_delay") settings.bruterDelay   = (uint16_t)val.toInt();
            else if (key == "bruter_repeats") settings.bruterRepeats = (uint8_t)val.toInt();
            else if (key == "radio_power_mod1") settings.radioPowerMod1 = (int8_t)val.toInt();
            else if (key == "radio_power_mod2") settings.radioPowerMod2 = (int8_t)val.toInt();
            else if (key == "button1_action") settings.button1Action = (uint8_t)val.toInt();
            else if (key == "button2_action") settings.button2Action = (uint8_t)val.toInt();
            else if (key == "nrf_pa_level") settings.nrfPaLevel = (uint8_t)val.toInt();
            else if (key == "nrf_data_rate") settings.nrfDataRate = (uint8_t)val.toInt();
            else if (key == "nrf_channel") settings.nrfChannel = (uint8_t)val.toInt();
            else if (key == "nrf_auto_retransmit") settings.nrfAutoRetransmit = (uint8_t)val.toInt();
            else if (key == "device_name") {
                strncpy(settings.deviceName, val.c_str(), MAX_DEVICE_NAME_LEN);
                settings.deviceName[MAX_DEVICE_NAME_LEN] = '\0';
            }
            // Unknown keys are silently ignored (forward-compatible)
        }
        f.close();

        // Clamp parsed values to valid ranges (same as updateFromBle)
        if (settings.bruterPower > 7) settings.bruterPower = 7;
        if (settings.bruterDelay < 1) settings.bruterDelay = 1;
        if (settings.bruterDelay > 1000) settings.bruterDelay = 1000;
        if (settings.bruterRepeats < 1) settings.bruterRepeats = 1;
        if (settings.bruterRepeats > 10) settings.bruterRepeats = 10;
        if (settings.radioPowerMod1 < -30) settings.radioPowerMod1 = -30;
        if (settings.radioPowerMod1 > 10)  settings.radioPowerMod1 = 10;
        if (settings.radioPowerMod2 < -30) settings.radioPowerMod2 = -30;
        if (settings.radioPowerMod2 > 10)  settings.radioPowerMod2 = 10;
        if (settings.scannerRssi > -10) settings.scannerRssi = -10;
        if (settings.scannerRssi < -120) settings.scannerRssi = -120;
        // Clamp button actions
        if (settings.button1Action > 6) settings.button1Action = 0;
        if (settings.button2Action > 6) settings.button2Action = 0;
        // Clamp NRF settings
        if (settings.nrfPaLevel > 3) settings.nrfPaLevel = 3;
        if (settings.nrfDataRate > 2) settings.nrfDataRate = 0;
        if (settings.nrfChannel > 125) settings.nrfChannel = 76;
        if (settings.nrfAutoRetransmit > 15) settings.nrfAutoRetransmit = 5;
        // Ensure device name is valid
        if (settings.deviceName[0] == '\0') {
            strncpy(settings.deviceName, DEFAULT_DEVICE_NAME, MAX_DEVICE_NAME_LEN);
            settings.deviceName[MAX_DEVICE_NAME_LEN] = '\0';
        }

        ESP_LOGI("ConfigManager", "Settings loaded: baud=%d rssi=%d power=%d delay=%d reps=%d mod1=%d mod2=%d btn1=%d btn2=%d nrf_pa=%d nrf_dr=%d nrf_ch=%d name=%s",
                 settings.serialBaudRate, settings.scannerRssi,
                 settings.bruterPower, settings.bruterDelay, settings.bruterRepeats,
                 settings.radioPowerMod1, settings.radioPowerMod2,
                 settings.button1Action, settings.button2Action,
                 settings.nrfPaLevel, settings.nrfDataRate, settings.nrfChannel,
                 settings.deviceName);
    }

    /// Persist current in-memory settings to /config.txt.
    static bool saveSettings()
    {
        File f = LittleFS.open("/config.txt", FILE_WRITE);
        if (!f) return false;
        f.printf("serial_baud_rate=%d\n", settings.serialBaudRate);
        f.printf("scanner_rssi=%d\n",     settings.scannerRssi);
        f.printf("bruter_power=%d\n",     settings.bruterPower);
        f.printf("bruter_delay=%d\n",     settings.bruterDelay);
        f.printf("bruter_repeats=%d\n",   settings.bruterRepeats);
        f.printf("radio_power_mod1=%d\n", settings.radioPowerMod1);
        f.printf("radio_power_mod2=%d\n", settings.radioPowerMod2);
        f.printf("button1_action=%d\n",  settings.button1Action);
        f.printf("button2_action=%d\n",  settings.button2Action);
        f.printf("nrf_pa_level=%d\n",    settings.nrfPaLevel);
        f.printf("nrf_data_rate=%d\n",   settings.nrfDataRate);
        f.printf("nrf_channel=%d\n",     settings.nrfChannel);
        f.printf("nrf_auto_retransmit=%d\n", settings.nrfAutoRetransmit);
        f.printf("device_name=%s\n", settings.deviceName);
        f.close();
        ESP_LOGI("ConfigManager", "Settings saved to /config.txt");
        return true;
    }

    /// Apply loaded settings to the runtime modules (bruter, scanner, etc.).
    /// Call AFTER modules are initialized.
    static void applyToRuntime();

    /// Update settings from a BLE binary payload and persist.
    /// Payload: [scannerRssi:int8][bruterPower:u8][bruterDelayLo:u8][bruterDelayHi:u8][bruterRepeats:u8][radioPowerMod1:int8][radioPowerMod2:int8]
    /// Returns true on success. Accepts 5 bytes (legacy) or 7 bytes (with radio power).
    static bool updateFromBle(const uint8_t* data, size_t len)
    {
        if (len < 5) return false;
        settings.scannerRssi   = (int8_t)data[0];
        settings.bruterPower   = data[1];
        settings.bruterDelay   = data[2] | (data[3] << 8);
        settings.bruterRepeats = data[4];
        // Extended payload with radio power per module
        if (len >= 7) {
            settings.radioPowerMod1 = (int8_t)data[5];
            settings.radioPowerMod2 = (int8_t)data[6];
        }
        // Clamp values
        if (settings.bruterPower > 7) settings.bruterPower = 7;
        if (settings.bruterDelay < 1) settings.bruterDelay = 1;
        if (settings.bruterDelay > 1000) settings.bruterDelay = 1000;
        if (settings.bruterRepeats < 1) settings.bruterRepeats = 1;
        if (settings.bruterRepeats > 10) settings.bruterRepeats = 10;
        if (settings.radioPowerMod1 < -30) settings.radioPowerMod1 = -30;
        if (settings.radioPowerMod1 > 10)  settings.radioPowerMod1 = 10;
        if (settings.radioPowerMod2 < -30) settings.radioPowerMod2 = -30;
        if (settings.radioPowerMod2 > 10)  settings.radioPowerMod2 = 10;
        saveSettings();
        applyToRuntime();
        return true;
    }

    /// Build the binary settings payload for BLE sync notification.
    /// Output: [0xC0][scannerRssi:int8][bruterPower:u8][bruterDelayLo:u8][bruterDelayHi:u8][bruterRepeats:u8][radioPowerMod1:int8][radioPowerMod2:int8]
    /// Returns 8 bytes.
    static void buildSyncPayload(uint8_t* out)
    {
        out[0] = 0xC0;  // MSG_SETTINGS_SYNC
        out[1] = (uint8_t)settings.scannerRssi;
        out[2] = settings.bruterPower;
        out[3] = (uint8_t)(settings.bruterDelay & 0xFF);
        out[4] = (uint8_t)((settings.bruterDelay >> 8) & 0xFF);
        out[5] = settings.bruterRepeats;
        out[6] = (uint8_t)settings.radioPowerMod1;
        out[7] = (uint8_t)settings.radioPowerMod2;
    }

    /// Remove current config and recreate defaults.
    static void resetConfigToDefault()
    {
        LittleFS.remove("/config.txt");
        settings = {115200, -80, 7, 10, 4, 10, 10, 0, 0, 3, 0, 76, 5, "EvilCrow_RF2"};
        saveSettings();
    }

    /// Set the BLE device name and persist it.
    /// Returns true on success. Name must be 1-20 ASCII characters.
    static bool setDeviceName(const char* name, size_t len)
    {
        if (len == 0 || len > MAX_DEVICE_NAME_LEN) return false;
        memcpy(settings.deviceName, name, len);
        settings.deviceName[len] = '\0';
        saveSettings();
        ESP_LOGI("ConfigManager", "Device name set to: %s (reboot required)", settings.deviceName);
        return true;
    }

    /// Get the current device name.
    static const char* getDeviceName()
    {
        if (settings.deviceName[0] == '\0') return DEFAULT_DEVICE_NAME;
        return settings.deviceName;
    }

    /// Full factory reset: remove ALL files from LittleFS and reboot.
    /// Removes config, flag files, and any other persisted data.
    static void factoryReset()
    {
        ESP_LOGW("ConfigManager", "FACTORY RESET initiated — erasing LittleFS");
        // Remove known files
        LittleFS.remove("/config.txt");
        LittleFS.remove("/sleep_mode.flag");
        LittleFS.remove("/service_mode.flag");
        // Format entire LittleFS to ensure clean state
        LittleFS.format();
        ESP_LOGW("ConfigManager", "LittleFS formatted. Rebooting...");
        delay(500);  // Allow BLE notification to be sent
        ESP.restart();
    }

    /// Return the entire config file as a plain-text string.
    static String getPlainConfig()
    {
        String configData = "";
        if (LittleFS.exists("/config.txt")) {
            File configFile = LittleFS.open("/config.txt", "r");
            if (configFile) {
                while (configFile.available()) {
                    configData += configFile.readStringUntil('\n');
                    configData += '\n';
                }
                configFile.close();
            }
        }
        return configData;
    }

    static String getConfigParam(const String& param)
    {
        String config = getPlainConfig();
        int paramIndex = config.indexOf(param + "=");
        if (paramIndex != -1) {
            int endIndex = config.indexOf("\n", paramIndex);
            if (endIndex == -1) {  // If no newline is found, this is the last line
                endIndex = config.length();
            }
            String value = config.substring(paramIndex + param.length() + 1, endIndex);
            value.trim();
            return value;
        }
        return "";
    }

    /// Set or clear a boolean flag file on LittleFS.
    static bool setFlag(const char* path, bool value)
    {
        if (value) {
            File flagFile = LittleFS.open(path, FILE_WRITE);
            if (flagFile) {
                flagFile.close();
                return true;
            }
        } else {
            return LittleFS.remove(path);
        }
        return false;
    }

    /// Check whether a flag file exists.
    static bool isFlagSet(const char* path)
    {
        return LittleFS.exists(path);
    }

    static void setSleepMode(bool value)
    {
        setFlag("/sleep_mode.flag", value);
    }

    static void setServiceMode(bool value)
    {
        setFlag("/service_mode.flag", value);
    }

    static bool isSleepMode()
    {
        return isFlagSet("/sleep_mode.flag");
    }

    static bool isServiceMode()
    {
        return isFlagSet("/service_mode.flag");
    }
};

#endif  // ConfigManager_h
