/**
 * @file NrfSpectrum.h
 * @brief 2.4 GHz spectrum analyzer using nRF24L01+ RPD register.
 *
 * Sweeps channels 0-125 (2.400-2.525 GHz, full ISM band) and reports
 * signal strength via BLE notifications for real-time visualization.
 */

#ifndef NRF_SPECTRUM_H
#define NRF_SPECTRUM_H

#include <Arduino.h>
#include <stdint.h>

/// Number of 2.4 GHz channels to scan (0-125 = 126 channels, full nRF24L01+ range)
#define NRF_SPECTRUM_CHANNELS 126

/**
 * @class NrfSpectrum
 * @brief Real-time 2.4 GHz spectrum analyzer.
 *
 * Continuously scans all 126 channels and sends level data
 * via BLE notification. Each channel level is an exponentially
 * weighted moving average of RPD readings.
 */
class NrfSpectrum {
public:
    /// Start spectrum analyzer task.
    static bool start();

    /// Stop spectrum analyzer task.
    static void stop();

    /// @return true if currently scanning.
    static bool isRunning() { return running_; }

    /// Get current channel levels (0-100 scale).
    /// @param[out] levels Array of NRF_SPECTRUM_CHANNELS (126) values.
    static void getLevels(uint8_t* levels);

    /// Single scan sweep (for manual/non-task usage).
    /// Caller must hold SPI mutex.
    static void scanOnce();

    /// Get the raw channel array pointer (read-only).
    static const uint8_t* getRawLevels() { return channelLevels_; }

private:
    static volatile bool running_;
    static volatile bool stopRequest_;
    static TaskHandle_t  taskHandle_;
    static uint8_t       channelLevels_[NRF_SPECTRUM_CHANNELS];

    /// Background task that continuously scans.
    static void spectrumTask(void* param);
};

#endif // NRF_SPECTRUM_H
