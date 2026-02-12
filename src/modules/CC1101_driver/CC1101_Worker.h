#ifndef CC1101Worker_h
#define CC1101Worker_h

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <string>
#include <vector>
#include <functional>
#include "config.h"
#include "modules/CC1101_driver/CC1101_Module.h"
#include "modules/subghz_function/ProtocolDecoder.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include "SD.h"
#include "modules/subghz_function/StreamingSubFileParser.h"
#include "StreamingPulsePayload.h"
#include "PulsePayload.h"
#include "DeviceTasks.h"
// Note: <sstream> moved to CC1101_Worker.cpp — only needed there

// Receive data structure - moved from Recorder.h
#define MAX_SAMPLES_BUFFER 512  // Reduced to 512 to save RAM (~4KB savings)

struct ReceivedSamples
{
    std::vector<unsigned long> samples;  // Vector with pre-allocation
    volatile unsigned long lastReceiveTime;
    
    ReceivedSamples() : lastReceiveTime(0) {
        // Pre-allocate on construction - no reallocation during ISR
        samples.reserve(MAX_SAMPLES_BUFFER);
    }
    
    inline void reset() {
        samples.clear();  // Fast with pre-allocated vector
        lastReceiveTime = 0;
    }
};

// CC1101 commands
enum class CC1101Command {
    StartDetect,      
    StopDetect,       
    StartRecord,      
    StopRecord,       
    Transmit,         
    Configure,        
    StartAnalyzer,    
    StopAnalyzer,     
    GoIdle,           
    StartJam
};

// Current operation state per module
enum class CC1101State {
    Idle,
    Detecting,
    Recording,
    Transmitting,
    Analyzing,
    Jamming
};

// DetectedSignal structure (simplified from Detector.h)
struct CC1101DetectedSignal {
    int rssi;
    uint8_t lqi = 0;              // Link Quality Indicator
    float frequency;
    int module;
    bool isBackgroundScanner;
    uint32_t signalLength = 0;    // Signal duration in ms
    bool isDecoded = false;       // Protocol recognized?
    std::string protocol;         // Protocol name if decoded
};

// Callbacks
using SignalDetectedCallback = std::function<void(const CC1101DetectedSignal& signal)>;
using SignalRecordedCallback = std::function<void(bool success, const std::string& filename)>;
using TransmitCompleteCallback = std::function<void(bool success, const std::string& error)>;

// Task structure for CC1101 operations
struct CC1101Task {
    CC1101Command command;
    int module;  // 0 or 1
    
    // For detection
    int minRssi;
    bool isBackground;
    
    // For recording
    float frequency;
    int modulation;
    float deviation;
    float rxBandwidth;
    float dataRate;
    std::string preset;
    
    // For transmission
    std::string filename;
    int repeat;
    int pathType;
    
    // For jamming
    int power;
    Device::JamPatternType patternType;
    std::vector<uint8_t> customPatternData;  // Owned deep-copy (no dangling pointer)
    bool hasCustomPattern;
    uint32_t maxDurationMs;
    uint32_t cooldownMs;
    
    CC1101Task() : 
        command(CC1101Command::GoIdle),
        module(0),
        minRssi(-50),
        isBackground(false),
        frequency(433.92),
        modulation(2),  // ASK_OOK
        deviation(2.380371),
        rxBandwidth(650),
        dataRate(3.79372),
        preset("Ook650"),
        repeat(1),
        pathType(0),
        power(7),
        patternType(Device::JamPatternType::Random),
        hasCustomPattern(false),
        maxDurationMs(60000),
        cooldownMs(5000) {}
};

class CC1101Worker {
public:
    static void init(SignalDetectedCallback detectedCb, SignalRecordedCallback recordedCb);
    static void start();
    static QueueHandle_t getQueue() { return taskQueue; }
    
    // Helper functions to send commands
    static bool startDetect(int module, int minRssi, bool isBackground);
    static bool stopDetect(int module);
    static bool startRecord(int module, float frequency, int modulation, float deviation, 
                           float rxBandwidth, float dataRate, const std::string& preset);
    static bool stopRecord(int module);
    static bool transmit(int module, const std::string& filename, int repeat, int pathType);
    static bool goIdle(int module);
    static bool startAnalyzer(int module, float startFreq, float endFreq, float step, uint32_t dwellTime);
    static bool stopAnalyzer(int module);
    static bool startJam(int module, float frequency, int power, 
                         Device::JamPatternType patternType, const std::vector<uint8_t>* customPattern,
                         uint32_t maxDurationMs, uint32_t cooldownMs);
    static bool stopJam(int module);
    
    // Get current state
    static CC1101State getState(int module);
    
    // Find first idle module
    static int findFirstIdleModule();

private:
    static void workerTask(void* parameter);
    static void processTask(const CC1101Task& task);
    
    // Individual operation handlers
    static void handleStartDetect(int module, int minRssi, bool isBackground);
    static void handleStopDetect(int module);
    static void handleStartRecord(int module, const CC1101Task& config);
    static void handleStopRecord(int module);
    static void handleTransmit(int module, const std::string& filename, int repeat, int pathType);
    static void handleStartAnalyzer(int module, float startFreq, float endFreq, float step, uint32_t dwellTime);
    static void handleStopAnalyzer(int module);
    static void handleGoIdle(int module);
    static void handleStartJam(int module, float frequency, int power,
                               Device::JamPatternType patternType, const std::vector<uint8_t>& customPatternData,
                               bool hasCustomPattern, uint32_t maxDurationMs, uint32_t cooldownMs);
    static void handleStopJam(int module);
    
    // Worker loop handlers
    static void processDetecting(int module);
    static void processRecording(int module);
    static void processAnalyzing(int module);
    static void processJamming(int module);
    
    // Detection logic (from Detector)
    static bool detectSignal(int module, int minRssi, bool isBackground);
    
    // Recording helpers
    static void checkAndSaveRecording(int module);
    
    // Transmission helpers (moved from Transmitter)
    static std::string transmitSub(const std::string& filename, int module, int repeat, int pathType);
    static bool transmitBinary(float frequency, int pulseDuration, const std::string& bits, int module, int modulation, float deviation, int repeatCount, int wait);
    static bool transmitRaw(int module, float frequency, int modulation, float deviation, std::string& data, int repeat);
    static bool transmitData(PulsePayload& payload, int module);
    
    // Template version for streaming payload (works with any type that has next())
    template<typename PayloadT>
    static bool transmitData(PayloadT& payload, int module) {
        uint32_t duration;
        bool pinState;
        
        while (payload.next(duration, pinState)) {
            digitalWrite(moduleCC1101State[module].getOutputPin(), pinState);
            delayMicroseconds(duration);
            taskYIELD();
        }
        
        return true;
    }
    
    // Private transmission helpers
    static std::vector<int> getCountOfOnOffBits(const std::string& bits);
    static bool transmitRawData(const std::vector<int>& rawData, int module);
    
    // ISR and interrupt management for recording (moved from Recorder)
    static void IRAM_ATTR receiveSample(int module);
    static void IRAM_ATTR receiver(void* arg);
    static void addModuleReceiver(int module);
    static void removeModuleReceiver(int module);
    static void clearReceivedSamples(int module);
    static ReceivedSamples& getReceivedData(int module);
    
    // Notification helper
    static void sendModeNotification(int module, CC1101State state);
    static void sendHeartbeat();
    
    static QueueHandle_t taskQueue;
    static TaskHandle_t workerTaskHandle;
    
    static CC1101State moduleStates[CC1101_NUM_MODULES];
    static int detectionMinRssi[CC1101_NUM_MODULES];
    static bool detectionIsBackground[CC1101_NUM_MODULES];
    
    // Recording config per module
    struct RecordingConfig {
        float frequency;
        int modulation;
        float deviation;
        float rxBandwidth;
        float dataRate;
        std::string preset;
    };
    static RecordingConfig recordingConfigs[CC1101_NUM_MODULES];
    
    // Jamming config per module
    struct JammingConfig {
        float frequency;
        int modulation;
        float deviation;
        int power;
        Device::JamPatternType patternType;
        std::vector<uint8_t> customPattern;
        uint32_t maxDurationMs;
        uint32_t cooldownMs;
        uint32_t startTimeMs;
        bool isCooldown;
        uint32_t cooldownStartTimeMs;
        bool useDirectPinControl;  // Use direct pin control instead of sendData
        byte gdo0Pin;  // GDO0 pin for direct control
        bool pinInitialized;  // Flag to track if pin was initialized for continuous TX
        bool fifoInitialized;  // Flag to track if FIFO was initialized
    };
    static JammingConfig jammingConfigs[CC1101_NUM_MODULES];
    
    // Pattern generation helpers
    static uint8_t generateJamPatternByte(int module, size_t index);
    static void generateJamPattern(int module, uint8_t* buffer, size_t length);
    
    // Callbacks
    static SignalDetectedCallback signalDetectedCallback;
    static SignalRecordedCallback signalRecordedCallback;
    
    // Detection frequencies (from Detector)
    static float signalDetectionFrequencies[];
    static constexpr int SIGNAL_DETECTION_FREQUENCIES_LENGTH = 18;
    
    // Recording ISR data structures (moved from Recorder)
    static portMUX_TYPE samplesMuxes[CC1101_NUM_MODULES];
    static ReceivedSamples receivedSamples[CC1101_NUM_MODULES];
};

#endif // CC1101Worker_h

