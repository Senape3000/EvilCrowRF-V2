/**
 * @file ButtonCommands.h
 * @brief BLE command handler for hardware button configuration + polling.
 *
 * Command IDs:
 *   0x40 = HW_BUTTON_CONFIG — Set action for a physical button
 *           Payload: [buttonId: 1|2][actionId: 0-6]
 *
 * Button actions (HwButtonAction enum):
 *   0 = None
 *   1 = Toggle NRF Jammer
 *   2 = Toggle SubGhz Recording
 *   3 = Replay Last Signal
 *   4 = Toggle LED
 *   5 = Deep Sleep
 *   6 = Reboot
 *
 * GPIO34 (BUTTON1) and GPIO35 (BUTTON2) are input-only pins on ESP32.
 * The polling function checkButtons() should be called from loop().
 */

#ifndef BUTTON_COMMANDS_H
#define BUTTON_COMMANDS_H

#include <Arduino.h>
#include "config.h"
#include "core/ble/CommandHandler.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "ConfigManager.h"
#include "core/device_controls/DeviceControls.h"
#include "modules/nrf/NrfJammer.h"
#include "esp_log.h"

/// Available actions for hardware buttons.
/// Must match the Flutter HwButtonAction enum order.
enum class HwButtonAction : uint8_t {
    None            = 0,
    ToggleJammer    = 1,
    ToggleRecording = 2,
    ReplayLast      = 3,
    ToggleLed       = 4,
    DeepSleep       = 5,
    Reboot          = 6,
    ACTION_COUNT    = 7,
};

class ButtonCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x40, handleButtonConfig);
        // Load persisted button actions from flash config
        loadFromConfig();
        ESP_LOGI("ButtonCmd", "HW Button commands registered (0x40), btn1=%d btn2=%d",
                 (int)button1Action, (int)button2Action);
    }

    /// Load button actions from ConfigManager (call after ConfigManager::loadSettings)
    static void loadFromConfig() {
        uint8_t a1 = ConfigManager::settings.button1Action;
        uint8_t a2 = ConfigManager::settings.button2Action;
        if (a1 < (uint8_t)HwButtonAction::ACTION_COUNT)
            button1Action = static_cast<HwButtonAction>(a1);
        if (a2 < (uint8_t)HwButtonAction::ACTION_COUNT)
            button2Action = static_cast<HwButtonAction>(a2);
    }

    /// Call from loop() — polls buttons with debounce and executes assigned action.
    static void checkButtons() {
        static unsigned long lastBtn1Press = 0;
        static unsigned long lastBtn2Press = 0;
        static bool btn1WasPressed = false;
        static bool btn2WasPressed = false;
        const unsigned long debounceMs = 300;
        unsigned long now = millis();

        // BUTTON1 (GPIO34) — active LOW
        bool btn1Pressed = (digitalRead(BUTTON1) == LOW);
        if (btn1Pressed && !btn1WasPressed && (now - lastBtn1Press > debounceMs)) {
            lastBtn1Press = now;
            executeAction(button1Action);
        }
        btn1WasPressed = btn1Pressed;

        // BUTTON2 (GPIO35) — active LOW
        bool btn2Pressed = (digitalRead(BUTTON2) == LOW);
        if (btn2Pressed && !btn2WasPressed && (now - lastBtn2Press > debounceMs)) {
            lastBtn2Press = now;
            executeAction(button2Action);
        }
        btn2WasPressed = btn2Pressed;
    }

private:
    static inline HwButtonAction button1Action = HwButtonAction::None;
    static inline HwButtonAction button2Action = HwButtonAction::None;

    /// Handle 0x40: Set button action
    /// Payload: [buttonId (1 or 2)][actionId (0-6)]
    static bool handleButtonConfig(const uint8_t* data, size_t len) {
        if (len < 2) {
            ESP_LOGW("ButtonCmd", "Payload too short (need 2 bytes)");
            return false;
        }

        uint8_t buttonId = data[0];
        uint8_t actionId = data[1];

        if (buttonId < 1 || buttonId > 2) {
            ESP_LOGW("ButtonCmd", "Invalid button ID: %u (must be 1 or 2)", buttonId);
            return false;
        }
        if (actionId >= (uint8_t)HwButtonAction::ACTION_COUNT) {
            ESP_LOGW("ButtonCmd", "Invalid action ID: %u (max %u)",
                     actionId, (uint8_t)HwButtonAction::ACTION_COUNT - 1);
            return false;
        }

        HwButtonAction action = static_cast<HwButtonAction>(actionId);

        if (buttonId == 1) {
            button1Action = action;
            ConfigManager::settings.button1Action = actionId;
        } else {
            button2Action = action;
            ConfigManager::settings.button2Action = actionId;
        }

        // Persist to flash so the action survives reboot
        ConfigManager::saveSettings();
        ESP_LOGI("ButtonCmd", "Button %u -> action %u (saved to flash)", buttonId, actionId);

        // Send confirmation
        uint8_t resp[] = { MSG_COMMAND_SUCCESS, buttonId, actionId };
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::SettingsSync, resp, sizeof(resp));

        return true;
    }

    /// Execute the action assigned to a button.
    static void executeAction(HwButtonAction action) {
        switch (action) {
            case HwButtonAction::None:
                break;

            case HwButtonAction::ToggleJammer:
                if (NrfJammer::isRunning()) {
                    NrfJammer::stop();
                    ESP_LOGI("ButtonCmd", "Jammer stopped via button");
                } else {
                    // Start with default mode (Full spectrum sweep)
                    NrfJammer::start(NRF_JAM_FULL);
                    ESP_LOGI("ButtonCmd", "Jammer started via button");
                }
                break;

            case HwButtonAction::ToggleRecording:
                // TODO: Implement recording toggle when recorder module
                // exposes a static start/stop interface.
                ESP_LOGI("ButtonCmd", "Toggle recording — not yet implemented");
                DeviceControls::ledBlink(2, 100);
                break;

            case HwButtonAction::ReplayLast:
                // TODO: Implement replay last signal
                ESP_LOGI("ButtonCmd", "Replay last — not yet implemented");
                DeviceControls::ledBlink(3, 80);
                break;

            case HwButtonAction::ToggleLed:
                {
                    static bool ledState = false;
                    ledState = !ledState;
                    digitalWrite(LED, ledState ? HIGH : LOW);
                    ESP_LOGI("ButtonCmd", "LED toggled %s", ledState ? "ON" : "OFF");
                }
                break;

            case HwButtonAction::DeepSleep:
                ESP_LOGI("ButtonCmd", "Entering deep sleep via button");
                DeviceControls::ledBlink(5, 150);
                DeviceControls::goDeepSleep();
                break;

            case HwButtonAction::Reboot:
                ESP_LOGI("ButtonCmd", "Rebooting via button");
                DeviceControls::ledBlink(3, 100);
                vTaskDelay(pdMS_TO_TICKS(200));
                esp_restart();
                break;

            default:
                break;
        }
    }
};

#endif // BUTTON_COMMANDS_H
