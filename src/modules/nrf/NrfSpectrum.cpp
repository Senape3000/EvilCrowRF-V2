/**
 * @file NrfSpectrum.cpp
 * @brief 2.4 GHz spectrum analyzer implementation.
 *
 * Uses the nRF24L01+ RPD (Received Power Detector) register to detect
 * signal presence on each channel. Applies exponential moving average
 * for smooth visualization (like the BRUCE firmware approach).
 */

#include "NrfSpectrum.h"
#include "NrfModule.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "esp_log.h"

static const char* TAG = "NrfSpectrum";

// Static members
volatile bool NrfSpectrum::running_     = false;
volatile bool NrfSpectrum::stopRequest_ = false;
TaskHandle_t  NrfSpectrum::taskHandle_  = nullptr;
uint8_t       NrfSpectrum::channelLevels_[NRF_SPECTRUM_CHANNELS] = {};

bool NrfSpectrum::start() {
    if (running_) {
        ESP_LOGW(TAG, "Already running");
        return false;
    }
    if (!NrfModule::isPresent()) {
        ESP_LOGE(TAG, "NRF not present");
        return false;
    }

    stopRequest_ = false;
    running_ = true;
    memset(channelLevels_, 0, sizeof(channelLevels_));

    BaseType_t result = xTaskCreatePinnedToCore(
        spectrumTask, "NrfSpec", 3072, nullptr, 2, &taskHandle_, 1);

    if (result != pdPASS) {
        ESP_LOGE(TAG, "Failed to create spectrum task");
        running_ = false;
        return false;
    }

    ESP_LOGI(TAG, "Spectrum analyzer started");
    return true;
}

void NrfSpectrum::stop() {
    if (!running_) return;
    stopRequest_ = true;
    ESP_LOGI(TAG, "Spectrum stop requested");
}

void NrfSpectrum::getLevels(uint8_t* levels) {
    memcpy(levels, channelLevels_, NRF_SPECTRUM_CHANNELS);
}

void NrfSpectrum::scanOnce() {
    // Must be called with SPI mutex held.
    //
    // RPD (Received Power Detector) is a binary flag: 1 = signal above
    // -64 dBm at the chip input.  With a PA+LNA module (E01-ML01SP2) the
    // effective antenna threshold drops to roughly -90 dBm.
    //
    // Fast-decay EMA: (level + rpd * 100) / 2
    //   - One RPD hit brings the bar to 50, a second to 75, third to 87...
    //   - Decay: 100 → 50 → 25 → 12 → 6 (drops quickly when signal gone)
    // This gives a responsive, real-time spectrum display.

    NrfModule::ceLow();

    for (int i = 0; i < NRF_SPECTRUM_CHANNELS; i++) {
        NrfModule::setChannel(i);

        // Enter RX mode briefly to trigger RPD sampling
        NrfModule::writeRegister(NRF_REG_CONFIG,
            NRF_PWR_UP | NRF_PRIM_RX);
        NrfModule::ceHigh();
        delayMicroseconds(170);  // ~170µs: 130µs RX settle + 40µs RPD sample window
        NrfModule::ceLow();

        // Read RPD: 1 = signal above -64dBm detected during RX
        int rpd = NrfModule::testRPD() ? 1 : 0;

        // Fast-decay EMA: (level + rpd * 100) / 2
        // Decay ratio ~50% per sweep — bars drop in 3-4 sweeps.
        channelLevels_[i] = (uint8_t)((channelLevels_[i] + rpd * 100) / 2);
    }
}

void NrfSpectrum::spectrumTask(void* param) {
    ESP_LOGI(TAG, "Spectrum task started");

    // Notification buffer: [msgType:1][80 channel levels]
    uint8_t notifBuf[1 + NRF_SPECTRUM_CHANNELS];
    notifBuf[0] = MSG_NRF_SPECTRUM_DATA;

    uint32_t notifyCounter = 0;

    while (!stopRequest_) {
        if (!NrfModule::acquireSpi(pdMS_TO_TICKS(100))) {
            vTaskDelay(pdMS_TO_TICKS(50));
            continue;
        }

        // Configure radio for wideband spectrum sensing
        NrfModule::writeRegister(NRF_REG_EN_AA, 0x00);    // No auto-ack
        NrfModule::writeRegister(NRF_REG_SETUP_AW, 0x00); // 2-byte address (promiscuous)
        NrfModule::setDataRate(NRF_1MBPS);

        // Open 6 reading pipes at noise-detection addresses exactly like
        // the BRUCE reference firmware. More pipes = higher sensitivity
        // because the radio checks all pipe addresses in parallel.
        const uint8_t noiseAddr[][2] = {
            {0x55, 0x55}, {0xAA, 0xAA}, {0xA0, 0xAA},
            {0xAB, 0xAA}, {0xAC, 0xAA}, {0xAD, 0xAA}
        };
        NrfModule::writeRegister(NRF_REG_RX_ADDR_P0, noiseAddr[0], 2);
        NrfModule::writeRegister(NRF_REG_RX_ADDR_P1, noiseAddr[1], 2);
        // Pipes 2-5 share address bytes [1..N] with pipe 1, only byte 0 differs
        NrfModule::writeRegister(0x0C, noiseAddr[2][0]); // RX_ADDR_P2
        NrfModule::writeRegister(0x0D, noiseAddr[3][0]); // RX_ADDR_P3
        NrfModule::writeRegister(0x0E, noiseAddr[4][0]); // RX_ADDR_P4
        NrfModule::writeRegister(0x0F, noiseAddr[5][0]); // RX_ADDR_P5
        NrfModule::writeRegister(NRF_REG_EN_RXADDR, 0x3F); // Enable all 6 pipes

        // Perform one full sweep
        scanOnce();

        NrfModule::powerDown();
        NrfModule::releaseSpi();

        // Send levels via BLE notification every 2nd sweep for smooth
        // real-time display (was every 3rd — too laggy for spectrum viz)
        notifyCounter++;
        if (notifyCounter % 2 == 0) {
            memcpy(notifBuf + 1, channelLevels_, NRF_SPECTRUM_CHANNELS);
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::NrfEvent, notifBuf, sizeof(notifBuf));
        }

        // ~25ms between scans gives ~40fps effective update rate
        vTaskDelay(pdMS_TO_TICKS(25));
    }

    // Cleanup
    running_ = false;
    taskHandle_ = nullptr;
    ESP_LOGI(TAG, "Spectrum task ended");
    vTaskDelete(nullptr);
}
