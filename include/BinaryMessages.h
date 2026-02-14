#ifndef BinaryMessages_h
#define BinaryMessages_h

#include <stdint.h>

#pragma pack(push, 1)

// Message type IDs (0x80-0xFF reserved for responses)
enum BinaryMessageType : uint8_t {
    // Status & State messages
    MSG_MODE_SWITCH = 0x80,      // Mode changed
    MSG_STATUS = 0x81,           // Current status
    MSG_HEARTBEAT = 0x82,        // Heartbeat
    
    // Signal events
    MSG_SIGNAL_DETECTED = 0x90,
    MSG_SIGNAL_RECORDED = 0x91,
    MSG_SIGNAL_SENT = 0x92,
    MSG_SIGNAL_SEND_ERROR = 0x93,
    // NOTE: 0x94 is reserved but never sent by firmware.
    // Frequency search results use MSG_SIGNAL_DETECTED (0x90) via the
    // CC1101Worker::detectSignal → signalDetectedCallback pipeline.
    MSG_FREQUENCY_SEARCH = 0x94,  // Reserved — frequency search uses 0x90 instead
    
    // File operations
    MSG_FILE_CONTENT = 0xA0,     // Raw file content chunks
    MSG_FILE_LIST = 0xA1,        // File list STREAMING: [0xA1][pathLen][path][flags][totalFiles:2][fileCount][files...]
    MSG_DIRECTORY_TREE = 0xA2,   // Directory tree (nested structure, directories only)
    MSG_FILE_ACTION_RESULT = 0xA3, // Result of file action (rename, delete, etc.)
    
    // Errors
    MSG_ERROR = 0xF0,
    MSG_LOW_MEMORY = 0xF1,
    
    // Command results (generic)
    MSG_COMMAND_SUCCESS = 0xF2,  // Generic success
    MSG_COMMAND_ERROR = 0xF3,    // Generic error
    
    // Bruter events
    MSG_BRUTER_PROGRESS = 0xB0,  // Brute force progress update
    MSG_BRUTER_COMPLETE = 0xB1,  // Brute force attack finished
    MSG_BRUTER_PAUSED   = 0xB2,  // Brute force attack paused (state saved)
    MSG_BRUTER_RESUMED  = 0xB3,  // Brute force attack resumed from saved state
    MSG_BRUTER_STATE_AVAIL = 0xB4, // A resumable state exists on LittleFS
    
    // Settings synchronization
    MSG_SETTINGS_SYNC   = 0xC0,  // Device → App: current persistent settings
    MSG_SETTINGS_UPDATE = 0xC1,  // App → Device: update settings (command byte)
    MSG_VERSION_INFO    = 0xC2,  // Device → App: firmware version info
    MSG_BATTERY_STATUS  = 0xC3,  // Device → App: battery voltage and percentage
    
    // NRF24 events
    MSG_NRF_DEVICE_FOUND    = 0xD0, // Device discovered during MouseJack scan
    MSG_NRF_ATTACK_COMPLETE = 0xD1, // MouseJack attack finished
    MSG_NRF_SCAN_COMPLETE   = 0xD2, // Full scan cycle done
    MSG_NRF_SCAN_STATUS     = 0xD3, // Scan status + target list response
    MSG_NRF_SPECTRUM_DATA   = 0xD4, // 80-channel spectrum levels
    MSG_NRF_JAM_STATUS      = 0xD5, // Jammer status update
    MSG_NRF_JAM_MODE_CONFIG = 0xD6, // Per-mode config response/update
    MSG_NRF_JAM_MODE_INFO   = 0xD7, // Mode info (channels, description)
    
    // SDR mode events
    MSG_SDR_STATUS        = 0xC4,  // Device → App: SDR mode status
    MSG_SDR_SPECTRUM_DATA = 0xC5,  // Device → App: spectrum scan results (chunked)
    MSG_SDR_RAW_DATA      = 0xC6,  // Device → App: raw RX data chunk

    // OTA update events
    MSG_OTA_PROGRESS  = 0xE0, // OTA progress: [received:4][total:4][pct:1]
    MSG_OTA_COMPLETE  = 0xE1, // OTA write complete, ready to reboot
    MSG_OTA_ERROR     = 0xE2, // OTA error: [msgLen:1][errorMsg...]

    // Device identity
    MSG_DEVICE_NAME   = 0xC7, // Current BLE device name: [nameLen:1][name...]

    // HW button config sync (sent on GetState)
    MSG_HW_BUTTON_STATUS = 0xC8, // [btn1Action:1][btn2Action:1][btn1PathType:1][btn2PathType:1]

    // SD card storage info (sent on GetState)
    MSG_SD_STATUS     = 0xC9, // [mounted:1][totalMB:2LE][freeMB:2LE]

    // nRF24 module status (sent on GetState)
    MSG_NRF_STATUS    = 0xCA, // [present:1][initialized:1][activeState:1]
};

// Mode switch notification (4 bytes)
struct BinaryModeSwitch {
    uint8_t messageType = MSG_MODE_SWITCH;
    uint8_t module;
    uint8_t currentMode;
    uint8_t previousMode;
};

// Status message with CC1101 registers + CPU telemetry
// Legacy payload: 102 bytes
// New payload: 108 bytes (adds cpuTempDeciC + core0Mhz + core1Mhz)
// 1+1+1+1+4+2+2+2+47+47 = 108 bytes total
struct BinaryStatus {
    uint8_t messageType = MSG_STATUS;
    uint8_t module0Mode;
    uint8_t module1Mode;
    uint8_t numRegisters;           // 0x2E (46 registers)
    uint32_t freeHeap;
    int16_t cpuTempDeciC;           // CPU temperature in deci-°C (e.g. 456 => 45.6°C)
    uint16_t core0Mhz;              // Core 0 clock in MHz
    uint16_t core1Mhz;              // Core 1 clock in MHz
    uint8_t module0Registers[47];   // All CC1101 registers for module 0
    uint8_t module1Registers[47];   // All CC1101 registers for module 1
};

// Heartbeat (5 bytes)
struct BinaryHeartbeat {
    uint8_t messageType = MSG_HEARTBEAT;
    uint32_t uptimeMs;
};

// Signal detected (12 bytes)
struct BinarySignalDetected {
    uint8_t messageType = MSG_SIGNAL_DETECTED;
    uint8_t module;
    uint16_t samples;
    uint32_t frequency;
    int16_t rssi;
    uint16_t reserved;
};

// Signal recorded (5 bytes + filename)
struct BinarySignalRecorded {
    uint8_t messageType = MSG_SIGNAL_RECORDED;
    uint8_t module;
    uint8_t filenameLength;
    // char filename[]; // Variable length follows
};

// Signal sent result
struct BinarySignalSent {
    uint8_t messageType = MSG_SIGNAL_SENT;
    uint8_t module;
    uint8_t filenameLength;
    // char filename[];
};

// Signal send error
struct BinarySignalSendError {
    uint8_t messageType = MSG_SIGNAL_SEND_ERROR;
    uint8_t module;
    uint8_t errorCode;
    uint8_t filenameLength;
    // char filename[];
};

// Error message (2 bytes + message)
struct BinaryError {
    uint8_t messageType = MSG_ERROR;
    uint8_t errorCode;
    // char message[]; // Variable length follows
};

// File action result (variable length)
// [type][action:1][status:1][errorCode:1][pathLen:1][path...]
struct BinaryFileActionResult {
    uint8_t messageType = MSG_FILE_ACTION_RESULT;
    uint8_t action;         // 1=delete, 2=rename, 3=mkdir, 4=copy, 5=move
    uint8_t status;         // 0=success, 1=error
    uint8_t errorCode;      // Optional error code
    uint8_t pathLen;
    // char path[];        // Path or filename follows
};

// Bruter progress update (13 bytes)
// Sent periodically during brute force attacks
struct BinaryBruterProgress {
    uint8_t messageType = MSG_BRUTER_PROGRESS;
    uint32_t currentCode;   // Current code index
    uint32_t totalCodes;    // Total codes to try
    uint8_t  menuId;        // Protocol menu ID (1-33)
    uint8_t  percentage;    // 0-100 percentage complete
    uint16_t codesPerSec;   // Estimated codes per second
};

// Bruter attack complete (8 bytes)
// Sent when brute force attack finishes (complete or cancelled)
struct BinaryBruterComplete {
    uint8_t messageType = MSG_BRUTER_COMPLETE;
    uint8_t menuId;         // Protocol menu ID (1-40)
    uint8_t status;         // 0=completed, 1=cancelled, 2=error
    uint8_t reserved;
    uint32_t totalSent;     // Total codes actually transmitted
};

// Bruter paused notification (13 bytes packed)
// Sent when the attack is paused and state has been saved to LittleFS
struct BinaryBruterPaused {
    uint8_t  messageType = MSG_BRUTER_PAUSED;
    uint8_t  menuId;         // Protocol that was paused
    uint32_t currentCode;    // Code index at pause point
    uint32_t totalCodes;     // Total keyspace
    uint8_t  percentage;     // Progress at pause
    uint8_t  reserved[2];
};

// Bruter resumed notification (13 bytes packed)
// Sent when an attack resumes from a saved state
struct BinaryBruterResumed {
    uint8_t  messageType = MSG_BRUTER_RESUMED;
    uint8_t  menuId;         // Protocol being resumed
    uint32_t resumeCode;     // Code index where resumption starts
    uint32_t totalCodes;     // Total keyspace
    uint8_t  reserved[3];
};

// Bruter saved state available notification (13 bytes packed)
// Sent on connect / on request to inform app that a resume is possible
struct BinaryBruterStateAvail {
    uint8_t  messageType = MSG_BRUTER_STATE_AVAIL;
    uint8_t  menuId;         // Protocol that was paused
    uint32_t currentCode;    // Code index at pause
    uint32_t totalCodes;     // Total keyspace
    uint8_t  percentage;     // Progress at pause
    uint8_t  reserved[2];
};

// Settings sync notification (8 bytes)
// Sent on BLE connect to synchronize app with device settings.
// [0xC0][scannerRssi:int8][bruterPower:u8][delayLo:u8][delayHi:u8][bruterRepeats:u8][radioPowerMod1:int8][radioPowerMod2:int8]
struct BinarySettingsSync {
    uint8_t messageType = MSG_SETTINGS_SYNC;
    int8_t  scannerRssi;
    uint8_t bruterPower;
    uint16_t bruterDelay;
    uint8_t bruterRepeats;
    int8_t  radioPowerMod1;
    int8_t  radioPowerMod2;
};

// Firmware version info (4 bytes)
// Sent on BLE connect (with getState) so the app can compare versions.
// [0xC2][major:u8][minor:u8][patch:u8]
struct BinaryVersionInfo {
    uint8_t messageType = MSG_VERSION_INFO;
    uint8_t major;
    uint8_t minor;
    uint8_t patch;
};

// Battery status (5 bytes)
// Sent periodically (every 30s) and on BLE connect with settings sync.
// [0xC3][voltage_mv:2 LE][percentage:1][charging:1]
struct BinaryBatteryStatus {
    uint8_t  messageType = MSG_BATTERY_STATUS;
    uint16_t voltage_mv;   // Battery voltage in millivolts (e.g., 3700 = 3.7V)
    uint8_t  percentage;   // 0-100%
    uint8_t  charging;     // 0 = not charging, 1 = charging
};

// SDR status (7 bytes)
// Sent when SDR mode changes or status is requested.
// [0xC4][active:1][module:1][freq_khz:4LE][modulation:1]
struct BinarySdrStatus {
    uint8_t  messageType = MSG_SDR_STATUS;
    uint8_t  active;       // 0 = SDR off, 1 = SDR on
    uint8_t  module;       // CC1101 module index used (0 or 1)
    uint32_t freq_khz;     // Current center frequency in kHz
    uint8_t  modulation;   // Current modulation type
};

// SDR spectrum data chunk (variable length)
// Sent as multiple chunks during spectrum scan.
// [0xC5][chunkIndex:1][totalChunks:1][pointsInChunk:1][startFreqKhz:4LE]{rssi_dBm:int8}...
struct BinarySdrSpectrumHeader {
    uint8_t  messageType = MSG_SDR_SPECTRUM_DATA;
    uint8_t  chunkIndex;       // Current chunk (0-based)
    uint8_t  totalChunks;      // Total chunks
    uint8_t  pointsInChunk;    // Number of RSSI values in this chunk
    uint32_t startFreq_khz;    // Start frequency of this chunk in kHz
    uint16_t stepSize_khz;     // Step size in kHz between points
    // int8_t rssi[];           // Variable: pointsInChunk RSSI values (dBm)
};

// SDR raw RX data chunk (variable length)
// [0xC6][seqNum:2LE][dataLen:1][data...]
struct BinarySdrRawDataHeader {
    uint8_t  messageType = MSG_SDR_RAW_DATA;
    uint16_t seqNum;       // Sequence number for ordering
    uint8_t  dataLen;      // Number of data bytes following
    // uint8_t data[];      // Variable: raw demodulated bytes from CC1101 FIFO
};

// HW button status (5 bytes)
// Sent on BLE connect (GetState) to sync app with current button config.
// [0xC8][btn1Action:1][btn2Action:1][btn1PathType:1][btn2PathType:1]
struct BinaryHwButtonStatus {
    uint8_t messageType = MSG_HW_BUTTON_STATUS;
    uint8_t btn1Action;      // HwButtonAction enum index (0-6)
    uint8_t btn2Action;      // HwButtonAction enum index (0-6)
    uint8_t btn1PathType;    // Path type for replay (0-5)
    uint8_t btn2PathType;    // Path type for replay (0-5)
};

// SD card status (6 bytes)
// Sent on BLE connect (GetState) to show storage info in app.
// [0xC9][mounted:1][totalMB:2LE][freeMB:2LE]
struct BinarySdStatus {
    uint8_t  messageType = MSG_SD_STATUS;
    uint8_t  mounted;      // 0 = not mounted, 1 = mounted
    uint16_t totalMB;      // Total size in MB
    uint16_t freeMB;       // Free space in MB
};

// nRF24 module status (4 bytes)
// Sent on BLE connect (GetState) to show nRF24 state in Device Status.
// [0xCA][present:1][initialized:1][activeState:1]
struct BinaryNrfStatus {
    uint8_t messageType = MSG_NRF_STATUS;
    uint8_t present;       // 0 = not present, 1 = present
    uint8_t initialized;   // 0 = not initialized, 1 = initialized
    uint8_t activeState;   // 0=idle, 1=jamming, 2=scanning, 3=attacking, 4=spectrum
};

#pragma pack(pop)

#endif // BinaryMessages_h

