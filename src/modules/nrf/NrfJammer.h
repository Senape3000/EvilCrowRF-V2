/**
 * @file NrfJammer.h
 * @brief 2.4 GHz jammer using nRF24L01+ constant carrier and data flooding.
 *
 * Supports multiple jamming modes: full-band, WiFi channels, BLE channels,
 * Bluetooth, BLE advertising, Zigbee, Drone, USB, video, RC, and custom
 * channel range hopping.
 *
 * Uses two jamming strategies depending on the target:
 *  - Constant Carrier (CW): Best for FHSS targets (Bluetooth, Drones)
 *  - Data Flooding (writeFast): Best for channel-specific targets (WiFi, BLE, Zigbee)
 */

#ifndef NRF_JAMMER_H
#define NRF_JAMMER_H

#include <Arduino.h>
#include <stdint.h>

/// Jamming mode presets
enum NrfJamMode : uint8_t {
    NRF_JAM_FULL       = 0,  // All channels 1-124
    NRF_JAM_WIFI       = 1,  // WiFi channel centers + bandwidth
    NRF_JAM_BLE        = 2,  // BLE data channels
    NRF_JAM_BLE_ADV    = 3,  // BLE advertising channels (37,38,39)
    NRF_JAM_BLUETOOTH  = 4,  // Classic Bluetooth (FHSS)
    NRF_JAM_USB        = 5,  // USB wireless
    NRF_JAM_VIDEO      = 6,  // Video streaming
    NRF_JAM_RC         = 7,  // RC controllers
    NRF_JAM_SINGLE     = 8,  // Single channel constant carrier
    NRF_JAM_HOPPER     = 9,  // Custom range hopper
    NRF_JAM_ZIGBEE     = 10, // Zigbee channels 11-26
    NRF_JAM_DRONE      = 11, // Drone: full band random hop
};

/// Hopper configuration for NRF_JAM_HOPPER mode
struct NrfHopperConfig {
    uint8_t startChannel;  // 0-124
    uint8_t stopChannel;   // 0-124
    uint8_t stepSize;      // 1-10
};

/// Total number of configurable jam modes (0-11)
#define NRF_JAM_MODE_COUNT 12

/**
 * Per-mode jamming configuration.
 * Each mode can have its own optimal RF parameters.
 * Persisted in /nrf_jam_cfg.bin on LittleFS.
 *
 * The E01-ML01SP2 module (NRF24L01+ with PA+LNA) amplifies the
 * NRF24L01+'s output (+20dBm max), so PA=3 (0dBm chip) becomes
 * approximately +20dBm at the antenna.
 */
struct NrfJamModeConfig {
    uint8_t  paLevel;       // 0-3 (0=MIN -18dBm, 3=MAX 0dBm → +20dBm with PA)
    uint8_t  dataRate;      // 0=1Mbps, 1=2Mbps, 2=250Kbps
    uint16_t dwellTimeMs;   // Time on each channel in ms (0-200, 0=turbo/no delay)
    uint8_t  useFlooding;   // 0=Constant Carrier (CW), 1=Data Flooding
    uint8_t  floodBursts;   // Number of flood packets per channel hop (1-20)
};

/// Static info about a jammer mode (compiled into flash)
struct NrfJamModeInfo {
    const char*    name;          // Short display name
    const char*    description;   // What this mode targets
    const uint8_t* channels;      // Channel list (nullptr = special logic)
    size_t         channelCount;  // Number of channels
    uint16_t       freqStartMHz;  // Approximate start freq (for display)
    uint16_t       freqEndMHz;    // Approximate end freq (for display)
};

/**
 * @class NrfJammer
 * @brief 2.4 GHz jammer with multiple mode presets and per-mode tuning.
 *
 * Each of the 12 modes has independent RF parameters (PA, data rate,
 * dwell time, CW vs flooding) that can be adjusted from the app and
 * persisted in flash.  The dwell time is the key parameter for
 * jamming effectiveness: too fast and the target escapes between hops,
 * too slow and you miss FHSS channels.
 */
class NrfJammer {
public:
    /**
     * Start jamming in a preset mode.
     * @param mode  Jamming mode preset.
     * @return true if started.
     */
    static bool start(NrfJamMode mode);

    /**
     * Start single-channel jamming.
     * @param channel  Channel to jam (0-124).
     * @return true if started.
     */
    static bool startSingleChannel(uint8_t channel);

    /**
     * Start custom range hopper.
     * @param config  Hopper parameters.
     * @return true if started.
     */
    static bool startHopper(const NrfHopperConfig& config);

    /// Change jamming mode while running (hot-swap).
    static bool setMode(NrfJamMode mode);

    /// Change channel live during single-channel jamming.
    /// Called from BLE command 0x2D — takes effect on next loop iteration.
    static bool setChannel(uint8_t channel);

    /// Update dwell time live during jamming (takes effect immediately).
    static bool setDwellTime(uint16_t ms);

    /// Stop jamming.
    static void stop();

    /// @return true if jammer is active.
    static bool isRunning() { return running_; }

    /// @return current jamming mode.
    static NrfJamMode getMode() { return currentMode_; }

    /// @return current channel (for single-channel mode).
    static uint8_t getCurrentChannel() { return currentChannel_; }

    // ── Per-mode configuration ──────────────────────────────────

    /// Get the current config for a specific mode.
    static const NrfJamModeConfig& getModeConfig(NrfJamMode mode);

    /// Update config for a specific mode and optionally persist.
    static bool setModeConfig(NrfJamMode mode, const NrfJamModeConfig& cfg, bool persist = true);

    /// Get static info (name, description, channels) for a mode.
    static const NrfJamModeInfo& getModeInfo(NrfJamMode mode);

    /// Load all per-mode configs from flash (called at boot).
    static void loadConfigs();

    /// Save all per-mode configs to flash.
    static bool saveConfigs();

    /// Reset all per-mode configs to optimal defaults.
    static void resetToDefaults();

private:
    static volatile bool running_;
    static volatile bool stopRequest_;
    static TaskHandle_t  taskHandle_;
    static NrfJamMode    currentMode_;
    static volatile uint8_t currentChannel_;
    static NrfHopperConfig hopperConfig_;

    /// Per-mode configuration array (index = NrfJamMode enum value)
    static NrfJamModeConfig modeConfigs_[NRF_JAM_MODE_COUNT];

    /// Background jamming task.
    static void jammerTask(void* param);

    /// Get channel list for a given mode.
    static const uint8_t* getChannelList(NrfJamMode mode, size_t& count);

    /// Apply the current mode's RF settings to the NRF hardware.
    static void applyModeConfig(NrfJamMode mode, bool flooding);

    /// Continuous flood one channel for the given dwell time.
    /// Holds CE HIGH and feeds TX FIFO for back-to-back packet TX.
    /// When dwellMs=0, sends a single burst (3 FIFO packets) and hops.
    static void floodOnChannel(uint8_t channel, uint16_t dwellMs);

    /// CW (constant carrier) hop helper: stays on channel for dwellMs.
    /// Uses delayMicroseconds for sub-ms precision instead of vTaskDelay.
    /// When dwellMs=0, hops immediately (SPI overhead only ~20µs).
    static void cwOnChannel(uint8_t channel, uint16_t dwellMs);

    /// Populate modeConfigs_ with optimal defaults per mode.
    static void setDefaults();
};

#endif // NRF_JAMMER_H
