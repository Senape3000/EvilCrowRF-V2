/**
 * @file OtaCommands.h
 * @brief BLE command handlers for OTA firmware updates.
 *
 * Command IDs 0x30-0x35 for OTA operations.
 *
 *   0x30 = OTA_BEGIN     — Start OTA session [size:4][md5:32]
 *   0x31 = OTA_DATA      — Write firmware chunk [chunkData:N]
 *   0x32 = OTA_END       — Finalize and verify
 *   0x33 = OTA_ABORT     — Cancel OTA
 *   0x34 = OTA_REBOOT    — Reboot device
 *   0x35 = OTA_STATUS    — Query OTA progress
 */

#ifndef OTA_COMMANDS_H
#define OTA_COMMANDS_H

#include <Arduino.h>
#include "core/ble/CommandHandler.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "modules/ota/OtaModule.h"
#include "esp_log.h"

class OtaCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x30, handleOtaBegin);
        handler.registerCommand(0x31, handleOtaData);
        handler.registerCommand(0x32, handleOtaEnd);
        handler.registerCommand(0x33, handleOtaAbort);
        handler.registerCommand(0x34, handleOtaReboot);
        handler.registerCommand(0x35, handleOtaStatus);
    }

private:
    // ── 0x30: Begin OTA session ─────────────────────────────────
    // Payload: [totalSize:4 LE][md5Hash:32 ASCII] = 36 bytes
    static bool handleOtaBegin(const uint8_t* data, size_t len) {
        if (len < 4) {
            sendError("OTA_BEGIN: payload too short");
            return false;
        }

        // Extract total size (little-endian u32)
        uint32_t totalSize = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);

        // Extract MD5 hash (optional, 32 ASCII chars)
        char md5[33] = {};
        if (len >= 36) {
            memcpy(md5, data + 4, 32);
            md5[32] = '\0';
        }

        bool ok = OtaModule::begin(totalSize, md5[0] ? md5 : nullptr);

        if (ok) {
            // Send OTA progress notification (0%)
            sendProgress(0, totalSize, 0);
        } else {
            sendError(OtaModule::getLastError());
        }
        return ok;
    }

    // ── 0x31: Write firmware chunk ──────────────────────────────
    // Payload: [rawBinaryData:N]
    static bool handleOtaData(const uint8_t* data, size_t len) {
        if (len == 0) return false;

        bool ok = OtaModule::writeChunk(data, len);

        if (ok) {
            // Send progress every chunk (app can throttle display)
            sendProgress(OtaModule::getBytesReceived(),
                        OtaModule::getTotalSize(),
                        OtaModule::getProgress());
        } else {
            sendError(OtaModule::getLastError());
        }
        return ok;
    }

    // ── 0x32: Finalize OTA ──────────────────────────────────────
    static bool handleOtaEnd(const uint8_t* data, size_t len) {
        bool ok = OtaModule::end();

        if (ok) {
            uint8_t resp[] = { MSG_OTA_COMPLETE };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::OtaEvent, resp, sizeof(resp));
        } else {
            sendError(OtaModule::getLastError());
        }
        return ok;
    }

    // ── 0x33: Abort OTA ─────────────────────────────────────────
    static bool handleOtaAbort(const uint8_t* data, size_t len) {
        OtaModule::abort();
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::OtaEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x34: Reboot device ─────────────────────────────────────
    static bool handleOtaReboot(const uint8_t* data, size_t len) {
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::OtaEvent, resp, sizeof(resp));
        // Small delay to let BLE notification go through
        vTaskDelay(pdMS_TO_TICKS(500));
        OtaModule::reboot();
        return true;  // Never reached
    }

    // ── 0x35: Query OTA status ──────────────────────────────────
    static bool handleOtaStatus(const uint8_t* data, size_t len) {
        sendProgress(OtaModule::getBytesReceived(),
                    OtaModule::getTotalSize(),
                    OtaModule::getProgress());
        return true;
    }

    // ── Helpers ─────────────────────────────────────────────────

    static void sendProgress(uint32_t received, uint32_t total, uint8_t pct) {
        // [MSG_OTA_PROGRESS][received:4 LE][total:4 LE][percentage:1]
        uint8_t buf[10];
        buf[0] = MSG_OTA_PROGRESS;
        buf[1] = (uint8_t)(received & 0xFF);
        buf[2] = (uint8_t)((received >> 8) & 0xFF);
        buf[3] = (uint8_t)((received >> 16) & 0xFF);
        buf[4] = (uint8_t)((received >> 24) & 0xFF);
        buf[5] = (uint8_t)(total & 0xFF);
        buf[6] = (uint8_t)((total >> 8) & 0xFF);
        buf[7] = (uint8_t)((total >> 16) & 0xFF);
        buf[8] = (uint8_t)((total >> 24) & 0xFF);
        buf[9] = pct;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::OtaEvent, buf, sizeof(buf));
    }

    static void sendError(const char* msg) {
        uint8_t buf[66];
        buf[0] = MSG_OTA_ERROR;
        uint8_t msgLen = 0;
        if (msg) {
            msgLen = (uint8_t)std::min(strlen(msg), (size_t)64);
            memcpy(buf + 1, msg, msgLen);
        }
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::OtaEvent, buf, 1 + msgLen);
    }
};

#endif // OTA_COMMANDS_H
