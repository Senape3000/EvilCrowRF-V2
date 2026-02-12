/**
 * @file OtaModule.h
 * @brief BLE OTA firmware update handler for EvilCrow-RF-V2.
 *
 * Receives firmware binary chunks over BLE, verifies MD5 integrity,
 * and writes to the OTA partition using ESP32 Update library.
 * Also supports serial-based flashing (binary forwarded from app via USB).
 *
 * Partition layout (from partitions.csv):
 *   app0  = ota_0  (0x10000,  0x1D0000 = 1,900KB)
 *   app1  = ota_1  (0x1E0000, 0x1D0000 = 1,900KB)
 *
 * Protocol:
 *   1. App sends OTA_BEGIN with total size + MD5 hash
 *   2. App sends OTA_DATA chunks (max ~500 bytes each, BLE MTU limited)
 *   3. App sends OTA_END to finalize
 *   4. Firmware verifies MD5, writes to flash, reboots
 */

#ifndef OTA_MODULE_H
#define OTA_MODULE_H

#include <Arduino.h>
#include <Update.h>
#include <stdint.h>

/// OTA update state machine
enum OtaState : uint8_t {
    OTA_IDLE      = 0,
    OTA_RECEIVING = 1,
    OTA_VERIFYING = 2,
    OTA_WRITING   = 3,
    OTA_COMPLETE  = 4,
    OTA_ERROR     = 5,
};

/**
 * @class OtaModule
 * @brief Manages BLE OTA firmware updates.
 */
class OtaModule {
public:
    /**
     * Begin OTA update session.
     * @param totalSize  Total firmware binary size in bytes.
     * @param md5Hash    Expected MD5 hash (32-char hex string, null-terminated).
     * @return true if OTA session started successfully.
     */
    static bool begin(uint32_t totalSize, const char* md5Hash);

    /**
     * Write a chunk of firmware data.
     * @param data  Pointer to chunk data.
     * @param len   Chunk size in bytes.
     * @return true if chunk written successfully.
     */
    static bool writeChunk(const uint8_t* data, size_t len);

    /**
     * Finalize OTA update — verify MD5, mark partition bootable.
     * @return true if update verified and ready to reboot.
     */
    static bool end();

    /// Abort OTA update and clean up.
    static void abort();

    /// Reboot into the new firmware.
    static void reboot();

    /// @return current OTA state.
    static OtaState getState() { return state_; }

    /// @return bytes received so far.
    static uint32_t getBytesReceived() { return bytesReceived_; }

    /// @return total expected size.
    static uint32_t getTotalSize() { return totalSize_; }

    /// @return progress percentage (0-100).
    static uint8_t getProgress();

    /// @return last error message (empty if no error).
    static const char* getLastError() { return lastError_; }

private:
    static OtaState  state_;
    static uint32_t  totalSize_;
    static uint32_t  bytesReceived_;
    static char      expectedMd5_[33];  // 32 hex chars + null
    static char      lastError_[64];
};

#endif // OTA_MODULE_H
