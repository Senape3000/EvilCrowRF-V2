#include "CC1101_Worker.h"
#include <sstream>  // Moved here from CC1101_Worker.h — only used in this .cpp
#include "FlipperSubFile.h"
#include "modules/subghz_function/StreamingSubFileParser.h"
#include "StreamingPulsePayload.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "modules/subghz_function/ProtocolDecoder.h"
#include "modules/subghz_function/FrequencyAnalyzer.h"
#include "StringHelpers.h"
#include "SubFileParser.h"  // For preset byte arrays
#include "core/ble/CommandHandler.h"
#include "DeviceTasks.h"
#include "esp_log.h"

static const char* TAG = "CC1101Worker";

// Helper function to get preset byte array by preset name
static const uint8_t* getPresetByteArray(const std::string& presetName) {
    if (presetName == "FuriHalSubGhzPresetOok270Async") {
        return subghz_device_cc1101_preset_ook_270khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPresetOok650Async") {
        return subghz_device_cc1101_preset_ook_650khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPreset2FSKDev238Async") {
        return subghz_device_cc1101_preset_2fsk_dev2_38khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPreset2FSKDev476Async") {
        return subghz_device_cc1101_preset_2fsk_dev47_6khz_async_regs;
    } else if (presetName == "FuriHalSubGhzPresetMSK99_97KbAsync") {
        return subghz_device_cc1101_preset_msk_99_97kb_async_regs;
    } else if (presetName == "FuriHalSubGhzPresetGFSK9_99KbAsync") {
        return subghz_device_cc1101_preset_gfsk_9_99kb_async_regs;
    }
    return nullptr;
}

// External references
extern ClientsManager& clients;

// Static member initialization
QueueHandle_t CC1101Worker::taskQueue = nullptr;
TaskHandle_t CC1101Worker::workerTaskHandle = nullptr;
CC1101State CC1101Worker::moduleStates[CC1101_NUM_MODULES] = {CC1101State::Idle, CC1101State::Idle};
int CC1101Worker::detectionMinRssi[CC1101_NUM_MODULES] = {-50, -50};
bool CC1101Worker::detectionIsBackground[CC1101_NUM_MODULES] = {false, false};
CC1101Worker::RecordingConfig CC1101Worker::recordingConfigs[CC1101_NUM_MODULES];
CC1101Worker::JammingConfig CC1101Worker::jammingConfigs[CC1101_NUM_MODULES];
SignalDetectedCallback CC1101Worker::signalDetectedCallback = nullptr;
SignalRecordedCallback CC1101Worker::signalRecordedCallback = nullptr;
SemaphoreHandle_t sdMutex = nullptr;  // SD card mutex for concurrent file operations

float CC1101Worker::signalDetectionFrequencies[] = {
    300.00, 303.87, 304.25, 310.00, 315.00, 318.00, 390.00, 418.00, 433.07,
    433.92, 434.42, 434.77, 438.90, 868.35, 868.865, 868.95, 915.00, 925.00
};

extern ModuleCc1101 moduleCC1101State[CC1101_NUM_MODULES];

// Recording ISR data structures (moved from Recorder.cpp)
portMUX_TYPE CC1101Worker::samplesMuxes[CC1101_NUM_MODULES];
ReceivedSamples CC1101Worker::receivedSamples[CC1101_NUM_MODULES];

void CC1101Worker::init(SignalDetectedCallback detectedCb, SignalRecordedCallback recordedCb) {
    signalDetectedCallback = detectedCb;
    signalRecordedCallback = recordedCb;
    
    // Initialize samples mutexes (moved from Recorder::init)
    for (int i = 0; i < CC1101_NUM_MODULES; ++i) {
        samplesMuxes[i] = portMUX_INITIALIZER_UNLOCKED;
    }
    
    // Create queue for CC1101 tasks
    taskQueue = xQueueCreate(10, sizeof(CC1101Task*));
    if (taskQueue == nullptr) {
        ESP_LOGE(TAG, "Failed to create task queue");
    }
    
    // Create SD card mutex for concurrent file operations
    sdMutex = xSemaphoreCreateMutex();
    if (sdMutex == nullptr) {
        ESP_LOGE(TAG, "Failed to create SD mutex");
    }
}

// ISR and interrupt management functions (moved from Recorder.cpp)
void IRAM_ATTR CC1101Worker::receiver(void* arg)
{
    int module = reinterpret_cast<int>(arg);
    receiveSample(module);
}

void IRAM_ATTR CC1101Worker::receiveSample(int module)
{
    const unsigned long time = micros();
    portENTER_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
    ReceivedSamples &data = getReceivedData(module);

    if (data.lastReceiveTime == 0) {
        data.lastReceiveTime = time;
        portEXIT_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
        return;
    }

    const unsigned long duration = time - data.lastReceiveTime;
    data.lastReceiveTime = time;

    if (duration > MAX_SIGNAL_DURATION) {
        // Log only occasionally to avoid ISR overhead - use static counter
        static volatile int clearCount[2] = {0, 0};
        clearCount[module] = clearCount[module] + 1;  // Avoid deprecated volatile++
        if ((clearCount[module] % 100) == 0) {
            // Note: ESP_LOG cannot be used in ISR, so we'll track this differently
        }
        data.samples.clear();
        portEXIT_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
        return;
    }

    if (duration >= MIN_PULSE_DURATION && data.samples.size() < MAX_SAMPLES_BUFFER) {
        try {
            data.samples.push_back(duration);
        } catch (...) {
            // If vector push_back fails, clear and continue
            data.samples.clear();
        }
    } else {
        // Track rejected samples for debugging
        static volatile int rejectedCount[2] = {0, 0};
        rejectedCount[module] = rejectedCount[module] + 1;  // Avoid deprecated volatile++
    }

    portEXIT_CRITICAL_ISR(&CC1101Worker::samplesMuxes[module]);
}

void CC1101Worker::addModuleReceiver(int module)
{
    // First remove any existing interrupt to avoid conflicts
    removeModuleReceiver(module);
    // Use busy wait instead of vTaskDelay to avoid context issues
    delayMicroseconds(1000); // 1ms delay
    attachInterruptArg(moduleCC1101State[module].getInputPin(), receiver, reinterpret_cast<void*>(module), CHANGE);
}

void CC1101Worker::removeModuleReceiver(int module)
{
    // Check if interrupt is actually attached before removing
    // This prevents "GPIO isr service is not installed" error
    int pin = moduleCC1101State[module].getInputPin();
    if (digitalPinToInterrupt(pin) != NOT_AN_INTERRUPT) {
        detachInterrupt(digitalPinToInterrupt(pin));
        ESP_LOGD(TAG, "ISR detached for module %d (pin %d)", module, pin);
    }
}

void CC1101Worker::clearReceivedSamples(int module)
{
    portENTER_CRITICAL(&CC1101Worker::samplesMuxes[module]);
    getReceivedData(module).samples.clear();
    getReceivedData(module).lastReceiveTime = 0;
    portEXIT_CRITICAL(&CC1101Worker::samplesMuxes[module]);
}

ReceivedSamples& CC1101Worker::getReceivedData(int module)
{
    return receivedSamples[module];
}

void CC1101Worker::start() {
    // Create worker task with static allocation
    // Stack usage:
    // - StreamingPulsePayload (~100 bytes - reads from file on-demand!)
    // - checkAndSaveRecording() chunk buffer (~2KB)
    // - Stack frames and local variables (~1KB)
    // - BLE notifications and system calls (~1KB)
    // Total: ~4KB used, increased to 6KB for safety margin
    static StackType_t workerStack[6144 / sizeof(StackType_t)];
    static StaticTask_t workerBuffer;
    
    workerTaskHandle = xTaskCreateStatic(
        workerTask,
        "CC1101Worker",
        6144 / sizeof(StackType_t),
        nullptr,
        5,  // Priority 3 (high priority for time-sensitive RF operations, increased for jamming stability)
        workerStack,
        &workerBuffer
    );
    
    if (workerTaskHandle == nullptr) {
        ESP_LOGE(TAG, "Failed to create worker task");
    } else {
        ESP_LOGI(TAG, "CC1101Worker started successfully");
    }
}

void CC1101Worker::workerTask(void* parameter) {
    ESP_LOGI(TAG, "CC1101Worker task running");
    
    CC1101Task* taskPtr;
    TickType_t lastWakeTime = xTaskGetTickCount();
    TickType_t lastHeartbeat = xTaskGetTickCount();
    
    while (true) {
        // Monitor stack usage periodically
        static int iterationCount = 0;
        if (++iterationCount % 1000 == 0) {
            UBaseType_t stackHighWaterMark = uxTaskGetStackHighWaterMark(NULL);
            ESP_LOGI(TAG, "Stack usage: %d bytes used, %d bytes remaining", 
                     6144 - stackHighWaterMark * sizeof(StackType_t),
                     stackHighWaterMark * sizeof(StackType_t));
            
            if (stackHighWaterMark < 1024) {
                ESP_LOGW(TAG, "Low stack: %d bytes remaining", stackHighWaterMark * sizeof(StackType_t));
            }
        }

        // Periodic heap health check (every ~60 s)
        static TickType_t lastHeapLog = 0;
        TickType_t nowHeap = xTaskGetTickCount();
        if ((nowHeap - lastHeapLog) > pdMS_TO_TICKS(60000)) {
            lastHeapLog = nowHeap;
            size_t freeH  = ESP.getFreeHeap();
            size_t largest = heap_caps_get_largest_free_block(MALLOC_CAP_DEFAULT);
            size_t minEver = ESP.getMinFreeHeap();
            float frag = (freeH > 0) ? 100.0f * (1.0f - (float)largest / (float)freeH) : 0.0f;
            ESP_LOGI(TAG, "Heap: free=%u largest=%u min=%u frag=%.1f%%",
                     freeH, largest, minEver, frag);
            if (freeH < 20000) {
                ESP_LOGW(TAG, "Heap critically low! free=%u", freeH);
            }
            if (frag > 40.0f) {
                ESP_LOGW(TAG, "High heap fragmentation: %.1f%%", frag);
            }
        }
        
        // Send periodic heartbeat for widget updates (every 30 seconds)
        // Skip if a command is currently executing to avoid interference
        TickType_t now = xTaskGetTickCount();
        if ((now - lastHeartbeat) > pdMS_TO_TICKS(30000)) {
            if (!commandHandler.isExecuting) {
                sendHeartbeat();
            }
            lastHeartbeat = now;
        }
        
        // Check for new commands (non-blocking)
        if (xQueueReceive(taskQueue, &taskPtr, 0) == pdTRUE) {
            if (taskPtr != nullptr) {
                processTask(*taskPtr);
                delete taskPtr;
            }
        }
        
        // Process ongoing operations for both modules
        for (int module = 0; module < CC1101_NUM_MODULES; module++) {
            switch (moduleStates[module]) {
                case CC1101State::Detecting:
                    processDetecting(module);
                    break;
                    
                case CC1101State::Recording:
                    processRecording(module);
                    break;
                    
                case CC1101State::Analyzing:
                    processAnalyzing(module);
                    break;
                    
                case CC1101State::Jamming:
                    processJamming(module);
                    break;
                    
                case CC1101State::Idle:
                case CC1101State::Transmitting:
                default:
                    // Nothing to do in these states
                    break;
            }
        }
        
        // Small delay to prevent busy-waiting
        vTaskDelayUntil(&lastWakeTime, pdMS_TO_TICKS(10));
    }
}

void CC1101Worker::processTask(const CC1101Task& task) {
    ESP_LOGD(TAG, "Processing command %d for module %d", (int)task.command, task.module);
    
    switch (task.command) {
        case CC1101Command::StartDetect:
            handleStartDetect(task.module, task.minRssi, task.isBackground);
            break;
            
        case CC1101Command::StopDetect:
            handleStopDetect(task.module);
            break;
            
        case CC1101Command::StartRecord:
            handleStartRecord(task.module, task);
            break;
            
        case CC1101Command::StopRecord:
            handleStopRecord(task.module);
            break;
            
        case CC1101Command::Transmit:
            handleTransmit(task.module, task.filename, task.repeat, task.pathType);
            break;
            
        case CC1101Command::StartAnalyzer:
            // frequency=startFreq, rxBandwidth=endFreq, deviation=step, dataRate=dwellTime
            handleStartAnalyzer(task.module, task.frequency, task.rxBandwidth, task.deviation, 
                               static_cast<uint32_t>(task.dataRate));
            break;
            
        case CC1101Command::StopAnalyzer:
            handleStopAnalyzer(task.module);
            break;
            
        case CC1101Command::GoIdle:
            handleGoIdle(task.module);
            break;
            
        case CC1101Command::StartJam:
            handleStartJam(task.module, task.frequency, task.power,
                          task.patternType, task.customPatternData, task.hasCustomPattern,
                          task.maxDurationMs, task.cooldownMs);
            break;
            
        default:
            ESP_LOGW(TAG, "Unknown command: %d", (int)task.command);
            break;
    }
}

void CC1101Worker::handleStartDetect(int module, int minRssi, bool isBackground) {
    ESP_LOGI(TAG, "Starting detection on module %d (minRssi=%d, background=%d)", 
             module, minRssi, isBackground);
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    
    // Configure CC1101 for detection
    moduleCC1101State[module].setReceiveConfig(
        signalDetectionFrequencies[SIGNAL_DETECTION_FREQUENCIES_LENGTH - 1],
        false, 
        MODULATION_ASK_OOK, 
        256, 
        0, 
        512
    ).initConfig();
    
    // Send mode switch notification BEFORE state update for accurate previousMode
    sendModeNotification(module, CC1101State::Detecting);
    
    // Update state after notification
    moduleStates[module] = CC1101State::Detecting;
    detectionMinRssi[module] = minRssi;
    detectionIsBackground[module] = isBackground;
    
    ESP_LOGI(TAG, "Detection started on module %d", module);
}

void CC1101Worker::handleStopDetect(int module) {
    ESP_LOGI(TAG, "Stopping detection on module %d", module);
    
    moduleCC1101State[module].setSidle();
    moduleCC1101State[module].unlock();
    
    // Send notification BEFORE changing state for accurate previousMode
    sendModeNotification(module, CC1101State::Idle);
    moduleStates[module] = CC1101State::Idle;
}

void CC1101Worker::handleStartRecord(int module, const CC1101Task& config) {
    ESP_LOGI(TAG, "Starting recording on module %d (freq=%.2f, mod=%d, preset=%s)", 
             module, config.frequency, config.modulation, config.preset.c_str());
    
    // Log other module state for debugging concurrent operations
    int otherModule = (module == 0) ? 1 : 0;
    ESP_LOGI(TAG, "Module %d state before start: %d, Module %d state: %d", 
             module, static_cast<int>(moduleStates[module]),
             otherModule, static_cast<int>(moduleStates[otherModule]));
    
    // Stop any ongoing operation first (ONLY on this module!)
    handleGoIdle(module);
    
    // Save recording config
    recordingConfigs[module].frequency = config.frequency;
    recordingConfigs[module].modulation = config.modulation;
    recordingConfigs[module].deviation = config.deviation;
    recordingConfigs[module].rxBandwidth = config.rxBandwidth;
    recordingConfigs[module].dataRate = config.dataRate;
    recordingConfigs[module].preset = config.preset;
    
    // Update state FIRST (before starting actual recording)
    // Send mode switch notification BEFORE changing state for accurate previousMode
    sendModeNotification(module, CC1101State::Recording);
    moduleStates[module] = CC1101State::Recording;
    
    // Verify other module state unchanged
    ESP_LOGI(TAG, "After start - Module %d: Recording, Module %d: %d (should be unchanged!)", 
             module, otherModule, static_cast<int>(moduleStates[otherModule]));
    
    // Configure CC1101
    moduleCC1101State[module].setReceiveConfig(
        config.frequency,
        config.modulation == MODULATION_2_FSK ? true : false,
        config.modulation,
        config.rxBandwidth,
        config.deviation,
        config.dataRate
    ).initConfig();
    
    // Clear any previous samples and start ISR
    clearReceivedSamples(module);
    
    // Get GDO0 pin for this module
    int gdo0Pin = moduleCC1101State[module].getInputPin();
    ESP_LOGI(TAG, "Setting up ISR for module %d on pin %d (frequency=%.2f, modulation=%d, deviation=%.2f)", 
             module, gdo0Pin, config.frequency, config.modulation, config.deviation);
    
    addModuleReceiver(module);
    
    // Verify interrupt was attached
    if (digitalPinToInterrupt(gdo0Pin) != NOT_AN_INTERRUPT) {
        ESP_LOGI(TAG, "ISR successfully attached for module %d on pin %d", module, gdo0Pin);
    } else {
        ESP_LOGE(TAG, "Failed to attach ISR for module %d on pin %d!", module, gdo0Pin);
    }
    
    ESP_LOGI(TAG, "Recording started on module %d", module);
}

void CC1101Worker::handleStopRecord(int module) {
    ESP_LOGI(TAG, "Stopping recording on module %d", module);
    
    removeModuleReceiver(module);
    moduleCC1101State[module].setSidle();
    moduleCC1101State[module].unlock();
    clearReceivedSamples(module);
    moduleStates[module] = CC1101State::Idle;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Idle);
}

void CC1101Worker::handleTransmit(int module, const std::string& filename, int repeat, int pathType) {
    ESP_LOGI(TAG, "Transmitting on module %d: %s (repeat=%d)", module, filename.c_str(), repeat);
    
    // Remember previous state for proper restoration
    CC1101State previousState = moduleStates[module];
    ESP_LOGI(TAG, "Module %d previous state: %d", module, static_cast<int>(previousState));
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    
    // IMPORTANT: Give more time after stopping operation to ensure notification is sent
    vTaskDelay(pdMS_TO_TICKS(100));
    
    // Update state
    moduleStates[module] = CC1101State::Transmitting;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Transmitting);
    
    // CRITICAL: Give BLE time to send notification before blocking transmission
    vTaskDelay(pdMS_TO_TICKS(100));
    
    // Perform transmission (this is blocking)
    std::string error = transmitSub(filename, module, repeat, pathType);
    
    // Back to idle
    moduleStates[module] = CC1101State::Idle;
    
    // Send mode switch notification
    sendModeNotification(module, CC1101State::Idle);
    
    // CRITICAL: Give BLE time to send notification
    vTaskDelay(pdMS_TO_TICKS(100));
    
    if (error.empty()) {
        ESP_LOGI(TAG, "Transmission completed successfully on module %d", module);
    } else {
        ESP_LOGE(TAG, "Transmission failed on module %d: %s", module, error.c_str());
    }
}

void CC1101Worker::handleStartAnalyzer(int module, float startFreq, float endFreq, float step, uint32_t dwellTime) {
    ESP_LOGI(TAG, "Starting analyzer on module %d (%.2f - %.2f MHz, step=%.2f, dwell=%u ms)", 
             module, startFreq, endFreq, step, dwellTime);
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    
    // Validate and set defaults
    if (step <= 0 || step > 1.0f) {
        step = 0.1f;  // Default step 0.1 MHz
    }
    
    if (dwellTime == 0) {
        dwellTime = 50;  // 50ms default dwell time
    }
    
    frequencyAnalyzer.startScan(module, startFreq, endFreq, step, dwellTime);
    moduleStates[module] = CC1101State::Analyzing;
    
    sendModeNotification(module, CC1101State::Analyzing);
}

void CC1101Worker::handleStopAnalyzer(int module) {
    ESP_LOGI(TAG, "Stopping analyzer on module %d", module);
    
    frequencyAnalyzer.stopScan();
    moduleStates[module] = CC1101State::Idle;
    
    sendModeNotification(module, CC1101State::Idle);
}

void CC1101Worker::processAnalyzing(int module) {
    frequencyAnalyzer.process();
    
    // Check if analyzer finished
    if (!frequencyAnalyzer.isActive() && moduleStates[module] == CC1101State::Analyzing) {
        handleStopAnalyzer(module);
    }
}

void CC1101Worker::handleGoIdle(int module) {
    ESP_LOGD(TAG, "Setting module %d to idle", module);
    
    switch (moduleStates[module]) {
        case CC1101State::Detecting:
            handleStopDetect(module);
            break;
            
        case CC1101State::Recording:
            handleStopRecord(module);
            break;
            
        case CC1101State::Analyzing:
            handleStopAnalyzer(module);
            break;
            
        case CC1101State::Jamming:
            handleStopJam(module);
            break;
            
        case CC1101State::Transmitting:
        case CC1101State::Idle:
        default:
            moduleCC1101State[module].setSidle();
            moduleCC1101State[module].unlock();
            moduleStates[module] = CC1101State::Idle;
            break;
    }
}

void CC1101Worker::processDetecting(int module) {
    // Scan all frequencies and report every signal above threshold
    detectSignal(module, detectionMinRssi[module], detectionIsBackground[module]);
    
    // Small cooldown between full sweeps to avoid flooding BLE
    vTaskDelay(pdMS_TO_TICKS(50));
}

bool CC1101Worker::detectSignal(int module, int minRssi, bool isBackground) {
    bool anyFound = false;
    
    // Scan ALL frequencies and report each one above threshold individually.
    // This turns the scanner into a real-time frequency activity monitor.
    for (int i = 0; i < SIGNAL_DETECTION_FREQUENCIES_LENGTH; i++) {
        float fMhz = signalDetectionFrequencies[i];
        moduleCC1101State[module].changeFrequency(fMhz);
        vTaskDelay(pdMS_TO_TICKS(1));
        int rssi = moduleCC1101State[module].getRssi();
        
        if (rssi >= minRssi) {
            CC1101DetectedSignal signal;
            signal.rssi = rssi;
            signal.lqi = moduleCC1101State[module].getLqi();
            signal.frequency = fMhz;
            signal.module = module;
            signal.isBackgroundScanner = isBackground;
            
            ESP_LOGD(TAG, "Signal: freq=%.2f rssi=%d module=%d", 
                     fMhz, rssi, module);
            
            if (signalDetectedCallback) {
                signalDetectedCallback(signal);
            }
            anyFound = true;
        }
    }
    
    return anyFound;
}

void CC1101Worker::processRecording(int module) {
    // Check if recording is complete
    checkAndSaveRecording(module);
}

void CC1101Worker::checkAndSaveRecording(int module) {
    // Get samples from ISR buffer
    portENTER_CRITICAL(&samplesMuxes[module]);
    ReceivedSamples &data = getReceivedData(module);
    size_t sampleCount = data.samples.size();
    unsigned long lastReceiveTime = data.lastReceiveTime;
    portEXIT_CRITICAL(&samplesMuxes[module]);
    
    if (sampleCount < MIN_SAMPLE) {
        return;  // Not enough samples yet
    }
    
    unsigned long timeSinceLast = micros() - lastReceiveTime;
    if (timeSinceLast <= MAX_SIGNAL_DURATION) {
        return;  // Signal still coming in
    }
    
    ESP_LOGI(TAG, "Signal complete on module %d: %zu samples", module, sampleCount);
    
    // Stop recording
    removeModuleReceiver(module);
    
    // Limit samples
    if (sampleCount > 10000) {
        sampleCount = 10000;
    }
    
    // Try to decode protocol in real-time
    ProtocolDecoder::DecodedSignal decoded;
    bool decodedSuccess = false;
    
    // Get samples copy for decoding (must be done outside critical section)
    std::vector<unsigned long> samplesCopy;
    samplesCopy.reserve(sampleCount);
    
    portENTER_CRITICAL(&samplesMuxes[module]);
    samplesCopy.assign(data.samples.begin(), data.samples.begin() + sampleCount);
    portEXIT_CRITICAL(&samplesMuxes[module]);
    
    // Read RSSI outside critical section to avoid deadlock
    // (getRssi acquires rwSemaphore internally, which is forbidden inside portENTER_CRITICAL)
    int currentRssi = moduleCC1101State[module].getRssi();
    
    // Attempt decoding
    decodedSuccess = ProtocolDecoder::decode(samplesCopy, 
                                            recordingConfigs[module].frequency,
                                            currentRssi,
                                            decoded);
    
    if (decodedSuccess && decoded.isValid() && decoded.protocol != "RAW") {
        ESP_LOGI(TAG, "Signal decoded as %s protocol", decoded.protocol.c_str());
    } else {
        ESP_LOGD(TAG, "Signal could not be decoded to specific protocol, saving as RAW");
    }
    
    // Generate filename (include protocol if decoded)
    RecordingConfig& config = recordingConfigs[module];
    char filenameBuffer[100];
    if (decodedSuccess && decoded.isValid() && decoded.protocol != "RAW") {
        sprintf(filenameBuffer, "m%d_%s_%d_%s.sub", 
                module, 
                decoded.protocol.c_str(),
                static_cast<int>(config.frequency * 100),
                helpers::string::generateRandomString(8).c_str());
    } else {
        sprintf(filenameBuffer, "m%d_%d_%s_%d_%s.sub", 
                module, 
                static_cast<int>(config.frequency * 100), 
                config.modulation == MODULATION_ASK_OOK ? "AM" : "FM",
                static_cast<int>(config.rxBandwidth),
                helpers::string::generateRandomString(8).c_str());
    }
    std::string filename = filenameBuffer;
    std::string fullPath = "/DATA/SIGNALS/" + filename;
    
    // Prepare custom preset data if needed
    std::vector<byte> customPresetData;
    if (config.preset == "Custom") {
        ModuleCc1101& m = moduleCC1101State[module];
        customPresetData.insert(customPresetData.end(), {
            CC1101_MDMCFG4, m.getRegisterValue(CC1101_MDMCFG4),
            CC1101_MDMCFG3, m.getRegisterValue(CC1101_MDMCFG3),
            CC1101_MDMCFG2, m.getRegisterValue(CC1101_MDMCFG2),
            CC1101_DEVIATN, m.getRegisterValue(CC1101_DEVIATN),
            CC1101_FREND0,  m.getRegisterValue(CC1101_FREND0),
            0x00, 0x00
        });
        
        std::array<byte, 8> paTable = m.getPATableValues();
        customPresetData.insert(customPresetData.end(), paTable.begin(), paTable.end());
    }
    
    // CRITICAL OPTIMIZATION: Write chunks directly to file
    // CRITICAL: Lock SD mutex for concurrent file operations from multiple modules
    if (xSemaphoreTake(sdMutex, pdMS_TO_TICKS(1000)) != pdTRUE) {
        ESP_LOGE(TAG, "Failed to acquire SD mutex for module %d", module);
        if (signalRecordedCallback) {
            signalRecordedCallback(false, filename);
        }
        clearReceivedSamples(module);
        addModuleReceiver(module);
        return;
    }
    
    // Create directory if needed
    if (!SD.exists("/DATA/SIGNALS")) {
        SD.mkdir("/DATA/SIGNALS");
    }
    
    File file = SD.open(fullPath.c_str(), FILE_WRITE);
    if (!file) {
        ESP_LOGE(TAG, "Failed to open file: %s", fullPath.c_str());
        xSemaphoreGive(sdMutex);  // Release mutex!
        if (signalRecordedCallback) {
            signalRecordedCallback(false, filename);
        }
        clearReceivedSamples(module);
        addModuleReceiver(module);  // Restart recording
        return;
    }
    
    // Write header and preset info
    file.println("Filetype: Flipper SubGhz RAW File");
    file.println("Version: 1");
    file.print("Frequency: ");
    file.print(config.frequency * 1e6, 0);
    file.println();
    
    // Write preset
    file.print("Preset: ");
    std::string presetName = config.preset.empty() ? "Custom" : config.preset;
    if (presetName == "Ook270") file.println("FuriHalSubGhzPresetOok270Async");
    else if (presetName == "Ook650") file.println("FuriHalSubGhzPresetOok650Async");
    else if (presetName == "2FSKDev238") file.println("FuriHalSubGhzPreset2FSKDev238Async");
    else if (presetName == "2FSKDev476") file.println("FuriHalSubGhzPreset2FSKDev476Async");
    else if (presetName == "MSK") file.println("FuriHalSubGhzPresetMSK99_97KbAsync");
    else if (presetName == "GFSK") file.println("FuriHalSubGhzPresetGFSK9_99KbAsync");
    else file.println("FuriHalSubGhzPresetCustom");
    
    if (presetName == "Custom" && !customPresetData.empty()) {
        file.println("Custom_preset_module: CC1101");
        file.print("Custom_preset_data: ");
        for (size_t i = 0; i < customPresetData.size(); ++i) {
            char hexStr[3];
            sprintf(hexStr, "%02X", customPresetData[i]);
            file.print(hexStr);
            if (i < customPresetData.size() - 1) file.print(" ");
        }
        file.println();
    }
    
    // Write protocol (decoded if available, otherwise RAW)
    file.print("Protocol: ");
    if (decodedSuccess && decoded.isValid() && decoded.protocol != "RAW") {
        file.println(decoded.protocol.c_str());
        
        // Write protocol-specific data
        if (decoded.protocol == "Princeton") {
            if (!decoded.key.empty()) {
                file.print("Key: ");
                file.println(decoded.key.c_str());
            }
            if (decoded.te > 0) {
                file.print("TE: ");
                file.println(decoded.te);
            }
            if (decoded.bitCount > 0) {
                file.print("Bit: ");
                file.println(decoded.bitCount);
            }
            if (decoded.repeat > 0) {
                file.print("Repeat: ");
                file.println(decoded.repeat);
            }
        }
        
        // Also save RAW data as fallback
        file.println("RAW_Data: ");
        file.print("RAW_Data: ");
    } else {
        file.println("RAW");
        file.print("RAW_Data: ");
    }
    
    // Write samples in chunks directly from ISR buffer
    const size_t CHUNK_SIZE = 256;
    unsigned long chunk[CHUNK_SIZE];
    size_t offset = 0;
    
    while (offset < sampleCount) {
        size_t chunkSize = min(CHUNK_SIZE, sampleCount - offset);
        
        // Copy chunk from ISR buffer
        portENTER_CRITICAL(&samplesMuxes[module]);
        for (size_t i = 0; i < chunkSize; i++) {
            chunk[i] = data.samples[offset + i];
        }
        portEXIT_CRITICAL(&samplesMuxes[module]);
        
        // Write chunk to file
        for (size_t i = 0; i < chunkSize; i++) {
            if (offset + i > 0) {
                file.print((offset + i) % 2 == 1 ? " -" : " ");
            }
            file.print(chunk[i]);
        }
        
        offset += chunkSize;
        
        // Line breaks every 512 numbers
        if (offset % 512 == 0 && offset < sampleCount) {
            file.println();
            file.print("RAW_Data: ");
        }
    }
    
    file.println();
    file.close();
    
    // NOTE: File time setting is disabled here to avoid stack overflow
    // Time will be set when file is saved to Records directory via saveFileToSignalsWithName
    // which has more stack space available
    
    // CRITICAL: Release SD mutex after file operations
    xSemaphoreGive(sdMutex);
    
    ESP_LOGI(TAG, "Signal saved: %s (%zu samples)", filename.c_str(), sampleCount);
    
    // Callback
    if (signalRecordedCallback) {
        signalRecordedCallback(true, filename);
    }
    
    // Clear samples and restart recording
    clearReceivedSamples(module);
    addModuleReceiver(module);
}

// Transmission functions (moved from Transmitter.cpp)
std::vector<int> CC1101Worker::getCountOfOnOffBits(const std::string &bits)
{
    std::vector<int> counts;
    char currentBit = bits[0];
    int currentCount = 1;

    for (size_t i = 1; i < bits.size(); i++) {
        if (bits[i] == currentBit) {
            currentCount++;
        } else {
            counts.push_back(currentCount);
            currentBit = bits[i];
            currentCount = 1;
        }
    }

    counts.push_back(currentCount);
    return counts;
}

bool CC1101Worker::transmitBinary(float frequency, int pulseDuration, const std::string &bits, int module, int modulation, float deviation, int repeatCount, int wait)
{
    moduleCC1101State[module].backupConfig().setTransmitConfig(frequency, modulation, deviation).init();
    std::vector<int> countOfOnOffBits = getCountOfOnOffBits(bits);

    for (int r = 0; r < repeatCount; r++) {
        for (int i = 0; i < countOfOnOffBits.size(); i++) {
            digitalWrite(moduleCC1101State[module].getOutputPin(), i % 2 == 0 ? HIGH : LOW);
            delayMicroseconds(countOfOnOffBits[i] * pulseDuration);
        }
        delay(wait);
    }

    moduleCC1101State[module].restoreConfig();
    moduleCC1101State[module].setSidle();

    return true;
}

bool CC1101Worker::transmitRaw(int module, float frequency, int modulation, float deviation, std::string& data, int repeat)
{
    std::vector<int> samples;
    std::istringstream stream(data.c_str());
    int sample;

    while (stream >> sample) {
        samples.push_back(sample);
    }

    moduleCC1101State[module].backupConfig().setTransmitConfig(frequency, modulation, deviation).initConfig();
    for (int r = 0; r < repeat; r++) {
        transmitRawData(samples, module);
        delay(1);
    }

    moduleCC1101State[module].restoreConfig();
    moduleCC1101State[module].setSidle();

    return true;
}

std::string CC1101Worker::transmitSub(const std::string& filename, int module, int repeat, int pathType)
{
    std::string fullPath;
    // If path is already absolute (/DATA/...), use it directly
    if (filename.find("/DATA/") == 0) {
        fullPath = filename;
        ESP_LOGD(TAG, "Using full system path: %s", fullPath.c_str());
    } else {
        // Use pathType to determine subdirectory
        static const char* DIRS[] = {"/DATA/RECORDS", "/DATA/SIGNALS", "/DATA/PRESETS", "/DATA/TEMP"};
        if (pathType >= 0 && pathType < 4) {
            fullPath = std::string(DIRS[pathType]) + "/" + filename;
            ESP_LOGD(TAG, "Using pathType %d: %s", pathType, DIRS[pathType]);
        } else {
            fullPath = std::string("/DATA/RECORDS/") + filename;
            ESP_LOGW(TAG, "Unknown pathType %d; default RECORDS", pathType);
        }
        ESP_LOGD(TAG, "Added base path, full path: %s", fullPath.c_str());
    }
    ESP_LOGI(TAG, "Opening file: %s", fullPath.c_str());
    if (!SD.exists(fullPath.c_str())) {
        std::string msg = "File does not exist: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    File file = SD.open(fullPath.c_str(), FILE_READ);
    if (!file) {
        std::string msg = "Failed to open file: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    ESP_LOGD(TAG, "File opened successfully, size: %d bytes", file.size());
    file.close(); // Close immediately - will reopen for streaming
    
    // OPTIMIZED: Use StreamingSubFileParser (minimal RAM usage!)
    StreamingSubFileParser streamParser;
    StreamingSubFileParser::SubFileHeader header;
    
    ESP_LOGD(TAG, "Parsing header (pass 1)...");
    if (!streamParser.parseHeader(fullPath.c_str(), header)) {
        std::string msg = "Failed to parse header from .sub: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    
    // Check if it's a supported protocol (RAW only for now)
    if (header.protocol != "RAW") {
        std::string msg = "Unsupported protocol (only RAW supported in streaming mode): " + header.protocol;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    
    ESP_LOGD(TAG, "Header parsed, frequency: %.2f MHz", header.frequency / 1000000.0);
    
    // Configure CC1101 with proper order:
    // CRITICAL: Preset must be applied AFTER Init but BEFORE entering TX mode
    // Order: 1) Idle, 2) Init (reset registers), 3) Set frequency, 4) Apply preset, 5) Set TX
    ESP_LOGD(TAG, "Configuring CC1101 module %d", module);
    
    // Get preset bytes
    const uint8_t* presetBytes = nullptr;
    int presetLength = 0;
    
    if (!header.preset.empty()) {
        presetBytes = getPresetByteArray(header.preset);
        if (presetBytes != nullptr) {
            presetLength = 44;  // Standard presets are 44 bytes
            ESP_LOGI(TAG, "Using standard preset: %s", header.preset.c_str());
        }
    }
    
    if (presetBytes == nullptr && header.customPresetDataSize > 0) {
        presetBytes = header.customPresetData;
        presetLength = header.customPresetDataSize;
        ESP_LOGI(TAG, "Using custom preset (%zu bytes)", header.customPresetDataSize);
    }
    
    if (presetBytes == nullptr) {
        ESP_LOGW(TAG, "No preset available - using default CC1101 configuration");
        // Use regular setTx without preset
        moduleCC1101State[module].setTx(header.frequency / 1000000.0);
    } else {
        // Use setTxWithPreset which applies preset in correct order
        moduleCC1101State[module].setTxWithPreset(header.frequency / 1000000.0, presetBytes, presetLength);
    }
    
    delay(10);
    
    // ULTRA-OPTIMIZED: Use StreamingPulsePayload (reads from file on-demand!)
    // RAM usage: ~100 bytes instead of ~2KB for vector!
    ESP_LOGD(TAG, "Initializing streaming transmission (repeat: %d)", repeat);
    
    StreamingPulsePayload streamingPayload;
    if (!streamingPayload.init(fullPath.c_str(), repeat)) {
        std::string msg = "Failed to initialize streaming payload: " + fullPath;
        ESP_LOGE(TAG, "%s", msg.c_str());
        return msg;
    }
    
    // Transmit directly from file
    ESP_LOGD(TAG, "Starting streaming transmission...");
    bool signalTransmitted = transmitData(streamingPayload, module);
    ESP_LOGD(TAG, "Transmission result: %s", signalTransmitted ? "SUCCESS" : "FAILED");
    
    streamingPayload.close();
    moduleCC1101State[module].restoreConfig().setSidle();
    ESP_LOGI(TAG, "Transmission %s for %s", signalTransmitted ? "SUCCESS" : "FAILED", fullPath.c_str());
    if (!signalTransmitted) {
        return "Transmission routine failed for file: " + fullPath;
    }
    return std::string(); // success
}

bool CC1101Worker::transmitRawData(const std::vector<int> &rawData, int module)
{
    if (rawData.empty()) {
        return false;
    }

    for (const auto &rawValue : rawData) {
        if (rawValue != 0) {
            digitalWrite(moduleCC1101State[module].getOutputPin(), (rawValue > 0));
            delayMicroseconds(abs(rawValue));
        }
    }

    return true;
}

bool CC1101Worker::transmitData(PulsePayload &payload, int module)
{
    uint32_t duration;
    bool pinState;

    while (payload.next(duration, pinState)) {
        digitalWrite(moduleCC1101State[module].getOutputPin(), pinState);
        delayMicroseconds(duration);
        taskYIELD();
    }

    return true;
}

int CC1101Worker::findFirstIdleModule()
{
    for (int i = 0; i < CC1101_NUM_MODULES; ++i) {
        // Check with CC1101Worker instead of direct mode check
        if (CC1101Worker::getState(i) == CC1101State::Idle)
            return i;
    }
    return -1;
}

// Helper functions to send commands
bool CC1101Worker::startDetect(int module, int minRssi, bool isBackground) {
    if (taskQueue == nullptr) {
        ESP_LOGE(TAG, "Task queue not initialized");
        return false;
    }
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartDetect;
    task->module = module;
    task->minRssi = minRssi;
    task->isBackground = isBackground;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        ESP_LOGE(TAG, "Failed to enqueue task");
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopDetect(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StopDetect;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::startRecord(int module, float frequency, int modulation, float deviation,
                                float rxBandwidth, float dataRate, const std::string& preset) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartRecord;
    task->module = module;
    task->frequency = frequency;
    task->modulation = modulation;
    task->deviation = deviation;
    task->rxBandwidth = rxBandwidth;
    task->dataRate = dataRate;
    task->preset = preset;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopRecord(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StopRecord;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::transmit(int module, const std::string& filename, int repeat, int pathType) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::Transmit;
    task->module = module;
    task->filename = filename;
    task->repeat = repeat;
    task->pathType = pathType;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::goIdle(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::GoIdle;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::startAnalyzer(int module, float startFreq, float endFreq, float step, uint32_t dwellTime) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartAnalyzer;
    task->module = module;
    task->frequency = startFreq;      // Use frequency field for startFreq
    task->rxBandwidth = endFreq;      // Use rxBandwidth field for endFreq
    task->deviation = step;           // Use deviation field for step
    task->dataRate = dwellTime;       // Use dataRate field for dwellTime
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopAnalyzer(int module) {
    if (taskQueue == nullptr) return false;
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StopAnalyzer;
    task->module = module;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(100)) != pdTRUE) {
        delete task;
        return false;
    }
    
    return true;
}

CC1101State CC1101Worker::getState(int module) {
    if (module >= 0 && module < CC1101_NUM_MODULES) {
        return moduleStates[module];
    }
    return CC1101State::Idle;
}

void CC1101Worker::sendModeNotification(int module, CC1101State newState) {
    // Send binary mode switch notification (compatible with old BinaryModeSwitch format)
    // NOTE: previousMode is read from moduleStates[module]. Callers should
    // invoke this BEFORE updating moduleStates for accurate previous state.
    BinaryModeSwitch msg;
    msg.module = static_cast<uint8_t>(module);
    msg.currentMode = static_cast<uint8_t>(newState);
    msg.previousMode = static_cast<uint8_t>(moduleStates[module]);
    
    // Send as binary data
    clients.notifyAllBinary(NotificationType::ModeSwitch, reinterpret_cast<const uint8_t*>(&msg), sizeof(BinaryModeSwitch));
    
    ESP_LOGI(TAG, "[NOTIFY] Module=%d: %d → %d", 
             module, static_cast<int>(msg.previousMode), static_cast<int>(newState));
}

void CC1101Worker::sendHeartbeat() {
    // CRITICAL: Only send heartbeat if there are connected clients
    // Check if any adapter has connected clients before sending
    // This prevents unnecessary processing when device is disconnected
    if (clients.getConnectedCount() == 0) {
        return;  // No connected clients, skip heartbeat
    }
    
    // Send full device status for widget updates (same as GetState)
    const byte numRegs = 0x2E;
    
    BinaryStatus status;
    status.messageType = MSG_STATUS;
    status.module0Mode = static_cast<uint8_t>(moduleStates[0]);
    status.module1Mode = static_cast<uint8_t>(moduleStates[1]);
    status.numRegisters = numRegs;
    status.freeHeap = ESP.getFreeHeap();
    
    // Read all CC1101 registers for both modules
    moduleCC1101State[0].readAllConfigRegisters(status.module0Registers, numRegs);
    moduleCC1101State[1].readAllConfigRegisters(status.module1Registers, numRegs);
    
    // Send binary status
    clients.notifyAllBinary(NotificationType::State, 
                           reinterpret_cast<const uint8_t*>(&status), 
                           sizeof(BinaryStatus));
    
    ESP_LOGD(TAG, "Heartbeat sent: Module0=%d, Module1=%d, FreeHeap=%u", 
             static_cast<int>(moduleStates[0]), 
             static_cast<int>(moduleStates[1]), 
             status.freeHeap);
}

// ====================================
// Jamming implementation
// ====================================

bool CC1101Worker::startJam(int module, float frequency, int power,
                            Device::JamPatternType patternType, const std::vector<uint8_t>* customPattern,
                            uint32_t maxDurationMs, uint32_t cooldownMs) {
    if (module < 0 || module >= CC1101_NUM_MODULES) {
        ESP_LOGE(TAG, "Invalid module for jam: %d", module);
        return false;
    }
    
    CC1101Task* task = new CC1101Task();
    task->command = CC1101Command::StartJam;
    task->module = module;
    task->frequency = frequency;
    task->power = power;
    task->patternType = patternType;
    // Deep-copy the custom pattern to avoid dangling pointer —
    // the caller's unique_ptr may be destroyed before the worker dequeues.
    if (customPattern != nullptr && !customPattern->empty()) {
        task->customPatternData = *customPattern;
        task->hasCustomPattern = true;
    } else {
        task->hasCustomPattern = false;
    }
    task->maxDurationMs = maxDurationMs;
    task->cooldownMs = cooldownMs;
    
    if (xQueueSend(taskQueue, &task, pdMS_TO_TICKS(1000)) != pdTRUE) {
        ESP_LOGE(TAG, "Failed to queue jam task for module %d", module);
        delete task;
        return false;
    }
    
    return true;
}

bool CC1101Worker::stopJam(int module) {
    if (module < 0 || module >= CC1101_NUM_MODULES) {
        ESP_LOGE(TAG, "Invalid module for stopJam: %d", module);
        return false;
    }
    
    // Call handleStopJam directly since this is called from main task processor
    // which already handles synchronization
    handleStopJam(module);
    return true;
}

void CC1101Worker::handleStartJam(int module, float frequency, int power,
                                  Device::JamPatternType patternType, const std::vector<uint8_t>& customPatternData,
                                  bool hasCustomPattern, uint32_t maxDurationMs, uint32_t cooldownMs) {
    ESP_LOGI(TAG, "=== Starting jam on module %d ===", module);
    
    // Convert pattern type to string for logging
    const char* patternName = "Unknown";
    switch (patternType) {
        case Device::JamPatternType::Random: patternName = "Random"; break;
        case Device::JamPatternType::Alternating: patternName = "Alternating"; break;
        case Device::JamPatternType::Continuous: patternName = "Continuous"; break;
        case Device::JamPatternType::Custom: patternName = "Custom"; break;
    }
    
    ESP_LOGI(TAG, "Input parameters: freq=%.2f MHz, power=%d, pattern=%s (%d), maxDur=%lu ms, cooldown=%lu ms",
             frequency, power, patternName, static_cast<int>(patternType), maxDurationMs, cooldownMs);
    
    // Stop any ongoing operation first
    handleGoIdle(module);
    vTaskDelay(pdMS_TO_TICKS(100));
    // Validate power
    if (power < 0 || power > 7) {
        ESP_LOGW(TAG, "Invalid power %d, clamping to 7", power);
        power = 7;
    }
    
    // Configure module for transmission - same logic as in transmitSub
    // Use setTxWithPreset() like transmitSub does with preset
    ModuleCc1101& m = moduleCC1101State[module];
    m.backupConfig();
    
    // Store jamming configuration (needed for pattern generation and time management)
    JammingConfig& config = jammingConfigs[module];
    config.frequency = frequency;
    config.modulation = MODULATION_ASK_OOK;  // Fixed for jamming (Ook650 preset)
    config.deviation = 2.380371;  // Fixed for jamming (from Ook650 preset)
    config.power = power;
    config.patternType = patternType;
    config.maxDurationMs = maxDurationMs;
    config.cooldownMs = cooldownMs;
    config.startTimeMs = millis();
    config.isCooldown = false;
    config.cooldownStartTimeMs = 0;
    config.useDirectPinControl = true;  // Enable direct pin control for testing
    config.gdo0Pin = m.getOutputPin();  // GDO0 pin (inputPin is actually GDO0)
    config.pinInitialized = false;      // Reset initialization flags
    config.fifoInitialized = false;
    
    if (patternType == Device::JamPatternType::Custom && hasCustomPattern) {
        config.customPattern = customPatternData;  // Copy from owned data (safe)
    } else {
        config.customPattern.clear();
    }
    
    // Use Ook650 preset as base (ASK/OOK with wide bandwidth - good for jamming)
    const uint8_t* basePreset = subghz_device_cc1101_preset_ook_650khz_async_regs;
    
    // Create preset bytes with power-specific PA table
    static uint8_t jamPresetBytes[44];
    memcpy(jamPresetBytes, basePreset, 44);
    
    // Use setTxWithPreset() - same as transmitSub
    m.setTxWithPreset(frequency, jamPresetBytes, 44);
    delay(20);  // Initial delay after preset application
    
    // Perform explicit calibration and wait for completion
    // Split_MDMCFG2() is called inside calibrate() to update modulation from register
    // This ensures optimal frequency accuracy and reduces spurious emissions
    m.calibrate();
    bool calComplete = m.waitForCalibration(100);  // Wait up to 100ms for calibration
    if (!calComplete) {
        ESP_LOGW(TAG, "[JAM] Calibration timeout, continuing anyway");
    } else {
        ESP_LOGI(TAG, "[JAM] Calibration completed successfully");
    }
    delay(20);  // Additional delay after calibration for stabilization
    
    // Set power using CC1101's setPA function
    // Convert power level (0-7) to dBm for setPA
    // 0=-30, 1=-20, 2=-15, 3=-10, 4=0, 5=5, 6=7, 7=10 dBm
    int powerDbm = -30;
    if (power == 1) powerDbm = -20;
    else if (power == 2) powerDbm = -15;
    else if (power == 3) powerDbm = -10;
    else if (power == 4) powerDbm = 0;
    else if (power == 5) powerDbm = 5;
    else if (power == 6) powerDbm = 7;
    else if (power >= 7) powerDbm = 10;
    
    // setPA() will automatically:
    // 1. Select correct PA table based on frequency (MHz[currentModule] is set by setMHZ in setTxWithPreset)
    // 2. Read modulation from MDMCFG2 register (using Split_MDMCFG2)
    // 3. Set PA_TABLE correctly based on modulation type
    m.setPA(powerDbm);
    delay(20);  // Delay for PA stabilization after power setting
    
    // Additional delay to ensure CC1101 is fully ready for transmission
    delay(10);
    
    // Log key CC1101 registers
    byte freq2 = m.getRegisterValue(0x0D);  // FREQ2
    byte freq1 = m.getRegisterValue(0x0E);  // FREQ1
    byte freq0 = m.getRegisterValue(0x0F);  // FREQ0
    
    ESP_LOGI(TAG, "CC1101 FREQ: 0x%02X%02X%02X (%.2f MHz), power=%d", 
             freq2, freq1, freq0, frequency, power);
    
    // Update state
    moduleStates[module] = CC1101State::Jamming;
    sendModeNotification(module, CC1101State::Jamming);
    
    ESP_LOGI(TAG, "=== Jam started on module %d ===", module);
}

void CC1101Worker::handleStopJam(int module) {
    ESP_LOGI(TAG, "Stopping jam on module %d", module);
    
    ModuleCc1101& m = moduleCC1101State[module];
    JammingConfig& config = jammingConfigs[module];
    
    // Reset GDO0 pin to LOW and initialization flags
    if (config.useDirectPinControl && config.pinInitialized) {
        digitalWrite(config.gdo0Pin, LOW);
        config.pinInitialized = false;
        ESP_LOGI(TAG, "[JAM] GDO0 pin %d set to LOW", config.gdo0Pin);
    }
    config.fifoInitialized = false;
    
    m.setSidle();
    m.restoreConfig();
    m.unlock();
    
    moduleStates[module] = CC1101State::Idle;
    sendModeNotification(module, CC1101State::Idle);
    
    ESP_LOGI(TAG, "Jam stopped on module %d", module);
}

uint8_t CC1101Worker::generateJamPatternByte(int module, size_t index) {
    JammingConfig& config = jammingConfigs[module];
    
    switch (config.patternType) {
        case Device::JamPatternType::Random:
            // Generate pseudo-random byte based on index and time
            {
                uint32_t seed = (millis() << 16) | (index & 0xFFFF) | (module << 24);
                // Simple LFSR for pseudo-random number generation
                static uint32_t lfsr[CC1101_NUM_MODULES] = {0xACE1u, 0xACE1u};
                uint32_t l = lfsr[module];
                l ^= l >> 7;
                l ^= l << 9;
                l ^= l >> 13;
                lfsr[module] = l;
                return static_cast<uint8_t>(l ^ seed);
            }
            
        case Device::JamPatternType::Alternating:
            // Alternating pattern: 0xAA, 0x55
            return (index % 2 == 0) ? 0xAA : 0x55;
            
        case Device::JamPatternType::Continuous:
            // Continuous transmission
            return 0xFF;
            
        case Device::JamPatternType::Custom:
            if (!config.customPattern.empty()) {
                return config.customPattern[index % config.customPattern.size()];
            }
            return 0xFF; // Fallback
            
        default:
            return 0xFF;
    }
}

void CC1101Worker::generateJamPattern(int module, uint8_t* buffer, size_t length) {
    for (size_t i = 0; i < length; i++) {
        buffer[i] = generateJamPatternByte(module, i);
    }
}

void CC1101Worker::processJamming(int module) {
    JammingConfig& config = jammingConfigs[module];
    uint32_t currentTime = millis();
    
    // FIRST check cooldown mode (to avoid re-entrancy)
    if (config.isCooldown) {
        uint32_t cooldownElapsed = currentTime - config.cooldownStartTimeMs;
        if (cooldownElapsed >= config.cooldownMs) {
            ESP_LOGI(TAG, "Module %d cooldown complete (%lu ms), resuming jam", module, cooldownElapsed);
            config.isCooldown = false;
            config.startTimeMs = currentTime; // Reset timer for new cycle
            
            // Resume transmission
            ModuleCc1101& m = moduleCC1101State[module];
            m.setTx(config.frequency);
        } else {
            // Still in cooldown - just exit
            return;
        }
    }
    
    // Now check overheat protection (only if NOT in cooldown)
    uint32_t elapsed = currentTime - config.startTimeMs;
    if (config.maxDurationMs > 0 && elapsed >= config.maxDurationMs) {
        ESP_LOGI(TAG, "Module %d jam max duration reached (%lu ms), entering cooldown for %lu ms", 
                 module, elapsed, config.cooldownMs);
        config.isCooldown = true;
        config.cooldownStartTimeMs = currentTime;
        
        // Stop transmission
        ModuleCc1101& m = moduleCC1101State[module];
        m.setSidle();
        
        return;
    }
    
    // Generate and transmit pattern via CC1101
    // Use non-blocking approach: SendData with delay instead of waiting for GDO0
    // This works as jamming - constant data transmission overloads the air
    
    ModuleCc1101& m = moduleCC1101State[module];
    JammingConfig& jamConfig = jammingConfigs[module];
    
    // Log parameters periodically (every 100 calls = ~1 second at 10ms cycle)
    static int logCounter[CC1101_NUM_MODULES] = {0, 0};
    if (++logCounter[module] % 100 == 0) {
        // Convert pattern type to string for logging
        const char* patternName = "Unknown";
        switch (jamConfig.patternType) {
            case Device::JamPatternType::Random: patternName = "Random"; break;
            case Device::JamPatternType::Alternating: patternName = "Alternating"; break;
            case Device::JamPatternType::Continuous: patternName = "Continuous"; break;
            case Device::JamPatternType::Custom: patternName = "Custom"; break;
        }
        
        ESP_LOGI(TAG, "[JAM] Module %d: freq=%.2f MHz, mod=%d, dev=%.2f kHz, power=%d, pattern=%s (%d), elapsed=%lu ms",
                 module, jamConfig.frequency, jamConfig.modulation, jamConfig.deviation,
                 jamConfig.power, patternName, static_cast<int>(jamConfig.patternType), millis() - jamConfig.startTimeMs);
        
        // Log current frequency register
        byte freq2 = m.getRegisterValue(0x0D);
        byte freq1 = m.getRegisterValue(0x0E);
        byte freq0 = m.getRegisterValue(0x0F);
        ESP_LOGI(TAG, "[JAM] Module %d FREQ registers: 0x%02X%02X%02X", module, freq2, freq1, freq0);
    }
    
    // m.setTx(config.frequency);
    
    // Choose jamming method: direct pin control or via sendData
    if (jamConfig.useDirectPinControl) {
        // Direct control of GDO0 pin for continuous jamming
        // In ASK/OOK asynchronous mode: HIGH = transmission on, LOW = transmission off
        // For effective jamming keep the pin CONSTANTLY HIGH (no toggling)
        // This will create a continuous signal without gaps
        byte gdo0Pin = jamConfig.gdo0Pin;
        
        // Set the pin to HIGH once on the first call
        // Important: do this after a short delay following CC1101 initialization for stability
        if (!jamConfig.pinInitialized) {
            // Additional delay before starting transmission to allow CC1101 to stabilize
            delay(10);
            digitalWrite(gdo0Pin, HIGH);  // Continuous transmission
            jamConfig.pinInitialized = true;
            ESP_LOGI(TAG, "[JAM] Direct pin control initialized: GDO0 pin=%d, state=HIGH (continuous)", gdo0Pin);
        }
        
        // Pin already set to HIGH, do nothing - just yield control
        // This ensures continuous transmission without gaps
    } else {
        // Method via continuous FIFO transmission
        // Generate a pattern to transmit (64 bytes - maximum FIFO size)
        static uint8_t pattern[64];
        
        if (!jamConfig.fifoInitialized) {
            // Initialization: fill the FIFO and start continuous transmission
            generateJamPattern(module, pattern, 64);

            // Write data to TX FIFO
            m.writeToTxFifo(pattern, 64);

            // Start transmission (already in TX mode after setTxWithPreset)
            // In asynchronous mode data will be transmitted continuously
            jamConfig.fifoInitialized = true;
            
            ESP_LOGI(TAG, "[JAM] FIFO continuous TX initialized: pattern size=64 bytes");
            ESP_LOGI(TAG, "[JAM] Module %d pattern (first 8 bytes): %02X %02X %02X %02X %02X %02X %02X %02X",
                     module, pattern[0], pattern[1], pattern[2], pattern[3], pattern[4], pattern[5], pattern[6], pattern[7]);
        }
        
        // Periodically refill FIFO if it becomes empty
        // But in asynchronous mode this is not required - data is transmitted directly via GDO0
        // This code is kept for compatibility but is effectively unused
    }
    
    // Yield control to other tasks
    taskYIELD();
}
