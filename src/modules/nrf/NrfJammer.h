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

/**
 * @class NrfJammer
 * @brief 2.4 GHz jammer with multiple mode presets.
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

    /// Change jamming mode while running.
    static bool setMode(NrfJamMode mode);

    /// Change channel in single-channel mode.
    static bool setChannel(uint8_t channel);

    /// Stop jamming.
    static void stop();

    /// @return true if jammer is active.
    static bool isRunning() { return running_; }

    /// @return current jamming mode.
    static NrfJamMode getMode() { return currentMode_; }

    /// @return current channel (for single-channel mode).
    static uint8_t getCurrentChannel() { return currentChannel_; }

private:
    static volatile bool running_;
    static volatile bool stopRequest_;
    static TaskHandle_t  taskHandle_;
    static NrfJamMode    currentMode_;
    static uint8_t       currentChannel_;
    static NrfHopperConfig hopperConfig_;

    /// Background jamming task.
    static void jammerTask(void* param);

    /// Get channel list for a given mode.
    static const uint8_t* getChannelList(NrfJamMode mode, size_t& count);
};

#endif // NRF_JAMMER_H
