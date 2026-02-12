/**
 * @file SdrCommands.h
 * @brief BLE command handlers for SDR (Software Defined Radio) mode.
 *
 * Registers command IDs 0x50-0x59 for SDR operations.
 * Follows the same CommandHandler pattern as NrfCommands, BruterCommands, etc.
 *
 * Command protocol:
 *   0x50 = SDR_ENABLE           — Enter SDR mode (locks CC1101 module)
 *   0x51 = SDR_DISABLE          — Exit SDR mode (unlocks CC1101 module)
 *   0x52 = SDR_SET_FREQ         — Set center frequency [freq_khz:4LE]
 *   0x53 = SDR_SET_BANDWIDTH    — Set RX bandwidth [bw_khz:2LE]
 *   0x54 = SDR_SET_MODULATION   — Set modulation type [mod:1]
 *   0x55 = SDR_SPECTRUM_SCAN    — Start spectrum scan [startKhz:4LE][endKhz:4LE][stepKhz:2LE]
 *   0x56 = SDR_RX_START         — Start raw RX streaming
 *   0x57 = SDR_RX_STOP          — Stop raw RX streaming
 *   0x58 = SDR_GET_STATUS       — Get current SDR status
 *   0x59 = SDR_SET_DATARATE     — Set data rate [rate_baud:4LE]
 *
 * When SDR mode is active, other CC1101 commands (record, transmit, detect,
 * jam) should be blocked by the app UI (SDR MODE toggle in Settings).
 *
 * Response messages:
 *   MSG_SDR_STATUS        (0xC4) — SDR mode status
 *   MSG_SDR_SPECTRUM_DATA (0xC5) — Spectrum scan results (chunked)
 *   MSG_SDR_RAW_DATA      (0xC6) — Raw RX data from CC1101 FIFO
 */

#ifndef SDR_COMMANDS_H
#define SDR_COMMANDS_H

#include <Arduino.h>
#include "config.h"

#if SDR_MODULE_ENABLED

#include "core/ble/CommandHandler.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "modules/sdr/SdrModule.h"
#include "esp_log.h"

class SdrCommands {
public:
    /**
     * Register all SDR BLE command handlers (0x50-0x59).
     */
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x50, handleEnable);
        handler.registerCommand(0x51, handleDisable);
        handler.registerCommand(0x52, handleSetFreq);
        handler.registerCommand(0x53, handleSetBandwidth);
        handler.registerCommand(0x54, handleSetModulation);
        handler.registerCommand(0x55, handleSpectrumScan);
        handler.registerCommand(0x56, handleRxStart);
        handler.registerCommand(0x57, handleRxStop);
        handler.registerCommand(0x58, handleGetStatus);
        handler.registerCommand(0x59, handleSetDataRate);
    }

private:
    // ── 0x50: Enable SDR mode ─────────────────────────────────────
    // Payload: [module:1] (optional, defaults to SDR_DEFAULT_MODULE)
    static bool handleEnable(const uint8_t* data, size_t len) {
        int module = (len >= 1) ? data[0] : SDR_DEFAULT_MODULE;

        bool ok = SdrModule::enable(module);

        uint8_t resp[2];
        resp[0] = ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR;
        resp[1] = ok ? 1 : 0;  // 1 = SDR active
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, sizeof(resp));

        if (ok) {
            SdrModule::sendStatus();
        }
        return ok;
    }

    // ── 0x51: Disable SDR mode ────────────────────────────────────
    // Payload: none
    static bool handleDisable(const uint8_t* data, size_t len) {
        (void)data; (void)len;

        bool ok = SdrModule::disable();

        uint8_t resp[2];
        resp[0] = ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR;
        resp[1] = 0;  // 0 = SDR inactive
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x52: Set frequency ───────────────────────────────────────
    // Payload: [freq_khz:4LE]
    static bool handleSetFreq(const uint8_t* data, size_t len) {
        if (!SdrModule::isActive()) {
            sendError("SDR not active");
            return false;
        }
        if (len < 4) {
            sendError("Missing freq_khz (4 bytes)");
            return false;
        }

        uint32_t freqKhz = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
        float freqMHz = freqKhz / 1000.0f;

        bool ok = SdrModule::setFrequency(freqMHz);

        uint8_t resp[1] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);

        if (ok) SdrModule::sendStatus();
        return ok;
    }

    // ── 0x53: Set bandwidth ───────────────────────────────────────
    // Payload: [bw_khz:2LE]
    static bool handleSetBandwidth(const uint8_t* data, size_t len) {
        if (!SdrModule::isActive()) {
            sendError("SDR not active");
            return false;
        }
        if (len < 2) {
            sendError("Missing bw_khz (2 bytes)");
            return false;
        }

        uint16_t bwKhz = data[0] | (data[1] << 8);
        bool ok = SdrModule::setBandwidth((float)bwKhz);

        uint8_t resp[1] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);
        return ok;
    }

    // ── 0x54: Set modulation ──────────────────────────────────────
    // Payload: [mod:1] (0=2FSK, 1=GFSK, 2=ASK/OOK, 3=4FSK, 4=MSK)
    static bool handleSetModulation(const uint8_t* data, size_t len) {
        if (!SdrModule::isActive()) {
            sendError("SDR not active");
            return false;
        }
        if (len < 1) {
            sendError("Missing modulation byte");
            return false;
        }

        bool ok = SdrModule::setModulation(data[0]);

        uint8_t resp[1] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);
        return ok;
    }

    // ── 0x55: Spectrum scan ───────────────────────────────────────
    // Payload: [startKhz:4LE][endKhz:4LE][stepKhz:2LE] (10 bytes)
    // If no payload: full scan 300-928 MHz at default step
    static bool handleSpectrumScan(const uint8_t* data, size_t len) {
        if (!SdrModule::isActive()) {
            sendError("SDR not active");
            return false;
        }

        SpectrumScanConfig cfg;

        if (len >= 10) {
            uint32_t startKhz = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
            uint32_t endKhz   = data[4] | (data[5] << 8) | (data[6] << 16) | (data[7] << 24);
            uint16_t stepKhz  = data[8] | (data[9] << 8);

            cfg.startFreqMHz = startKhz / 1000.0f;
            cfg.endFreqMHz   = endKhz / 1000.0f;
            cfg.stepMHz      = stepKhz / 1000.0f;
        }
        // else: use defaults (300-928 MHz, 100 kHz step)

        // Validate
        if (cfg.stepMHz <= 0.0f) cfg.stepMHz = 0.1f;

        int points = SdrModule::spectrumScan(cfg);

        uint8_t resp[1] = { (points > 0) ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);
        return points > 0;
    }

    // ── 0x56: Start raw RX streaming ──────────────────────────────
    // Payload: none
    static bool handleRxStart(const uint8_t* data, size_t len) {
        (void)data; (void)len;

        if (!SdrModule::isActive()) {
            sendError("SDR not active");
            return false;
        }

        bool ok = SdrModule::startRawRx();

        uint8_t resp[1] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);
        return ok;
    }

    // ── 0x57: Stop raw RX streaming ───────────────────────────────
    // Payload: none
    static bool handleRxStop(const uint8_t* data, size_t len) {
        (void)data; (void)len;

        SdrModule::stopRawRx();

        uint8_t resp[1] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);
        return true;
    }

    // ── 0x58: Get SDR status ──────────────────────────────────────
    // Payload: none
    static bool handleGetStatus(const uint8_t* data, size_t len) {
        (void)data; (void)len;

        SdrModule::sendStatus();
        return true;
    }

    // ── 0x59: Set data rate ───────────────────────────────────────
    // Payload: [rate_baud:4LE]
    static bool handleSetDataRate(const uint8_t* data, size_t len) {
        if (!SdrModule::isActive()) {
            sendError("SDR not active");
            return false;
        }
        if (len < 4) {
            sendError("Missing rate_baud (4 bytes)");
            return false;
        }

        uint32_t rateBaud = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
        float kBaud = rateBaud / 1000.0f;

        bool ok = SdrModule::setDataRate(kBaud);

        uint8_t resp[1] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, resp, 1);
        return ok;
    }

    // ── Helper: send error via BLE ────────────────────────────────
    static void sendError(const char* msg) {
        uint8_t packet[2 + 64];
        packet[0] = MSG_COMMAND_ERROR;
        size_t msgLen = strlen(msg);
        if (msgLen > 63) msgLen = 63;
        packet[1] = (uint8_t)msgLen;
        memcpy(packet + 2, msg, msgLen);
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SdrEvent, packet, 2 + msgLen);
    }
};

#endif // SDR_MODULE_ENABLED
#endif // SDR_COMMANDS_H
