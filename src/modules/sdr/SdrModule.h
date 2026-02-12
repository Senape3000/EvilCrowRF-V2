/**
 * @file SdrModule.h
 * @brief Software Defined Radio mode for EvilCrow-RF-V2.
 *
 * Provides SDR-like functionality using the CC1101 transceiver:
 *   - Spectrum scanning (frequency sweep with RSSI readings)
 *   - Raw RX streaming (demodulated bytes from CC1101 FIFO)
 *   - Signal scanner (detect active frequencies above threshold)
 *   - HackRF-compatible serial command interface for PC tools
 *
 * IMPORTANT: The CC1101 is NOT a true SDR — it is a digital transceiver
 * with built-in modulation/demodulation. This module provides the closest
 * SDR-like experience possible:
 *   - Spectrum data is real RSSI measurements at each frequency step
 *   - Raw RX data is demodulated bytes from the CC1101 FIFO, not raw IQ
 *   - Pseudo-IQ can be constructed from RSSI + FREQEST registers
 *
 * When SDR mode is active, other CC1101 operations (record, transmit,
 * detect, jam) are blocked to prevent hardware conflicts.
 *
 * Interfaces:
 *   - BLE: Binary commands from app (0x50-0x59)
 *   - Serial: Text commands from PC tools (HackRF-compatible)
 */

#ifndef SDR_MODULE_H
#define SDR_MODULE_H

#include <Arduino.h>
#include "config.h"

#if SDR_MODULE_ENABLED

#include "BinaryMessages.h"
#include "core/ble/ClientsManager.h"
#include "modules/CC1101_driver/CC1101_Module.h"
#include "esp_log.h"

/**
 * SDR operating sub-mode within SDR mode.
 */
enum class SdrSubMode : uint8_t {
    Idle = 0,           // SDR mode on, but not actively scanning/streaming
    SpectrumScan = 1,   // Sweeping frequencies, reading RSSI
    RawRx = 2,          // Streaming demodulated bytes from FIFO
    SignalScanner = 3   // Scanning for active frequencies above threshold
};

/**
 * Spectrum scan configuration.
 */
struct SpectrumScanConfig {
    float startFreqMHz = 300.0f;    // Start frequency in MHz
    float endFreqMHz   = 928.0f;    // End frequency in MHz
    float stepMHz      = 0.1f;      // Step size in MHz (default SDR_SPECTRUM_STEP_KHZ / 1000)
    int8_t rssiThreshold = -90;     // Minimum RSSI to report (dBm), for signal scanner
};

/**
 * SDR module state (read-only snapshot for status queries).
 */
struct SdrState {
    bool active;              // True if SDR mode is enabled
    SdrSubMode subMode;       // Current sub-mode
    int module;               // CC1101 module index in use
    float centerFreqMHz;      // Current center frequency
    int modulation;           // Current modulation type
    uint32_t samplesStreamed;  // Total raw bytes streamed in current session
};

class SdrModule {
public:
    /**
     * Initialize SDR module (call once from setup).
     * Does NOT activate SDR mode — just prepares internal state.
     */
    static void init();

    // ── SDR mode lifecycle ──────────────────────────────────────────

    /**
     * Enable SDR mode. Puts the assigned CC1101 module in IDLE and
     * blocks other CC1101 operations.
     * @param module CC1101 module index (0 or 1). Default: SDR_DEFAULT_MODULE.
     * @return true if successfully enabled.
     */
    static bool enable(int module = SDR_DEFAULT_MODULE);

    /**
     * Disable SDR mode. Restores the CC1101 module to normal operation.
     * @return true if successfully disabled.
     */
    static bool disable();

    /** @return true if SDR mode is currently active. */
    static bool isActive() { return active_; }

    /** @return Current state snapshot. */
    static SdrState getState();

    // ── Frequency and configuration ─────────────────────────────────

    /**
     * Set center frequency for RX/spectrum operations.
     * @param freqMHz Frequency in MHz (valid range: 300–928 MHz).
     * @return true if frequency is valid and applied.
     */
    static bool setFrequency(float freqMHz);

    /**
     * Set modulation type.
     * @param mod Modulation constant (MODULATION_ASK_OOK, MODULATION_2_FSK, etc.)
     * @return true if applied.
     */
    static bool setModulation(int mod);

    /**
     * Set RX bandwidth.
     * @param bwKHz Bandwidth in kHz.
     * @return true if applied.
     */
    static bool setBandwidth(float bwKHz);

    /**
     * Set data rate.
     * @param rate Data rate in kBaud.
     * @return true if applied.
     */
    static bool setDataRate(float rate);

    // ── Spectrum scan ───────────────────────────────────────────────

    /**
     * Start a spectrum scan. Sweeps from startFreq to endFreq reading RSSI.
     * Results are sent via BLE as MSG_SDR_SPECTRUM_DATA chunks.
     * This is a blocking operation (runs on the calling task).
     * @param config Scan configuration.
     * @return Number of frequency points scanned.
     */
    static int spectrumScan(const SpectrumScanConfig& config);

    // ── Raw RX streaming ────────────────────────────────────────────

    /**
     * Start raw RX streaming via serial. CC1101 FIFO bytes are read
     * and sent over serial in binary format.
     * @return true if started successfully.
     */
    static bool startRawRx();

    /** Stop raw RX streaming. */
    static void stopRawRx();

    /** @return true if raw RX streaming is active. */
    static bool isStreaming() { return streaming_; }

    /**
     * Poll for raw RX data. Call from a loop/task while streaming.
     * Reads FIFO and sends data via serial (and optionally BLE).
     */
    static void pollRawRx();

    // ── Serial SDR command interface ────────────────────────────────

    /**
     * Process a text command received over serial (HackRF-compatible).
     * @param command The command string (without newline).
     * @return true if command was recognized and handled.
     */
    static bool processSerialCommand(const String& command);

    // ── BLE notification helpers ────────────────────────────────────

    /** Send current SDR status via BLE (MSG_SDR_STATUS). */
    static void sendStatus();

    /** @return The CC1101 module index assigned to SDR. */
    static int getModule() { return sdrModule_; }

private:
    static bool active_;
    static bool streaming_;
    static bool initialized_;
    static int  sdrModule_;           // CC1101 module index (0 or 1)
    static float currentFreqMHz_;
    static int  currentModulation_;
    static float currentBandwidthKHz_;
    static float currentDataRate_;
    static uint32_t streamSeqNum_;    // Sequence number for raw RX packets
    static uint32_t totalBytesStreamed_;
    static SdrSubMode subMode_;

    /**
     * Read RSSI at the current frequency.
     * Puts CC1101 in RX, waits for RSSI to settle, reads register.
     * @return RSSI in dBm.
     */
    static int readRssi();

    /**
     * Send spectrum scan results chunk via BLE.
     * @param rssiValues Array of RSSI readings.
     * @param count Number of readings.
     * @param startFreqKhz Start frequency of this chunk in kHz.
     * @param stepKhz Step size in kHz.
     * @param chunkIndex Current chunk index.
     * @param totalChunks Total number of chunks.
     */
    static void sendSpectrumChunk(const int8_t* rssiValues, uint8_t count,
                                  uint32_t startFreqKhz, uint16_t stepKhz,
                                  uint8_t chunkIndex, uint8_t totalChunks);

    /**
     * Send raw RX data chunk via BLE.
     * @param data Raw bytes from CC1101 FIFO.
     * @param len Number of bytes.
     */
    static void sendRawDataChunk(const uint8_t* data, uint8_t len);

    /// Validate frequency is within CC1101 supported range.
    static bool isValidFrequency(float freqMHz);
};

#endif // SDR_MODULE_ENABLED
#endif // SDR_MODULE_H
