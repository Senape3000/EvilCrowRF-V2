/**
 * @file NrfCommands.h
 * @brief BLE command handlers for all NRF24 features.
 *
 * Registers command IDs 0x20-0x2F for MouseJack, Spectrum, and Jammer.
 * Follows the same CommandHandler pattern as StateCommands, BruterCommands, etc.
 *
 * Command protocol:
 *   0x20 = NRF_INIT           — Initialize nRF24 module
 *   0x21 = NRF_SCAN_START     — Start MouseJack scan
 *   0x22 = NRF_SCAN_STOP      — Stop scan
 *   0x23 = NRF_SCAN_STATUS    — Get scan state and target list
 *   0x24 = NRF_ATTACK_HID     — Inject raw HID codes
 *   0x25 = NRF_ATTACK_STRING  — Inject ASCII string
 *   0x26 = NRF_ATTACK_DUCKY   — Execute DuckyScript from SD
 *   0x27 = NRF_ATTACK_STOP    — Stop attack
 *   0x28 = NRF_SPECTRUM_START — Start spectrum analyzer
 *   0x29 = NRF_SPECTRUM_STOP  — Stop spectrum analyzer
 *   0x2A = NRF_JAM_START      — Start jammer (mode in payload)
 *   0x2B = NRF_JAM_STOP       — Stop jammer
 *   0x2C = NRF_JAM_SET_MODE   — Change jammer mode
 *   0x2D = NRF_JAM_SET_CH     — Change jammer channel
 *   0x2E = NRF_CLEAR_TARGETS  — Clear target list
 *   0x2F = NRF_STOP_ALL       — Stop all NRF tasks (cleanup on screen exit)
 *
 *   0x41 = NRF_SETTINGS       — Apply nRF24 radio settings (PA, data rate, channel, retransmit)
 */

#ifndef NRF_COMMANDS_H
#define NRF_COMMANDS_H

#include <Arduino.h>
#include "core/ble/CommandHandler.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "modules/nrf/NrfModule.h"
#include "modules/nrf/MouseJack.h"
#include "modules/nrf/NrfSpectrum.h"
#include "modules/nrf/NrfJammer.h"
#include "ConfigManager.h"
#include "esp_log.h"

class NrfCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x20, handleInit);
        handler.registerCommand(0x21, handleScanStart);
        handler.registerCommand(0x22, handleScanStop);
        handler.registerCommand(0x23, handleScanStatus);
        handler.registerCommand(0x24, handleAttackHid);
        handler.registerCommand(0x25, handleAttackString);
        handler.registerCommand(0x26, handleAttackDucky);
        handler.registerCommand(0x27, handleAttackStop);
        handler.registerCommand(0x28, handleSpectrumStart);
        handler.registerCommand(0x29, handleSpectrumStop);
        handler.registerCommand(0x2A, handleJamStart);
        handler.registerCommand(0x2B, handleJamStop);
        handler.registerCommand(0x2C, handleJamSetMode);
        handler.registerCommand(0x2D, handleJamSetChannel);
        handler.registerCommand(0x2E, handleClearTargets);
        handler.registerCommand(0x2F, handleStopAll);
        handler.registerCommand(0x41, handleNrfSettings);
    }

private:
    // ── 0x20: Initialize NRF module ─────────────────────────────
    static bool handleInit(const uint8_t* data, size_t len) {
        bool ok = NrfModule::init();
        if (ok) {
            MouseJack::init();
        }

        // Response: [MSG_COMMAND_SUCCESS/ERROR][nrf_present:1]
        uint8_t resp[2];
        resp[0] = ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR;
        resp[1] = NrfModule::isPresent() ? 1 : 0;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x21: Start MouseJack scan ──────────────────────────────
    static bool handleScanStart(const uint8_t* data, size_t len) {
        // Check if any NRF operation is already running
        if (MouseJack::isRunning() || NrfSpectrum::isRunning() || NrfJammer::isRunning()) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 1 };  // Busy
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        bool ok = MouseJack::startScan();
        uint8_t resp[] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR, 0 };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x22: Stop scan ─────────────────────────────────────────
    static bool handleScanStop(const uint8_t* data, size_t len) {
        MouseJack::stopScan();
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x23: Get scan status and target list ───────────────────
    static bool handleScanStatus(const uint8_t* data, size_t len) {
        // Response: [NRF_SCAN_STATUS_RESP][state:1][targetCount:1]
        //   then for each target: [type:1][channel:1][addrLen:1][addr:N]
        uint8_t targetCount = MouseJack::getTargetCount();
        const MjTarget* targets = MouseJack::getTargets();

        // Calculate response size
        size_t respSize = 3;  // header + state + count
        for (uint8_t i = 0; i < targetCount; i++) {
            if (targets[i].active) {
                respSize += 3 + targets[i].addrLen;  // type + ch + addrLen + addr
            }
        }

        uint8_t* resp = new uint8_t[respSize];
        resp[0] = MSG_NRF_SCAN_STATUS;
        resp[1] = (uint8_t)MouseJack::getState();
        resp[2] = targetCount;

        size_t offset = 3;
        for (uint8_t i = 0; i < targetCount; i++) {
            if (targets[i].active) {
                resp[offset++] = (uint8_t)targets[i].type;
                resp[offset++] = targets[i].channel;
                resp[offset++] = targets[i].addrLen;
                memcpy(resp + offset, targets[i].address, targets[i].addrLen);
                offset += targets[i].addrLen;
            }
        }

        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, offset);
        delete[] resp;
        return true;
    }

    // ── 0x24: Attack with raw HID payload ───────────────────────
    // Payload: [targetIndex:1][hidData:N]
    static bool handleAttackHid(const uint8_t* data, size_t len) {
        if (len < 3) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 2 };  // Bad payload
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        uint8_t targetIdx = data[0];
        bool ok = MouseJack::startAttack(targetIdx, data + 1, len - 1);

        uint8_t resp[] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR, 0 };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x25: Attack with ASCII string ──────────────────────────
    // Payload: [targetIndex:1][strLen:1][string:N]
    static bool handleAttackString(const uint8_t* data, size_t len) {
        if (len < 3) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 2 };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        uint8_t targetIdx = data[0];
        uint8_t strLen = data[1];
        if (len < (size_t)(2 + strLen)) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 2 };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        // Null-terminate the string
        char* str = new char[strLen + 1];
        memcpy(str, data + 2, strLen);
        str[strLen] = '\0';

        bool ok = MouseJack::injectString(targetIdx, str);
        delete[] str;

        uint8_t resp[] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR, 0 };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x26: Execute DuckyScript ───────────────────────────────
    // Payload: [targetIndex:1][pathLen:1][path:N]
    static bool handleAttackDucky(const uint8_t* data, size_t len) {
        if (len < 3) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 2 };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        uint8_t targetIdx = data[0];
        uint8_t pathLen = data[1];
        if (len < (size_t)(2 + pathLen)) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 2 };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        char* path = new char[pathLen + 1];
        memcpy(path, data + 2, pathLen);
        path[pathLen] = '\0';

        bool ok = MouseJack::executeDuckyScript(targetIdx, path);
        delete[] path;

        uint8_t resp[] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR, 0 };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x27: Stop attack ───────────────────────────────────────
    static bool handleAttackStop(const uint8_t* data, size_t len) {
        MouseJack::stopAttack();
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x28: Start spectrum analyzer ───────────────────────────
    static bool handleSpectrumStart(const uint8_t* data, size_t len) {
        if (MouseJack::isRunning() || NrfJammer::isRunning()) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 1 };  // NRF busy
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        bool ok = NrfSpectrum::start();
        uint8_t resp[] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR, 0 };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x29: Stop spectrum analyzer ────────────────────────────
    static bool handleSpectrumStop(const uint8_t* data, size_t len) {
        NrfSpectrum::stop();
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x2A: Start jammer ──────────────────────────────────────
    // Payload: [mode:1] or [mode:1][channel:1] for SINGLE
    //          or [mode:1][startCh:1][stopCh:1][step:1] for HOPPER
    static bool handleJamStart(const uint8_t* data, size_t len) {
        if (MouseJack::isRunning() || NrfSpectrum::isRunning()) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 1 };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        if (len < 1) {
            uint8_t resp[] = { MSG_COMMAND_ERROR, 2 };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        NrfJamMode mode = (NrfJamMode)data[0];
        bool ok = false;

        if (mode == NRF_JAM_SINGLE && len >= 2) {
            ok = NrfJammer::startSingleChannel(data[1]);
        } else if (mode == NRF_JAM_HOPPER && len >= 4) {
            NrfHopperConfig config;
            config.startChannel = data[1];
            config.stopChannel  = data[2];
            config.stepSize     = data[3];
            ok = NrfJammer::startHopper(config);
        } else {
            ok = NrfJammer::start(mode);
        }

        uint8_t resp[] = { ok ? MSG_COMMAND_SUCCESS : MSG_COMMAND_ERROR, 0 };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return ok;
    }

    // ── 0x2B: Stop jammer ───────────────────────────────────────
    static bool handleJamStop(const uint8_t* data, size_t len) {
        NrfJammer::stop();
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x2C: Change jammer mode ────────────────────────────────
    // Payload: [mode:1]
    static bool handleJamSetMode(const uint8_t* data, size_t len) {
        if (len < 1) return false;
        NrfJammer::setMode((NrfJamMode)data[0]);
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x2D: Change jammer channel ─────────────────────────────
    // Payload: [channel:1]
    static bool handleJamSetChannel(const uint8_t* data, size_t len) {
        if (len < 1) return false;
        NrfJammer::setChannel(data[0]);
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x2E: Clear all targets ─────────────────────────────────
    static bool handleClearTargets(const uint8_t* data, size_t len) {
        MouseJack::clearTargets();
        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }

    // ── 0x2F: Stop all NRF tasks (cleanup for screen exit) ──────
    // Stops MouseJack scan/attack, spectrum analyzer, and jammer.
    // Sends confirmation with current state of each subsystem.
    static bool handleStopAll(const uint8_t* data, size_t len) {
        bool wasScanning = MouseJack::isRunning();
        bool wasSpectrum = NrfSpectrum::isRunning();
        bool wasJamming  = NrfJammer::isRunning();

        if (wasScanning) MouseJack::stopScan();
        if (wasSpectrum) NrfSpectrum::stop();
        if (wasJamming)  NrfJammer::stop();

        // Wait briefly for tasks to finish releasing SPI
        if (wasScanning || wasSpectrum || wasJamming) {
            vTaskDelay(pdMS_TO_TICKS(150));
        }

        // Confirmation: [SUCCESS][wasScan][wasSpectrum][wasJam]
        uint8_t resp[4] = {
            MSG_COMMAND_SUCCESS,
            wasScanning ? (uint8_t)1 : (uint8_t)0,
            wasSpectrum ? (uint8_t)1 : (uint8_t)0,
            wasJamming  ? (uint8_t)1 : (uint8_t)0
        };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));

        ESP_LOGI("NRF", "StopAll: scan=%d spec=%d jam=%d",
                 wasScanning, wasSpectrum, wasJamming);
        return true;
    }

    // ── 0x41: Apply nRF24 settings ──────────────────────────────
    // Payload: [paLevel:1][dataRate:1][channel:1][autoRetransmit:1] = 4 bytes
    static bool handleNrfSettings(const uint8_t* data, size_t len) {
        if (len < 4) {
            uint8_t resp[] = { MSG_COMMAND_ERROR };
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, resp, sizeof(resp));
            return false;
        }

        uint8_t paLevel     = data[0];
        uint8_t dataRate    = data[1];
        uint8_t channel     = data[2];
        uint8_t autoRetrans = data[3];

        // Clamp values
        if (paLevel > 3) paLevel = 3;
        if (dataRate > 2) dataRate = 0;
        if (channel > 125) channel = 76;
        if (autoRetrans > 15) autoRetrans = 5;

        // Update ConfigManager and persist
        ConfigManager::settings.nrfPaLevel = paLevel;
        ConfigManager::settings.nrfDataRate = dataRate;
        ConfigManager::settings.nrfChannel = channel;
        ConfigManager::settings.nrfAutoRetransmit = autoRetrans;
        ConfigManager::saveSettings();

        // Apply to NRF module if initialized
        if (NrfModule::isInitialized() && NrfModule::isPresent()) {
            if (NrfModule::acquireSpi()) {
                NrfModule::setPALevel(paLevel);
                NrfModule::setDataRate((NrfDataRate)dataRate);
                NrfModule::setChannel(channel);
                // Auto-retransmit: upper nibble = delay (250µs steps), lower = count
                uint8_t retrReg = (0x01 << 4) | (autoRetrans & 0x0F); // 500µs delay
                NrfModule::writeRegister(0x04, retrReg); // SETUP_RETR register
                NrfModule::releaseSpi();
            }
        }

        ESP_LOGI("NRF", "Settings applied: PA=%d DR=%d CH=%d ART=%d",
                 paLevel, dataRate, channel, autoRetrans);

        uint8_t resp[] = { MSG_COMMAND_SUCCESS };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::NrfEvent, resp, sizeof(resp));
        return true;
    }
};

#endif // NRF_COMMANDS_H
