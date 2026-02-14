// ========================================
// FIRMWARE VERSION — Update here on every release!
// ========================================
// Format: MAJOR.MINOR.PATCH
// - MAJOR: Breaking changes to BLE protocol or hardware support
// - MINOR: New features, new protocols, UI commands
// - PATCH: Bug fixes, optimizations
// The app will compare these values for FW update matching.
#define FIRMWARE_VERSION_MAJOR 1
#define FIRMWARE_VERSION_MINOR 0
#define FIRMWARE_VERSION_PATCH 5
#define FIRMWARE_VERSION_STRING "1.0.5"

#define CC1101_NUM_MODULES 2

// Modulation types
#define MODULATION_2_FSK 0
#define MODULATION_GFSK 1
#define MODULATION_ASK_OOK 2
#define MODULATION_4_FSK 3
#define MODULATION_MSK 4

#if defined(ESP8266)
    #define RECEIVE_ATTR ICACHE_RAM_ATTR
#elif defined(ESP32)
    #define RECEIVE_ATTR IRAM_ATTR
#else
    #define RECEIVE_ATTR
#endif

#define MIN_SAMPLE 30
#define MIN_PULSE_DURATION 50
#define MAX_SIGNAL_DURATION 100000

#define SERIAL_BAUDRATE 115200

// Tasks params
#define NOTIFICATIONS_QUEUE 5  // Reduced from 10 to save ~2KB heap

/* I/O */
// SPI devices
#define SD_SCLK 18
#define SD_MISO 19
#define SD_MOSI 23
#define SD_SS   22

#define CC1101_SCK  14
#define CC1101_MISO 12
#define CC1101_MOSI 13
#define CC1101_SS0   5 
#define CC1101_SS1 27
#define MOD0_GDO0 2
#define MOD0_GDO2 4
#define MOD1_GDO0 25
#define MOD1_GDO2 26

// nRF24L01 MouseJack module
#define NRF_MODULE_ENABLED 1
#define NRF_CE   33    // Chip Enable
#define NRF_CSN  15    // Chip Select (SPI)
// nRF24 shares HSPI bus (SCK=14, MISO=12, MOSI=13) with CC1101 modules

// OTA firmware update
#define OTA_MODULE_ENABLED 1

// Battery monitoring via ADC
// GPIO 36 (VP) connected to battery through voltage divider
// Voltage divider: GND---100K---GPIO36---220K---VBAT → ratio = (220+100)/100 = 3.2
#define BATTERY_MODULE_ENABLED 1
#define BATTERY_ADC_PIN 36         // GPIO 36 = ADC1_CH0 (input-only)
#define BATTERY_DIVIDER_RATIO 3.2  // Voltage divider ratio: (R1+R2)/R2 = (220K+100K)/100K
#define BATTERY_READ_INTERVAL_MS 30000  // Read every 30 seconds
#define BATTERY_FULL_MV 4200       // Fully charged LiPo voltage (mV)
#define BATTERY_EMPTY_MV 3200      // Empty LiPo voltage (mV)

// Buttons and led
#define LED 32
#define BUTTON1 34
#define BUTTON2 35

// SDR (Software Defined Radio) mode
// Uses one CC1101 module for spectrum scanning, raw RX, and serial SDR interface.
// When active, other CC1101 operations are blocked.
#define SDR_MODULE_ENABLED 1
#define SDR_DEFAULT_MODULE 0           // CC1101 module index to use for SDR (0 or 1)
#define SDR_SPECTRUM_STEP_KHZ 100      // Default frequency step for spectrum scan (kHz)
#define SDR_RSSI_SETTLE_US 1500        // Microseconds to wait for RSSI stabilization
#define SDR_MAX_SPECTRUM_POINTS 200    // Max points per spectrum scan
#define SDR_SERIAL_BAUDRATE 115200     // Serial baud rate for SDR streaming

/* BRUTER MODULE CONFIGURATION */
// Based on EvilCrowRf Bruter v5 config, adapted for our hardware

// --- BRUTER MODULE ENABLE ---
#define BRUTER_MODULE_ENABLED 1  // Enable/disable bruter functionality

// --- RF HARDWARE CONFIG (using our CC1101 module 1) ---
#define BRUTER_CC1101_FREQ_OFFSET 0.052  // Adjust with SDR if possible

// --- PIN DEFINITIONS (matching our config.h) ---
#define BRUTER_RF_CS   CC1101_SS1    // 27 - Second CC1101 module
#define BRUTER_RF_GDO0 MOD1_GDO0    // 25 - GDO0 for module 1
#define BRUTER_RF_TX   MOD1_GDO0    // 25 - TX pin (GDO0 = async serial data input in PKT_FORMAT=3)
#define BRUTER_RF_SCK  CC1101_SCK   // 14
#define BRUTER_RF_MISO CC1101_MISO  // 12
#define BRUTER_RF_MOSI CC1101_MOSI  // 13

// --- BRUTER SPECIFIC ---
#define BRUTER_DEFAULT_REPETITIONS 4  // Default repetitions per code
#define BRUTER_MAX_REPETITIONS 10     // Maximum allowed repetitions
#define BRUTER_INTER_FRAME_GAP_MS 10  // Default gap between frames in ms (configurable via BLE)

// --- PROGRESS REPORTING ---
#define BRUTER_PROGRESS_INTERVAL 32   // Report progress every N codes (small for reactive UI)
#define BRUTER_LED_BLINK_INTERVAL 16  // LED toggle every N codes (fast visible blink)
#define DEBRUIJN_PROGRESS_INTERVAL 256  // Progress interval for De Bruijn (bits)
#define DEBRUIJN_MAX_BITS 16            // Max n for De Bruijn sequence on ESP32

// --- MEMORY MANAGEMENT ---
#define BRUTER_PROTOCOL_BUFFER_SIZE 256  // Buffer for protocol data
#define BRUTER_MAX_PROTOCOLS_LOADED 10   // Limit concurrent protocols to save RAM

// --- TIMING PRECISION ---
#define BRUTER_TIMING_TOLERANCE_US 10  // ±10µs tolerance for pulses

// --- DEBUG & LOGGING ---
#define BRUTER_DEBUG_ENABLED 1  // Enable debug output
#define BRUTER_LOG_PROGRESS_INTERVAL 1000  // Log progress every N codes
