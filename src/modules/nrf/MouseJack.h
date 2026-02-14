/**
 * @file MouseJack.h
 * @brief MouseJack scan, fingerprint, and attack logic.
 *
 * Supports Microsoft (encrypted + unencrypted) and Logitech wireless
 * mice/keyboards via nRF24L01+.
 */

#ifndef MOUSEJACK_H
#define MOUSEJACK_H

#include <Arduino.h>
#include <stdint.h>

/// Maximum number of discovered targets to track
#define MJ_MAX_TARGETS 16

/// Device brand/type identification
enum MjDeviceType : uint8_t {
    MJ_DEVICE_NONE       = 0,
    MJ_DEVICE_MICROSOFT  = 1,
    MJ_DEVICE_MS_CRYPT   = 2,  // Microsoft encrypted
    MJ_DEVICE_LOGITECH   = 3,
};

/// MouseJack state machine
enum MjState : uint8_t {
    MJ_IDLE      = 0,
    MJ_SCANNING  = 1,
    MJ_FOUND     = 2,
    MJ_ATTACKING = 3,
};

/// A discovered wireless device target
struct MjTarget {
    uint8_t      address[5];   // nRF address (up to 5 bytes)
    uint8_t      addrLen;      // Address length (2-5)
    uint8_t      channel;      // Channel where device was found
    MjDeviceType type;         // Detected brand
    int8_t       rssi;         // Signal strength indicator
    bool         active;       // Is this slot in use?
};

/**
 * @class MouseJack
 * @brief High-level MouseJack operations (scan + attack).
 *
 * Runs as a FreeRTOS task when scanning or attacking.
 * Must hold the SPI mutex (acquired/released per operation burst).
 */
class MouseJack {
public:
    /// Initialize MouseJack (requires NrfModule::init() first).
    static bool init();

    // ── Scanning ────────────────────────────────────────────────
    /// Start background scan task (channel sweep 2-84).
    static bool startScan();
    /// Stop scan task.
    static void stopScan();

    // ── Target Management ───────────────────────────────────────
    /// Get current list of discovered targets.
    static const MjTarget* getTargets();
    /// Get count of discovered targets.
    static uint8_t getTargetCount();
    /// Clear target list.
    static void clearTargets();

    // ── Attacks ─────────────────────────────────────────────────
    /**
     * Start keystroke injection attack on a specific target.
     * @param targetIndex  Index into targets array.
     * @param hidPayload   Raw HID codes to inject.
     * @param payloadLen   Number of bytes.
     * @return true if attack started.
     */
    static bool startAttack(uint8_t targetIndex,
                            const uint8_t* hidPayload, size_t payloadLen);

    /**
     * Inject an ASCII string as keystrokes.
     * @param targetIndex  Index into targets array.
     * @param text         Null-terminated ASCII string.
     * @return true if attack started.
     */
    static bool injectString(uint8_t targetIndex, const char* text);

    /**
     * Load and execute a DuckyScript file from SD card.
     * @param targetIndex  Index into targets array.
     * @param filePath     Path on SD (e.g., "/DATA/DUCKY/payload.txt").
     * @return true if script loaded and attack started.
     */
    static bool executeDuckyScript(uint8_t targetIndex, const char* filePath);

    /// Stop any running attack.
    static void stopAttack();

    // ── State ───────────────────────────────────────────────────
    static MjState getState() { return state_; }
    static bool isRunning() { return state_ == MJ_SCANNING || state_ == MJ_ATTACKING; }
    /// Expose stop flag for internal helper functions (typeString, sendKeystroke).
    static bool getStopRequest() { return stopRequest_; }

    // ── Protocol TX (public so file-scope helpers can call them) ─
    static void msTransmit(const MjTarget& target, uint8_t meta, uint8_t hid);
    static void logTransmit(const MjTarget& target, uint8_t meta,
                            const uint8_t* keys, uint8_t keysLen);

private:
    static MjState   state_;
    static MjTarget  targets_[MJ_MAX_TARGETS];
    static uint8_t   targetCount_;
    static uint16_t  msSequence_;      // Microsoft frame sequence counter
    static volatile bool stopRequest_; // Signal to stop current operation

    // FreeRTOS task handle
    static TaskHandle_t taskHandle_;

    // ── Internal scan logic ─────────────────────────────────────
    static void scanTask(void* param);
    static bool scanChannel(uint8_t ch);
    static void fingerprint(const uint8_t* rawBuf, uint8_t size, uint8_t channel);
    static void fingerprintPayload(const uint8_t* payload, uint8_t size,
                                   const uint8_t* addr, uint8_t channel);
    static int  findTarget(const uint8_t* addr, uint8_t addrLen);
    static int  addTarget(const uint8_t* addr, uint8_t addrLen,
                          uint8_t channel, MjDeviceType type);

    // ── Internal attack logic ───────────────────────────────────
    static void attackTask(void* param);

    // Microsoft protocol helpers
    static void msCrypt(uint8_t* payload, uint8_t size, const uint8_t* addr);
    static void msChecksum(uint8_t* payload, uint8_t size);

    // DuckyScript parser
    static bool parseDuckyLine(const String& line, uint8_t targetIndex);
};

#endif // MOUSEJACK_H
