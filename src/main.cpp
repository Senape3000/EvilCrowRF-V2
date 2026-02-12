#include <Arduino.h>
#include <freertos/event_groups.h>
#include <freertos/semphr.h>
// #include <sstream>  // Removed — unused, saves ~2-4KB rodata
#include "core/ble/CommandHandler.h"
#include "FileCommands.h"
#include "TransmitterCommands.h"
#include "RecorderCommands.h"
#include "StateCommands.h"
#include "BruterCommands.h"
#include "NrfCommands.h"
#include "OtaCommands.h"
#include "ButtonCommands.h"
#include "SdrCommands.h"
#include "AllProtocols.h"
#include "modules/bruter/bruter_main.h"
#include "core/ble/ClientsManager.h"
#include "ConfigManager.h"
#include "core/device_controls/DeviceControls.h"
#include "FS.h"
#include <LittleFS.h>
#include "SD.h"
#include "SPI.h"
#include "core/ble/BleAdapter.h"
#include "config.h"
#include "esp_log.h"
#include "modules/CC1101_driver/CC1101_Module.h"
#include "BinaryMessages.h"
#include "modules/CC1101_driver/CC1101_Worker.h"
#include "modules/nrf/NrfModule.h"
#include "modules/nrf/MouseJack.h"
#include "modules/nrf/NrfJammer.h"
#include "driver/gpio.h"

#if BATTERY_MODULE_ENABLED
#include "modules/battery/BatteryModule.h"
#endif

#if SDR_MODULE_ENABLED
#include "modules/sdr/SdrModule.h"
#endif

static const char* TAG = "Setup";

// Constants
const int MAX_RETRIES = 5;

static void setupCc1101Pins()
{
    // Ensure CC1101 SPI pins are configured as GPIO before any digitalWrite
    pinMode(CC1101_SCK, OUTPUT);
    pinMode(CC1101_MOSI, OUTPUT);
    pinMode(CC1101_MISO, INPUT);
    pinMode(CC1101_SS0, OUTPUT);
    pinMode(CC1101_SS1, OUTPUT);
}

// Global variables
bool bleAdapterStarted = false;
BleAdapter bleAdapter;

// Device time (Unix timestamp in seconds, updated by time sync task)
uint32_t deviceTime = 0;

SPIClass sdspi(VSPI);

// REMOVED - old static task buffers (no longer needed with worker architecture)
// CC1101Worker uses its own static allocation

// Forward declarations
void signalRecordedHandler(bool saved, const std::string& filename);
void timeSyncTask(void* pvParameters);

// Heap monitoring helper
void logHeapStats(const char* context) {
    size_t freeHeap = ESP.getFreeHeap();
    size_t largestBlock = heap_caps_get_largest_free_block(MALLOC_CAP_DEFAULT);
    size_t minFreeHeap = ESP.getMinFreeHeap();
    
    // Calculate fragmentation percentage
    float fragmentation = 0.0f;
    if (freeHeap > 0) {
        fragmentation = 100.0f * (1.0f - (float)largestBlock / (float)freeHeap);
    }
    
    ESP_LOGI("Heap", "[%s] Free: %d, Largest: %d, MinFree: %d, Frag: %.1f%%",
             context, freeHeap, largestBlock, minFreeHeap, fragmentation);
    
    // Warning if fragmentation is high
    if (fragmentation > 30.0f) {
        ESP_LOGW("Heap", "High fragmentation detected: %.1f%%", fragmentation);
    }
    
    // Warning if largest block is smaller than task stack sizes
    if (largestBlock < 4096) {
        ESP_LOGW("Heap", "Largest block (%d) < RecordTask stack (4096) - would fail with dynamic allocation!", largestBlock);
    }
    if (largestBlock < 3072) {
        ESP_LOGW("Heap", "Largest block (%d) < DetectTask stack (3072) - would fail with dynamic allocation!", largestBlock);
    }
}

// Apply persistent settings to bruter and scanner runtime.
// Called at boot after module init, and on BLE settings update.
void ConfigManager::applyToRuntime() {
    BruterModule& bruter = getBruterModule();
    bruter.setInterFrameDelay(settings.bruterDelay);
    if (settings.bruterRepeats >= 1 && settings.bruterRepeats <= BRUTER_MAX_REPETITIONS) {
        bruter.setGlobalRepeats(settings.bruterRepeats);
    }
    // Apply radio TX power for both CC1101 modules
    extern ModuleCc1101 moduleCC1101State[CC1101_NUM_MODULES];
    moduleCC1101State[0].setPA(settings.radioPowerMod1);
    moduleCC1101State[1].setPA(settings.radioPowerMod2);
    ESP_LOGI("ConfigManager", "Runtime settings applied: delay=%dms reps=%d mod1_pwr=%ddBm mod2_pwr=%ddBm",
             settings.bruterDelay, settings.bruterRepeats,
             settings.radioPowerMod1, settings.radioPowerMod2);
}

// Global objects (moved from Actions.cpp)
ClientsManager& clients = ClientsManager::getInstance();

// REMOVED: deviceModes - no longer needed with worker architecture
// Cc1101Mode deviceModes[] = {...};

// Handler functions (moved from Actions.cpp)
void signalRecordedHandler(bool saved, const std::string& filename)
{
    if (saved) {
        BinarySignalRecorded msg;
        msg.module = 0; // Default
        msg.filenameLength = (uint8_t)std::min((size_t)255, filename.length());
        
        static uint8_t buffer[260];
        memcpy(buffer, &msg, sizeof(BinarySignalRecorded));
        memcpy(buffer + sizeof(BinarySignalRecorded), filename.c_str(), msg.filenameLength);
        
        clients.notifyAllBinary(NotificationType::SignalRecorded, buffer, sizeof(BinarySignalRecorded) + msg.filenameLength);
    } else {
        // Send as binary error
        static uint8_t errBuffer[260];
        errBuffer[0] = MSG_ERROR;
        errBuffer[1] = 10; // Error code for record failed
        std::string errMsg = "Failed to save file: " + filename;
        uint8_t msgLen = (uint8_t)std::min((size_t)255, errMsg.length());
        memcpy(errBuffer + 2, errMsg.c_str(), msgLen);
        clients.notifyAllBinary(NotificationType::FileSystem, errBuffer, 2 + msgLen);
    }
}

// Adapter for CC1101Worker detected signal callback
void cc1101WorkerSignalDetectedHandler(const CC1101DetectedSignal& signal)
{
    ESP_LOGI("Main", "Signal detected: rssi=%d, freq=%.2f, module=%d", 
             signal.rssi, signal.frequency, signal.module);
    
    BinarySignalDetected msg;
    msg.module = signal.module;
    msg.frequency = (uint32_t)(signal.frequency * 1000000); // MHz to Hz
    msg.rssi = signal.rssi;
    msg.samples = 0;
    
    clients.notifyAllBinary(NotificationType::SignalDetected, reinterpret_cast<const uint8_t*>(&msg), sizeof(BinarySignalDetected));
}

// REMOVED - signalDetectedHandler (Detector functionality moved to CC1101Worker)

// REMOVED - old state machine callback
// void onStateChange(int module, OperationMode mode, OperationMode previousMode) { }

// BLE parameters - no longer needed

// Device settings
struct DeviceConfig
{
    bool powerBlink;
} deviceConfig;

// REMOVED - old state machine task (all code deleted, now using CC1101Worker)

void taskProcessor(void* pvParameters)
{
    if (ControllerAdapter::xTaskQueue == nullptr) {
        ESP_LOGE(TAG, "Task queue not found");
        vTaskDelete(nullptr);  // Remove task
    }
    QueueItem* item;
    while (true) {
        if (xQueueReceive(ControllerAdapter::xTaskQueue, &item, portMAX_DELAY)) {
            switch (item->type) {
                case Device::TaskType::Transmission: {
                    Device::TaskTransmission& task = item->transmissionTask;
                    ESP_LOGI(TAG, "Processing transmission task for module %d", task.module);
                    
                    if (task.filename) {
                        // Send command to CC1101Worker
                        int repeat = task.repeat ? *task.repeat : 1;
                        if (CC1101Worker::transmit(task.module, *task.filename, repeat, task.pathType)) {
                            BinarySignalSent msg;
                            msg.module = task.module;
                            msg.filenameLength = (uint8_t)std::min((size_t)255, task.filename->length());
                            
                            static uint8_t buffer[260];
                            memcpy(buffer, &msg, sizeof(BinarySignalSent));
                            memcpy(buffer + sizeof(BinarySignalSent), task.filename->c_str(), msg.filenameLength);
                            clients.notifyAllBinary(NotificationType::SignalSent, buffer, sizeof(BinarySignalSent) + msg.filenameLength);
                        } else {
                            BinarySignalSendError msg;
                            msg.module = task.module;
                            msg.errorCode = 1; // Failed to queue
                            msg.filenameLength = (uint8_t)std::min((size_t)255, task.filename->length());
                            
                            static uint8_t buffer[260];
                            memcpy(buffer, &msg, sizeof(BinarySignalSendError));
                            memcpy(buffer + sizeof(BinarySignalSendError), task.filename->c_str(), msg.filenameLength);
                            clients.notifyAllBinary(NotificationType::SignalSendingError, buffer, sizeof(BinarySignalSendError) + msg.filenameLength);
                        }
                    } else {
                        // Raw transmission
                        ESP_LOGI(TAG, "Raw transmission not implemented yet");
                    }
                } break;
                
                case Device::TaskType::Record: {
                    Device::TaskRecord& task = item->recordTask;
                    ESP_LOGI(TAG, "Processing record task for module %d", task.module ? *task.module : 0);
                    
                    if (task.module) {
                        int module = *task.module;
                        std::string errorMessage;
                        
                        float frequency = task.config.frequency;
                        int modulation = MODULATION_ASK_OOK;
                        float deviation = 2.380371;
                        float bandwidth = 650;
                        float dataRate = 3.79372;
                        std::string preset = "Ook650";
                        
                        // Check if preset is provided
                        if (task.config.preset) {
                            preset = *task.config.preset;
                            ESP_LOGI(TAG, "Applying preset: '%s' (length=%zu)", preset.c_str(), preset.length());
                            
                            // Match presets exactly as sent from Flutter app
                            // Expected values: "Ook270", "Ook650", "2FSKDev238", "2FSKDev476"
                            if (preset == "Ook270") {
                                modulation = MODULATION_ASK_OOK;
                                deviation = 2.380371;
                                bandwidth = 270.833333;
                                dataRate = 3.79372;
                            } else if (preset == "Ook650") {
                                modulation = MODULATION_ASK_OOK;
                                deviation = 2.380371;
                                bandwidth = 650;
                                dataRate = 3.79372;
                            } else if (preset == "2FSKDev238") {
                                modulation = MODULATION_2_FSK;
                                deviation = 2.380371;
                                bandwidth = 270.833333;
                                dataRate = 4.79794;
                            } else if (preset == "2FSKDev476") {
                                modulation = MODULATION_2_FSK;
                                deviation = 47.60742;
                                bandwidth = 270.833333;
                                dataRate = 4.79794;
                            } else {
                                errorMessage = "{\"error\":\"Can not apply record configuration. Unsupported preset " + preset + "\"}";
                                ESP_LOGE(TAG, "Unsupported preset: %s", preset.c_str());
                            }
                        } else {
                            // Use custom parameters
                            modulation = task.config.modulation ? *task.config.modulation : MODULATION_ASK_OOK;
                            bandwidth = task.config.rxBandwidth ? *task.config.rxBandwidth : 650;
                            deviation = task.config.deviation ? *task.config.deviation : 47.60742;
                            dataRate = task.config.dataRate ? *task.config.dataRate : 4.79794;
                            preset = "Custom";
                        }
                        
                        if (errorMessage.empty()) {
                            // Send command to CC1101Worker
                            if (CC1101Worker::startRecord(module, frequency, modulation, deviation, bandwidth, dataRate, preset)) {
                                ESP_LOGI(TAG, "Recording started on module %d", module);
                            } else {
                                static uint8_t errBuffer[2];
                                errBuffer[0] = MSG_ERROR;
                                errBuffer[1] = 11; // Error code for record start failed
                                clients.notifyAllBinary(NotificationType::SignalRecordError, errBuffer, 2);
                            }
                        } else {
                            static uint8_t errBuffer[260];
                            errBuffer[0] = MSG_ERROR;
                            errBuffer[1] = 12; // Error code for preset application failed
                            uint8_t msgLen = (uint8_t)std::min((size_t)255, errorMessage.length());
                            memcpy(errBuffer + 2, errorMessage.c_str(), msgLen);
                            clients.notifyAllBinary(NotificationType::SignalRecordError, errBuffer, 2 + msgLen);
                        }
                    }
                } break;
                
                case Device::TaskType::DetectSignal: {
                    Device::TaskDetectSignal& task = item->detectSignalTask;
                    
                    if (task.module && task.minRssi) {
                        int minRssi = *task.minRssi;
                        int module = *task.module;
                        bool isBackground = task.background ? *task.background : false;
                        
                        // Send command to CC1101Worker
                        if (CC1101Worker::startDetect(module, minRssi, isBackground)) {
                            ESP_LOGI(TAG, "Detection started on module %d", module);
                        } else {
                            ESP_LOGE(TAG, "Failed to start detection on module %d", module);
                        }
                    }
                } break;
                
                case Device::TaskType::GetState: {
                    Device::TaskGetState& task = item->getStateTask;
                    ESP_LOGI(TAG, "Processing get state task");
                    
                    const byte numRegs = 0x2E;

                    // Create BinaryStatus structure with CC1101 registers
                    BinaryStatus status;
                    status.messageType = MSG_STATUS;
                    status.module0Mode = static_cast<uint8_t>(CC1101Worker::getState(0));
                    status.module1Mode = static_cast<uint8_t>(CC1101Worker::getState(1));
                    status.numRegisters = numRegs; // 0x00 to 0x2E (46 registers)
                    status.freeHeap = ESP.getFreeHeap();
                    
                    // Read all CC1101 registers for both modules
                    moduleCC1101State[0].readAllConfigRegisters(status.module0Registers, numRegs);
                    moduleCC1101State[1].readAllConfigRegisters(status.module1Registers, numRegs);
                    
                    // Send binary status
                    clients.notifyAllBinary(NotificationType::State, reinterpret_cast<const uint8_t*>(&status), sizeof(BinaryStatus));
                } break;
                
                case Device::TaskType::Jam: {
                    Device::TaskJam& task = item->jamTask;
                    ESP_LOGI(TAG, "Processing jam task for module %d", task.module);
                    
                    const std::vector<uint8_t>* customPatternPtr = task.customPattern ? task.customPattern.get() : nullptr;
                    
                    // Send command to CC1101Worker (power is already 0-7, no conversion needed)
                    if (CC1101Worker::startJam(task.module, task.frequency, task.power, 
                                               task.patternType, customPatternPtr, 
                                               task.maxDurationMs, task.cooldownMs)) {
                        ESP_LOGI(TAG, "Jam started on module %d", task.module);
                    } else {
                        ESP_LOGE(TAG, "Failed to start jam on module %d", task.module);
                    }
                } break;
                
                case Device::TaskType::Idle: {
                    Device::TaskIdle& task = item->idleTask;
                    ESP_LOGI(TAG, "Processing idle task for module %d", task.module);
                    
                    // Send command to CC1101Worker (it will handle jamming state internally)
                    if (CC1101Worker::goIdle(task.module)) {
                        ESP_LOGI(TAG, "Module %d set to idle", task.module);
                    } else {
                        ESP_LOGE(TAG, "Failed to set module %d to idle", task.module);
                    }
                } break;
                default:
                    break;
            }
            
            // CRITICAL: Delete the QueueItem after processing to prevent memory leak
            delete item;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

// Serial command processing task - reads binary commands from Serial and processes them
void serialCommandTask(void* pvParameters) {
    static uint8_t buffer[512]; // Buffer for incoming data
    static size_t bufferIndex = 0;
    
    while (true) {
        if (Serial.available()) {
            uint8_t byte = Serial.read();
            buffer[bufferIndex++] = byte;

            // Handle simple raw commands (non-framed) to avoid race with loop()
            if (bufferIndex >= 1 && buffer[0] != 0xAA) {
                uint8_t command = buffer[0];
                size_t consumed = 1;

                if (command == 0x04) {
                    if (bufferIndex < 2) {
                        continue; // Wait for menu choice byte
                    }
                    uint8_t menuChoice = buffer[1];
                    consumed = 2;

                    if (menuChoice == 0) {
                        // Cancel (stop) running attack
                        BruterModule& bruter = getBruterModule();
                        bruter.cancelAttack();
                        Serial.write((uint8_t)0xF2); // MSG_COMMAND_SUCCESS
                    } else if (menuChoice == 0xFB) {
                        // Pause running attack
                        BruterModule& bruter = getBruterModule();
                        if (bruter.isAttackRunning()) {
                            bruter.pauseAttack();
                            Serial.write((uint8_t)0xF2);
                        } else {
                            Serial.write((uint8_t)0xF3);
                            Serial.write((uint8_t)5); // Nothing to pause
                        }
                    } else if (menuChoice == 0xFA) {
                        // Resume from saved state
                        BruterModule& bruter = getBruterModule();
                        if (bruter.isAttackRunning() || BruterModule::attackTaskHandle != nullptr) {
                            Serial.write((uint8_t)0xF3);
                            Serial.write((uint8_t)4); // Already running
                        } else {
                            Serial.write((uint8_t)0xF2);
                            if (!bruter.resumeAttackAsync()) {
                                ESP_LOGE("Serial", "Resume failed — no saved state");
                            }
                        }
                    } else if (menuChoice == 0xF9) {
                        // Query saved state
                        BruterModule& bruter = getBruterModule();
                        bruter.checkAndNotifySavedState();
                        Serial.write((uint8_t)0xF2);
                    } else if (menuChoice == 0xFE) {
                        // Set inter-frame delay: [0x04][0xFE][delayLo][delayHi]
                        if (bufferIndex < 4) {
                            continue; // Wait for delay bytes
                        }
                        consumed = 4;
                        uint16_t delayMs = buffer[2] | (buffer[3] << 8);
                        BruterModule& bruter = getBruterModule();
                        bruter.setInterFrameDelay(delayMs);
                        ESP_LOGI("Serial", "Inter-frame delay set to %d ms", delayMs);
                        Serial.write((uint8_t)0xF2);
                    } else if (menuChoice == 0xFC) {
                        // Set global repeats: [0x04][0xFC][repeats]
                        if (bufferIndex < 3) {
                            continue; // Wait for repeats byte
                        }
                        consumed = 3;
                        uint8_t repeats = buffer[2];
                        if (repeats >= 1 && repeats <= BRUTER_MAX_REPETITIONS) {
                            BruterModule& bruter = getBruterModule();
                            bruter.setGlobalRepeats(repeats);
                            ESP_LOGI("Serial", "Global repeats set to %d", repeats);
                            Serial.write((uint8_t)0xF2);
                        } else {
                            Serial.write((uint8_t)0xF3);
                            Serial.write((uint8_t)3); // Out of range
                        }
                    } else if (menuChoice >= 1 && menuChoice <= 40) {
                        BruterModule& bruter = getBruterModule();

                        // Reject if already running
                        if (bruter.isAttackRunning() || BruterModule::attackTaskHandle != nullptr) {
                            Serial.write((uint8_t)0xF3); // MSG_COMMAND_ERROR
                            Serial.write((uint8_t)4);    // Already running
                        } else {
                            // Send success immediately
                            Serial.write((uint8_t)0xF2); // MSG_COMMAND_SUCCESS

                            // Launch async attack (same static task used by BLE path)
                            if (!bruter.startAttackAsync(menuChoice)) {
                                ESP_LOGE("Serial", "Failed to create bruter task");
                            }
                        }
                    } else {
                        Serial.write((uint8_t)0xF3); // MSG_COMMAND_ERROR
                        Serial.write((uint8_t)2);    // Invalid choice
                    }
                } else if (command == 0x01) {
                    Serial.write((uint8_t)0xF2); // MSG_COMMAND_SUCCESS (ping)
                }
#if SDR_MODULE_ENABLED
                // SDR text command mode: printable ASCII
                // Accept text commands even when SDR is not yet active so
                // that PC tools can send "sdr_enable" to bootstrap the mode.
                else if (command >= 0x20 && command < 0x80) {
                    // Accumulate text until newline
                    bool gotNewline = false;
                    for (size_t idx = 0; idx < bufferIndex; idx++) {
                        if (buffer[idx] == '\n' || buffer[idx] == '\r') {
                            gotNewline = true;
                            consumed = idx + 1;
                            // Skip trailing \r or \n
                            while (consumed < bufferIndex &&
                                   (buffer[consumed] == '\n' || buffer[consumed] == '\r')) {
                                consumed++;
                            }
                            break;
                        }
                    }
                    if (!gotNewline) {
                        // Need more data — keep accumulating
                        continue;
                    }
                    // Extract command string (exclude trailing newlines)
                    size_t cmdLen = consumed;
                    while (cmdLen > 0 && (buffer[cmdLen - 1] == '\n' || buffer[cmdLen - 1] == '\r')) {
                        cmdLen--;
                    }
                    String sdrCmd;
                    sdrCmd.reserve(cmdLen);
                    for (size_t c = 0; c < cmdLen; c++) {
                        sdrCmd += (char)buffer[c];
                    }
                    // Process SDR text command
                    if (!SdrModule::processSerialCommand(sdrCmd)) {
                        Serial.println("HACKRF_ERROR");
                        Serial.println("Unknown command: " + sdrCmd);
                    }
                }
#endif // SDR_MODULE_ENABLED
                else {
                    Serial.write((uint8_t)0xF3); // MSG_COMMAND_ERROR
                    Serial.write((uint8_t)1);    // Unknown command
                }

                size_t remaining = bufferIndex - consumed;
                if (remaining > 0) {
                    memmove(buffer, buffer + consumed, remaining);
                }
                bufferIndex = remaining;
                continue;
            }
            
            // Check if we have a complete packet (minimum 8 bytes: header + checksum)
            if (bufferIndex >= 8) {
                // Check for magic byte at start
                if (buffer[0] == 0xAA) {
                    // Extract data length (little-endian, bytes 5-6)
                    uint16_t dataLen = buffer[5] | (buffer[6] << 8);
                    uint16_t expectedLen = 7 + dataLen + 1; // header + data + checksum
                    
                    if (bufferIndex >= expectedLen) {
                        // Process the complete packet
                        bleAdapter.setSerialCommand(true);
                        bleAdapter.processBinaryData(buffer, expectedLen);
                        
                        // Shift remaining data to start of buffer
                        size_t remaining = bufferIndex - expectedLen;
                        if (remaining > 0) {
                            memmove(buffer, buffer + expectedLen, remaining);
                        }
                        bufferIndex = remaining;
                    }
                } else {
                    // Invalid magic, reset buffer
                    bufferIndex = 0;
                }
            }
            
            // Prevent buffer overflow
            if (bufferIndex >= sizeof(buffer)) {
                bufferIndex = 0;
            }
        } else {
            vTaskDelay(pdMS_TO_TICKS(10)); // Small delay when no data
        }
    }
}

void setup()
{
    ESP_LOGD(TAG, "Starting LittleFS");
    if (!LittleFS.begin(false, "/littlefs", 10, "littlefs")) {
        ESP_LOGW(TAG, "LittleFS mount failed, attempting to format...");
        if (!LittleFS.begin(true, "/littlefs", 10, "littlefs")) {
            ESP_LOGE(TAG, "LittleFS format failed!");
            return;
        }
        ESP_LOGI(TAG, "LittleFS formatted successfully");
    } else {
        ESP_LOGI(TAG, "LittleFS mounted successfully");
    }

    // Load persistent settings from /config.txt (or create defaults).
    // Must happen BEFORE Serial.begin() since baud rate comes from config.
    ConfigManager::loadSettings();

    int serialBaud = ConfigManager::settings.serialBaudRate;
    Serial.begin(serialBaud);

    setupCc1101Pins();

    // Ensure ESP log output level (override build flag if needed)
    esp_log_level_set("*", ESP_LOG_INFO);
    // Confirm serial is working
    Serial.printf("Serial started at %d bps\n", serialBaud);

    // Ensure GPIO ISR service is available for detachInterrupt usage
    static bool isrServiceReady = false;
    if (!isrServiceReady) {
        esp_err_t isrResult = gpio_install_isr_service(0);
        if (isrResult == ESP_OK || isrResult == ESP_ERR_INVALID_STATE) {
            isrServiceReady = true;
        } else {
            ESP_LOGE(TAG, "GPIO ISR service install failed: %d", (int)isrResult);
        }
    }

    DeviceControls::setup();
    DeviceControls::onLoadPowerManagement();
    DeviceControls::onLoadServiceMode();

    if (ConfigManager::isServiceMode()) {
        // ServiceMode::serviceModeStart();  // ServiceMode.h not found - functionality may be in DeviceControls
        return;
    }

    ESP_LOGD(TAG, "Starting setup...");

    sdspi.begin(SD_SCLK, SD_MISO, SD_MOSI, SD_SS);
    if (!SD.begin(SD_SS, sdspi)) {
        ESP_LOGE(TAG, "Card Mount Failed");
        return;
    }

    ESP_LOGD(TAG, "SD card initialized.");

    ControllerAdapter::initializeQueue();

    ESP_LOGD(TAG, "Device controls setup completed.");

    for (int i = 0; i < CC1101_NUM_MODULES; i++) {
        ESP_LOGD(TAG, "Initializing CC1101 module #%d\n", i);
        moduleCC1101State[i].init();
        ESP_LOGD(TAG, "Initializing CC1101 module #%d end \n", i);
        // cc1101Control initialization removed - using workers now
        ESP_LOGD(TAG, "CC1101 module #%d initialized.\n", i);
    }

    deviceConfig.powerBlink = true;

    // Initialize CC1101Worker (includes recording functionality moved from Recorder)
    CC1101Worker::init(cc1101WorkerSignalDetectedHandler, signalRecordedHandler);
    CC1101Worker::start();
    ESP_LOGI(TAG, "CC1101Worker initialized and started");

    // Old state machine initialization REMOVED
    // Workers are now responsible for CC1101 operations

    // BALANCED: TaskProcessor needs adequate stack for file operations
    // Pinned to Core 1 (app core) — keeps BLE stack on Core 0 undisturbed
    xTaskCreatePinnedToCore(taskProcessor, "TaskProcessor", 6144, NULL, 1, NULL, 1);  // 6KB on Core 1
    ESP_LOGD(TAG, "TaskProcessor task created.");

    ClientsManager& clients = ClientsManager::getInstance();
    clients.initializeQueue(NOTIFICATIONS_QUEUE);
    ESP_LOGD(TAG, "ClientsManager initialized.");
    
    // Initialize CommandHandler and register commands
    ESP_LOGI(TAG, "Initializing CommandHandler...");
    
    // Register all commands
    StateCommands::registerCommands(commandHandler);
    FileCommands::registerCommands(commandHandler);
    TransmitterCommands::registerCommands(commandHandler);
    RecorderCommands::registerCommands(commandHandler);
    BruterCommands::registerCommands(commandHandler);
    NrfCommands::registerCommands(commandHandler);
    OtaCommands::registerCommands(commandHandler);
    ButtonCommands::registerCommands(commandHandler);
#if SDR_MODULE_ENABLED
    SdrCommands::registerCommands(commandHandler);
#endif
    
    ESP_LOGI(TAG, "CommandHandler initialized with %zu commands", commandHandler.getCommandCount());

    // Initialize bruter module
    ESP_LOGI(TAG, "Initializing Bruter module...");
    if (!bruter_init()) {
        ESP_LOGE(TAG, "Failed to initialize Bruter module!");
    } else {
        ESP_LOGI(TAG, "Bruter module initialized successfully");
        // Check for any resumable paused attack and notify on connect
        BruterModule& bruter = getBruterModule();
        bruter.checkAndNotifySavedState();
    }

    // Apply persistent settings to runtime modules (bruter delay, repeats, etc.)
    ConfigManager::applyToRuntime();

    // Initialize nRF24L01 module (optional hardware)
#if NRF_MODULE_ENABLED
    ESP_LOGI(TAG, "Initializing nRF24L01 module...");
    if (NrfModule::init()) {
        MouseJack::init();
        ESP_LOGI(TAG, "nRF24L01 + MouseJack initialized");
    } else {
        ESP_LOGW(TAG, "nRF24L01 not detected — NRF features disabled");
    }
#endif

    // Initialize battery monitoring (optional hardware)
#if BATTERY_MODULE_ENABLED
    ESP_LOGI(TAG, "Initializing battery monitor...");
    BatteryModule::init();
#endif

#if SDR_MODULE_ENABLED
    ESP_LOGI(TAG, "Initializing SDR module...");
    SdrModule::init();
#endif

    // Notification sender on Core 0 (near BLE stack for lower latency)
    xTaskCreatePinnedToCore(ClientsManager::processMessageQueue, "SendNotifications", 2560, NULL, 1, NULL, 0); // 2.5KB on Core 0
    ESP_LOGD(TAG, "SendNotifications task created.");
    
    // Create time synchronization task (updates deviceTime every second)
    xTaskCreatePinnedToCore(timeSyncTask, "TimeSync", 1024, NULL, 1, NULL, 0); // 1KB on Core 0 (minimal)
    ESP_LOGD(TAG, "TimeSync task created.");
    
    // Create serial command processing task on Core 1
    xTaskCreatePinnedToCore(serialCommandTask, "SerialCmd", 3072, NULL, 1, NULL, 1); // 3KB on Core 1
    ESP_LOGD(TAG, "SerialCmd task created.");
    
    // Initialize BLE adapter instead of WiFi
    bleAdapter.begin();
    bleAdapter.setCommandHandler(&commandHandler);  // Set CommandHandler
    clients.addAdapter(&bleAdapter);
    bleAdapterStarted = true;
    ESP_LOGD(TAG, "BLE adapter initialized and added to clients.");

    // Log initial heap state - baseline for comparison
    ESP_LOGI(TAG, "===== INITIAL HEAP STATE (using static task allocation) =====");
    logHeapStats("Setup complete");
    ESP_LOGI(TAG, "NOTE: Heap stats should remain stable even after many task create/delete cycles!");

    ESP_LOGD(TAG, "Scheduler is managed by Arduino core; not starting it manually.");
    // The Arduino core already starts the FreeRTOS scheduler. Calling
    // `vTaskStartScheduler()` here would attempt to start it again and
    // can cause undefined behavior (task registration issues and WDT
    // panics). Tasks created above will run under the existing scheduler.
}

// Time synchronization task - updates deviceTime every second
void timeSyncTask(void* pvParameters) {
    const TickType_t delay = pdMS_TO_TICKS(1000); // 1 second
    
    while (true) {
        vTaskDelay(delay);
        
        // Only increment if time has been set (deviceTime > 0)
        if (deviceTime > 0) {
            deviceTime++;
        }
    }
}

void loop()
{
    // Poll hardware buttons for configured actions
    ButtonCommands::checkButtons();

#if SDR_MODULE_ENABLED
    // Poll SDR raw RX streaming (reads CC1101 FIFO and sends via serial/BLE)
    if (SdrModule::isActive() && SdrModule::isStreaming()) {
        SdrModule::pollRawRx();
    }
#endif

    if (deviceConfig.powerBlink) {
        // Priority blink: NRF jammer > bruter > normal heartbeat
        BruterModule& bruter = getBruterModule();
        if (NrfJammer::isRunning()) {
            DeviceControls::nrfJamActiveBlink();
        } else if (bruter.isAttackRunning()) {
            DeviceControls::bruterActiveBlink();
        } else {
            DeviceControls::poweronBlink();
        }
    }
}
