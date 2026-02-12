#ifndef BruterCommands_h
#define BruterCommands_h

#include "StringBuffer.h"
#include "core/ble/CommandHandler.h"
#include "core/ble/ControllerAdapter.h"
#include "DeviceTasks.h"
#include "StringHelpers.h"
#include "core/ble/ClientsManager.h"
#include "config.h"
#include "modules/bruter/bruter_main.h"
#include "cstring"

/**
 * Bruter commands for RF protocol brute force attacks.
 *
 * The attack runs on a dedicated FreeRTOS task (static allocation,
 * no heap usage for the stack) so the BLE callback returns immediately
 * and the mobile app does not time out.
 */
class BruterCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x04, handleBruterCommand);
    }

private:
    // Bruter command handler — returns immediately for menu 1-33,
    // the actual attack runs on the bruter async task.
    static bool handleBruterCommand(const uint8_t* data, size_t len) {
        ESP_LOGD("BruterCommands", "handleBruterCommand START, len=%zu", len);

        if (len < 1) {
            ESP_LOGE("BruterCommands", "Insufficient data for bruter command");
            uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 1}; // 1=insufficient data
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
            return false;
        }

        uint8_t menuChoice = data[0];
        ESP_LOGI("BruterCommands", "Bruter menu choice: %d", menuChoice);

        // --- Pause running attack (sub-command 0xFB) ---
        if (menuChoice == 0xFB) {
            BruterModule& bruter = getBruterModule();
            if (!bruter.isAttackRunning()) {
                ESP_LOGW("BruterCommands", "No attack running to pause");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 5}; // 5=nothing to pause
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            bruter.pauseAttack();
            ESP_LOGI("BruterCommands", "Pause requested");
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            return true;
        }

        // --- Resume from saved state (sub-command 0xFA) ---
        if (menuChoice == 0xFA) {
            BruterModule& bruter = getBruterModule();
            if (bruter.isAttackRunning() || BruterModule::attackTaskHandle != nullptr) {
                ESP_LOGW("BruterCommands", "Attack already running, cannot resume");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 4};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            if (!bruter.resumeAttackAsync()) {
                ESP_LOGE("BruterCommands", "Failed to resume attack (no saved state?)");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 6}; // 6=no saved state
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
            }
            return true;
        }

        // --- Query saved state (sub-command 0xF9) ---
        if (menuChoice == 0xF9) {
            BruterModule& bruter = getBruterModule();
            bruter.checkAndNotifySavedState();
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            return true;
        }

        // --- Set inter-frame delay (sub-command 0xFE) ---
        if (menuChoice == 0xFE) {
            if (len < 3) {
                ESP_LOGE("BruterCommands", "Insufficient data for set-delay command");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 1};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            uint16_t delayMs = data[1] | (data[2] << 8); // little-endian
            BruterModule& bruter = getBruterModule();
            bruter.setInterFrameDelay(delayMs);
            ESP_LOGI("BruterCommands", "Inter-frame delay set to %d ms", delayMs);
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            return true;
        }

        // --- Set global repeats (sub-command 0xFC) ---
        if (menuChoice == 0xFC) {
            if (len < 2) {
                ESP_LOGE("BruterCommands", "Insufficient data for set-repeats command");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 1};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            uint8_t repeats = data[1];
            if (repeats < 1 || repeats > BRUTER_MAX_REPETITIONS) {
                ESP_LOGE("BruterCommands", "Invalid repeats value: %d (range 1-%d)", repeats, BRUTER_MAX_REPETITIONS);
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 3}; // 3=out of range
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            BruterModule& bruter = getBruterModule();
            bruter.setGlobalRepeats(repeats);
            ESP_LOGI("BruterCommands", "Global repeats set to %d", repeats);
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            return true;
        }

        // --- De Bruijn universal with custom params (sub-command 0xFD) ---
        // Format: [0xFD][bits:1][teLo:1][teHi:1][ratio:1] (5 bytes)
        //    or:  [0xFD][bits:1][teLo:1][teHi:1][ratio:1][freq:4LE float] (9 bytes)
        if (menuChoice == 0xFD) {
            if (len < 5) {
                ESP_LOGE("BruterCommands", "Insufficient data for De Bruijn custom command");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 1};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            BruterModule& bruter = getBruterModule();
            if (bruter.isAttackRunning() || BruterModule::attackTaskHandle != nullptr) {
                ESP_LOGW("BruterCommands", "Attack already running, rejecting De Bruijn custom");
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 4};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }

            // Parse custom parameters
            uint8_t bits = data[1];
            uint16_t te = data[2] | (data[3] << 8); // little-endian
            uint8_t ratio = data[4];

            // Optional frequency (default 433.92 MHz if not provided)
            float freq = 433.92f;
            if (len >= 9) {
                memcpy(&freq, &data[5], 4); // IEEE 754 float, little-endian
            }

            // Validate parameters
            if (bits < 1 || bits > DEBRUIJN_MAX_BITS) {
                ESP_LOGE("BruterCommands", "Invalid bits: %d (range 1-%d)", bits, DEBRUIJN_MAX_BITS);
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 3};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            if (te < 50 || te > 5000) {
                ESP_LOGE("BruterCommands", "Invalid Te: %d (range 50-5000 us)", te);
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 3};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }
            if (ratio < 1 || ratio > 10) {
                ESP_LOGE("BruterCommands", "Invalid ratio: %d (range 1-10)", ratio);
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 3};
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }

            // Store custom params and launch attack
            bruter.setCustomDeBruijnParams(bits, te, ratio, freq);
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            if (!bruter.startAttackAsync(0xFD)) {
                ESP_LOGE("BruterCommands", "Failed to create bruter task for De Bruijn custom");
            }
            return true;
        }

        // --- Cancel running attack (instant, no task needed) ---
        if (menuChoice == 0) {
            BruterModule& bruter = getBruterModule();
            bruter.cancelAttack();
            ESP_LOGI("BruterCommands", "Cancel attack requested");
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);
            return true;
        }

        // --- Start a new attack (async) ---
        if (menuChoice >= 1 && menuChoice <= 40) {
            BruterModule& bruter = getBruterModule();

            // Reject if an attack is already in progress
            if (bruter.isAttackRunning() || BruterModule::attackTaskHandle != nullptr) {
                ESP_LOGW("BruterCommands", "Attack already running, rejecting menu %d", menuChoice);
                uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 4}; // 4=already running
                ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
                return false;
            }

            // Send immediate ACK so the BLE write callback returns quickly
            uint8_t successBuffer[1] = {MSG_COMMAND_SUCCESS};
            ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, successBuffer, 1);

            // Launch the attack on a separate statically-allocated task
            if (!bruter.startAttackAsync(menuChoice)) {
                ESP_LOGE("BruterCommands", "Failed to create bruter task for menu %d", menuChoice);
            }

            return true;
        }

        // --- Invalid choice ---
        ESP_LOGE("BruterCommands", "Invalid bruter menu choice: %d", menuChoice);
        uint8_t errBuffer[2] = {MSG_COMMAND_ERROR, 2}; // 2=invalid choice
        ClientsManager::getInstance().notifyAllBinary(NotificationType::SignalSendingError, errBuffer, 2);
        return false;
    }
};

#endif // BruterCommands_h