/**
 * @file NrfJammer.cpp
 * @brief 2.4 GHz jammer with multiple mode presets and dual jamming methods.
 *
 * Uses the nRF24L01+ in two modes:
 *  - Constant Carrier (CW): Unmodulated RF at max power for FHSS targets
 *    (Bluetooth Classic, Drones). Hops rapidly through relevant channels.
 *  - Data Flooding (writeFast): Transmits garbage packets at max speed
 *    to create packet-level collisions for channel-specific targets
 *    (WiFi, BLE, Zigbee).
 *
 * Channel mappings derived from the nRF24_jammer project and RF standards:
 *  - nRF24 channel N = 2400 + N MHz
 *  - WiFi ch 1 = 2412 MHz center, 22 MHz bandwidth → nRF24 ch 1-23
 *  - BLE advertising ch 37 = 2402 MHz → nRF24 ch 2
 *  - BLE advertising ch 38 = 2426 MHz → nRF24 ch 26
 *  - BLE advertising ch 39 = 2480 MHz → nRF24 ch 80
 *  - Zigbee ch 11 = 2405 MHz → nRF24 ch 4-6, etc.
 */

#include "NrfJammer.h"
#include "NrfModule.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "core/device_controls/DeviceControls.h"
#include "esp_log.h"

static const char* TAG = "NrfJammer";

// Static members
volatile bool NrfJammer::running_     = false;
volatile bool NrfJammer::stopRequest_ = false;
TaskHandle_t  NrfJammer::taskHandle_  = nullptr;
NrfJamMode    NrfJammer::currentMode_ = NRF_JAM_FULL;
uint8_t       NrfJammer::currentChannel_ = 50;
NrfHopperConfig NrfJammer::hopperConfig_ = {0, 80, 2};

// Garbage payload for data flooding (same as nRF24_jammer reference)
static const char JAM_FLOOD_DATA[] = "xxxxxxxxxxxxxxxx";

// ── Channel lists for each jamming mode ─────────────────────────

// Classic Bluetooth: 21 key FHSS channels (from nRF24_jammer)
static const uint8_t JAM_BLUETOOTH_CHANNELS[] = {
    32, 34, 46, 48, 50, 52, 0, 1, 2, 4, 6,
    8, 22, 24, 26, 28, 30, 74, 76, 78, 80
};

// BLE advertising channels (the only 3 that matter for BLE discovery)
// BLE ch37=2402MHz→nRF ch2, BLE ch38=2426MHz→nRF ch26, BLE ch39=2480MHz→nRF ch80
static const uint8_t JAM_BLE_ADV_CHANNELS[] = { 2, 26, 80 };

// BLE data channels: cover the full 2402-2480 MHz range used by BLE
// data connections (channels 0-36 in BLE = nRF24 ch 2-80)
static const uint8_t JAM_BLE_CHANNELS[] = {
    2, 4, 6, 8, 10, 12, 14, 16, 18, 20,
    22, 24, 26, 28, 30, 32, 34, 36, 38, 40,
    42, 44, 46, 48, 50, 52, 54, 56, 58, 60,
    62, 64, 66, 68, 70, 72, 74, 76, 78, 80
};

// Zigbee channels 11-26: each is 2 MHz wide at 5 MHz spacing
// Zigbee ch N center = 2405 + 5*(N-11) MHz → nRF24 ch = 5 + 5*(N-11)
// We cover ±1 MHz around each center for effective jamming
static const uint8_t JAM_ZIGBEE_CHANNELS[] = {
    4, 5, 6,       // Zigbee ch 11 (2405 MHz)
    9, 10, 11,     // Zigbee ch 12 (2410 MHz)
    14, 15, 16,    // Zigbee ch 13 (2415 MHz)
    19, 20, 21,    // Zigbee ch 14 (2420 MHz)
    24, 25, 26,    // Zigbee ch 15 (2425 MHz)
    29, 30, 31,    // Zigbee ch 16 (2430 MHz)
    34, 35, 36,    // Zigbee ch 17 (2435 MHz)
    39, 40, 41,    // Zigbee ch 18 (2440 MHz)
    44, 45, 46,    // Zigbee ch 19 (2445 MHz)
    49, 50, 51,    // Zigbee ch 20 (2450 MHz)
    54, 55, 56,    // Zigbee ch 21 (2455 MHz)
    59, 60, 61,    // Zigbee ch 22 (2460 MHz)
    64, 65, 66,    // Zigbee ch 23 (2465 MHz)
    69, 70, 71,    // Zigbee ch 24 (2470 MHz)
    74, 75, 76,    // Zigbee ch 25 (2475 MHz)
    79, 80, 81     // Zigbee ch 26 (2480 MHz)
};

static const uint8_t JAM_USB_CHANNELS[] = { 40, 50, 60 };

static const uint8_t JAM_VIDEO_CHANNELS[] = { 70, 75, 80 };

static const uint8_t JAM_RC_CHANNELS[] = { 1, 3, 5, 7 };

// Full spectrum (generated at startup to save flash)
static uint8_t JAM_FULL_CHANNELS[125];
static bool fullChannelsInit = false;

static void initFullChannels() {
    if (!fullChannelsInit) {
        for (int i = 0; i < 125; i++) {
            JAM_FULL_CHANNELS[i] = i;
        }
        fullChannelsInit = true;
    }
}

// ── Determine jamming method per mode ───────────────────────────

/**
 * Returns true if the mode should use data flooding (writeFast),
 * false if it should use constant carrier (CW).
 *
 * - Constant Carrier: Best for FHSS targets (BT classic, drones)
 *   because the CW disrupts the PLL lock of hopping receivers.
 * - Data Flooding: Best for channel-specific targets (WiFi, BLE,
 *   Zigbee) because it creates actual packet collisions/corruption.
 */
static bool useDataFlooding(NrfJamMode mode) {
    switch (mode) {
        case NRF_JAM_BLE:
        case NRF_JAM_BLE_ADV:
        case NRF_JAM_WIFI:
        case NRF_JAM_ZIGBEE:
            return true;
        case NRF_JAM_BLUETOOTH:
        case NRF_JAM_DRONE:
        case NRF_JAM_USB:
        case NRF_JAM_VIDEO:
        case NRF_JAM_RC:
        case NRF_JAM_SINGLE:
            return false;
        case NRF_JAM_FULL:
        case NRF_JAM_HOPPER:
        default:
            return false;  // CW for full-band and custom range
    }
}

// ── Channel list accessor ───────────────────────────────────────

const uint8_t* NrfJammer::getChannelList(NrfJamMode mode, size_t& count) {
    switch (mode) {
        case NRF_JAM_BLE:
            count = sizeof(JAM_BLE_CHANNELS);
            return JAM_BLE_CHANNELS;
        case NRF_JAM_BLE_ADV:
            count = sizeof(JAM_BLE_ADV_CHANNELS);
            return JAM_BLE_ADV_CHANNELS;
        case NRF_JAM_BLUETOOTH:
            count = sizeof(JAM_BLUETOOTH_CHANNELS);
            return JAM_BLUETOOTH_CHANNELS;
        case NRF_JAM_USB:
            count = sizeof(JAM_USB_CHANNELS);
            return JAM_USB_CHANNELS;
        case NRF_JAM_VIDEO:
            count = sizeof(JAM_VIDEO_CHANNELS);
            return JAM_VIDEO_CHANNELS;
        case NRF_JAM_RC:
            count = sizeof(JAM_RC_CHANNELS);
            return JAM_RC_CHANNELS;
        case NRF_JAM_ZIGBEE:
            count = sizeof(JAM_ZIGBEE_CHANNELS);
            return JAM_ZIGBEE_CHANNELS;
        case NRF_JAM_WIFI:
            // WiFi uses a special sweep in jammerTask, not a simple list
            count = 0;
            return nullptr;
        case NRF_JAM_DRONE:
            // Drone uses random channel hopping, not a list
            count = 0;
            return nullptr;
        case NRF_JAM_FULL:
        default:
            initFullChannels();
            count = 125;
            return JAM_FULL_CHANNELS;
    }
}

// ── Start/Stop ──────────────────────────────────────────────────

bool NrfJammer::start(NrfJamMode mode) {
    if (running_) {
        ESP_LOGW(TAG, "Already running");
        return false;
    }
    if (!NrfModule::isPresent()) {
        ESP_LOGE(TAG, "NRF not present");
        return false;
    }

    currentMode_ = mode;
    stopRequest_ = false;
    running_ = true;

    BaseType_t result = xTaskCreatePinnedToCore(
        jammerTask, "NrfJam", 4096, nullptr, 2, &taskHandle_, 1);

    if (result != pdPASS) {
        ESP_LOGE(TAG, "Failed to create jammer task");
        running_ = false;
        return false;
    }

    // Notify app that jammer is active
    uint8_t notif[3] = { MSG_NRF_JAM_STATUS, 1, (uint8_t)mode };
    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::NrfEvent, notif, sizeof(notif));

    ESP_LOGI(TAG, "Jammer started (mode=%d)", mode);
    return true;
}

bool NrfJammer::startSingleChannel(uint8_t channel) {
    if (running_) {
        ESP_LOGW(TAG, "Already running");
        return false;
    }

    currentChannel_ = channel;
    currentMode_ = NRF_JAM_SINGLE;
    return start(NRF_JAM_SINGLE);
}

bool NrfJammer::startHopper(const NrfHopperConfig& config) {
    if (running_) {
        ESP_LOGW(TAG, "Already running");
        return false;
    }

    hopperConfig_ = config;
    currentMode_ = NRF_JAM_HOPPER;
    return start(NRF_JAM_HOPPER);
}

bool NrfJammer::setMode(NrfJamMode mode) {
    // Can change mode while running (atomic write)
    currentMode_ = mode;
    return true;
}

bool NrfJammer::setChannel(uint8_t channel) {
    currentChannel_ = channel;
    return true;
}

void NrfJammer::stop() {
    if (!running_) return;
    stopRequest_ = true;
    ESP_LOGI(TAG, "Jammer stop requested");
}

// ── WiFi Bandwidth Sweep ────────────────────────────────────────

/**
 * Sweep all 22 nRF24 channels that make up one WiFi channel's bandwidth.
 * WiFi channel N (1-indexed) center = 2412 + 5*(N-1) MHz = nRF24 ch 12+5*(N-1).
 * Bandwidth = 22 MHz, so sweep from center-11 to center+10.
 *
 * This function sweeps all 13 WiFi channels sequentially, flooding
 * each sub-channel with garbage data.
 */
static void wifiJamSweep() {
    for (int wifiCh = 0; wifiCh < 13; wifiCh++) {
        int startCh = (wifiCh * 5) + 1;
        for (int ch = startCh; ch < startCh + 22; ch++) {
            if (ch >= 0 && ch <= 125) {
                NrfModule::setChannel(ch);
                NrfModule::writeFast(JAM_FLOOD_DATA, sizeof(JAM_FLOOD_DATA));
            }
        }
    }
}

// ── Jammer Task ─────────────────────────────────────────────────

void NrfJammer::jammerTask(void* param) {
    ESP_LOGI(TAG, "Jammer task started");

    if (!NrfModule::acquireSpi()) {
        ESP_LOGE(TAG, "SPI busy");
        running_ = false;
        vTaskDelete(nullptr);
        return;
    }

    NrfJamMode activeMode = currentMode_;
    bool flooding = useDataFlooding(activeMode);

    // Common radio setup
    NrfModule::writeRegister(NRF_REG_CONFIG, NRF_PWR_UP);
    delay(2);

    NrfModule::setPALevel(3);           // Max power (0 dBm)
    NrfModule::setDataRate(NRF_2MBPS);  // 2 Mbps for maximum RF bandwidth
    NrfModule::writeRegister(NRF_REG_EN_AA, 0x00);     // No auto-ack
    NrfModule::writeRegister(NRF_REG_SETUP_RETR, 0x00); // No retries
    NrfModule::disableCRC();            // No CRC for maximum speed
    NrfModule::setAddressWidth(3);      // Minimum address for speed
    NrfModule::setPayloadSize(sizeof(JAM_FLOOD_DATA));

    if (!flooding) {
        // Constant Carrier mode: start CW on initial channel
        NrfModule::startConstCarrier(currentChannel_);
    } else {
        // Data flooding: configure TX mode (no constant carrier)
        NrfModule::writeRegister(NRF_REG_CONFIG, NRF_PWR_UP);  // TX mode, no CRC
        NrfModule::flushTx();
        NrfModule::writeRegister(NRF_REG_STATUS, 0x70);  // Clear flags
    }

    size_t hopIndex = 0;

    while (!stopRequest_) {
        // Check if mode changed dynamically
        if (activeMode != currentMode_) {
            activeMode = currentMode_;
            flooding = useDataFlooding(activeMode);
            hopIndex = 0;

            if (!flooding) {
                // Switch to constant carrier
                NrfModule::startConstCarrier(currentChannel_);
            } else {
                // Switch to data flooding: stop carrier, configure TX
                NrfModule::stopConstCarrier();
                NrfModule::writeRegister(NRF_REG_CONFIG, NRF_PWR_UP);
                delay(2);
                NrfModule::setPALevel(3);
                NrfModule::setDataRate(NRF_2MBPS);
                NrfModule::writeRegister(NRF_REG_EN_AA, 0x00);
                NrfModule::writeRegister(NRF_REG_SETUP_RETR, 0x00);
                NrfModule::disableCRC();
                NrfModule::flushTx();
                NrfModule::writeRegister(NRF_REG_STATUS, 0x70);
            }
        }

        // ── WiFi mode: special sweep across bandwidth ───────────
        if (activeMode == NRF_JAM_WIFI) {
            wifiJamSweep();
            // Yield to other tasks briefly
            vTaskDelay(pdMS_TO_TICKS(1));
            continue;
        }

        // ── Drone mode: random channel hopping with CW ─────────
        if (activeMode == NRF_JAM_DRONE) {
            uint8_t randomCh = random(125);
            NrfModule::ceLow();
            NrfModule::setChannel(randomCh);
            NrfModule::ceHigh();
            vTaskDelay(pdMS_TO_TICKS(1));
            continue;
        }

        // ── Single channel: keep carrier on one channel ─────────
        if (activeMode == NRF_JAM_SINGLE) {
            if (!flooding) {
                NrfModule::ceLow();
                NrfModule::setChannel(currentChannel_);
                NrfModule::ceHigh();
            } else {
                NrfModule::setChannel(currentChannel_);
                NrfModule::writeFast(JAM_FLOOD_DATA, sizeof(JAM_FLOOD_DATA));
            }
            vTaskDelay(pdMS_TO_TICKS(1));
            continue;
        }

        // ── Hopper mode: custom range ───────────────────────────
        if (activeMode == NRF_JAM_HOPPER) {
            if (!flooding) {
                NrfModule::ceLow();
                NrfModule::setChannel(currentChannel_);
                NrfModule::ceHigh();
            } else {
                NrfModule::setChannel(currentChannel_);
                NrfModule::writeFast(JAM_FLOOD_DATA, sizeof(JAM_FLOOD_DATA));
            }
            currentChannel_ += hopperConfig_.stepSize;
            if (currentChannel_ > hopperConfig_.stopChannel) {
                currentChannel_ = hopperConfig_.startChannel;
            }
            vTaskDelay(pdMS_TO_TICKS(1));
            continue;
        }

        // ── Preset modes: hop through channel list ──────────────
        size_t count;
        const uint8_t* channels = getChannelList(activeMode, count);
        if (count > 0 && channels != nullptr) {
            uint8_t ch = channels[hopIndex % count];

            if (flooding) {
                // Data flooding: set channel and spam garbage
                NrfModule::setChannel(ch);
                NrfModule::writeFast(JAM_FLOOD_DATA, sizeof(JAM_FLOOD_DATA));
            } else {
                // Constant carrier: toggle CE for PLL re-lock
                NrfModule::ceLow();
                NrfModule::setChannel(ch);
                NrfModule::ceHigh();
            }

            hopIndex++;
            if (hopIndex >= count) hopIndex = 0;
        }

        // 1ms delay: fast enough for effective jamming while giving
        // other Core-1 tasks CPU time. Full sweep at 125 channels
        // takes ~125ms which is well within effective jamming range.
        vTaskDelay(pdMS_TO_TICKS(1));
    }

    // Cleanup
    NrfModule::stopConstCarrier();
    NrfModule::flushTx();
    NrfModule::powerDown();
    NrfModule::releaseSpi();

    running_ = false;
    taskHandle_ = nullptr;

    // Notify app that jammer stopped
    uint8_t notif[3] = { MSG_NRF_JAM_STATUS, 0, 0 };
    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::NrfEvent, notif, sizeof(notif));

    ESP_LOGI(TAG, "Jammer task ended");
    vTaskDelete(nullptr);
}
