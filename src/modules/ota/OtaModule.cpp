/**
 * @file OtaModule.cpp
 * @brief BLE OTA firmware update implementation.
 *
 * Uses the ESP32 Update library to write firmware chunks to the
 * inactive OTA partition. Verifies MD5 integrity before marking
 * the new partition as bootable.
 */

#include "OtaModule.h"
#include "esp_log.h"
#include "esp_ota_ops.h"

static const char* TAG = "OtaModule";

// Static members
OtaState  OtaModule::state_         = OTA_IDLE;
uint32_t  OtaModule::totalSize_     = 0;
uint32_t  OtaModule::bytesReceived_ = 0;
char      OtaModule::expectedMd5_[33] = {};
char      OtaModule::lastError_[64] = {};

bool OtaModule::begin(uint32_t totalSize, const char* md5Hash) {
    if (state_ != OTA_IDLE) {
        snprintf(lastError_, sizeof(lastError_), "OTA already in progress (state=%d)", state_);
        ESP_LOGE(TAG, "%s", lastError_);
        return false;
    }

    // Validate size (must fit in OTA partition: ~1900KB = 0x1D0000)
    if (totalSize == 0 || totalSize > 0x1D0000) {
        snprintf(lastError_, sizeof(lastError_), "Invalid size: %lu (max=%lu)", 
                 (unsigned long)totalSize, (unsigned long)0x1D0000);
        ESP_LOGE(TAG, "%s", lastError_);
        return false;
    }

    // Store expected MD5
    if (md5Hash && strlen(md5Hash) == 32) {
        strncpy(expectedMd5_, md5Hash, 32);
        expectedMd5_[32] = '\0';
    } else {
        expectedMd5_[0] = '\0';
        ESP_LOGW(TAG, "No MD5 hash provided — skipping verification");
    }

    // Begin ESP32 Update
    if (!Update.begin(totalSize, U_FLASH)) {
        snprintf(lastError_, sizeof(lastError_), "Update.begin failed: %s", 
                 Update.errorString());
        ESP_LOGE(TAG, "%s", lastError_);
        return false;
    }

    // Set MD5 for verification if provided
    if (expectedMd5_[0] != '\0') {
        Update.setMD5(expectedMd5_);
    }

    totalSize_ = totalSize;
    bytesReceived_ = 0;
    state_ = OTA_RECEIVING;
    lastError_[0] = '\0';

    ESP_LOGI(TAG, "OTA started: size=%lu, md5=%s", 
             (unsigned long)totalSize, expectedMd5_[0] ? expectedMd5_ : "none");
    return true;
}

bool OtaModule::writeChunk(const uint8_t* data, size_t len) {
    if (state_ != OTA_RECEIVING) {
        snprintf(lastError_, sizeof(lastError_), "Not receiving (state=%d)", state_);
        return false;
    }

    if (bytesReceived_ + len > totalSize_) {
        snprintf(lastError_, sizeof(lastError_), "Chunk exceeds total size");
        ESP_LOGE(TAG, "%s", lastError_);
        abort();
        return false;
    }

    size_t written = Update.write(const_cast<uint8_t*>(data), len);
    if (written != len) {
        snprintf(lastError_, sizeof(lastError_), "Write failed: %s", 
                 Update.errorString());
        ESP_LOGE(TAG, "%s (wrote %zu of %zu)", lastError_, written, len);
        abort();
        return false;
    }

    bytesReceived_ += len;

    // Log progress every 10%
    uint8_t pct = getProgress();
    static uint8_t lastPct = 0;
    if (pct / 10 != lastPct / 10) {
        ESP_LOGI(TAG, "OTA progress: %d%% (%lu/%lu)", pct, 
                 (unsigned long)bytesReceived_, (unsigned long)totalSize_);
        lastPct = pct;
    }

    return true;
}

bool OtaModule::end() {
    if (state_ != OTA_RECEIVING) {
        snprintf(lastError_, sizeof(lastError_), "Not receiving (state=%d)", state_);
        return false;
    }

    if (bytesReceived_ != totalSize_) {
        snprintf(lastError_, sizeof(lastError_), "Incomplete: %lu/%lu bytes",
                 (unsigned long)bytesReceived_, (unsigned long)totalSize_);
        ESP_LOGE(TAG, "%s", lastError_);
        abort();
        return false;
    }

    state_ = OTA_VERIFYING;

    // Finalize — this verifies MD5 if set
    if (!Update.end(true)) {
        snprintf(lastError_, sizeof(lastError_), "Verify failed: %s", 
                 Update.errorString());
        ESP_LOGE(TAG, "%s", lastError_);
        state_ = OTA_ERROR;
        return false;
    }

    state_ = OTA_COMPLETE;
    ESP_LOGI(TAG, "OTA update verified and written successfully!");
    ESP_LOGI(TAG, "Reboot to activate new firmware.");
    return true;
}

void OtaModule::abort() {
    if (state_ == OTA_IDLE) return;

    Update.abort();
    state_ = OTA_ERROR;
    ESP_LOGW(TAG, "OTA aborted: %s", lastError_[0] ? lastError_ : "user abort");
}

void OtaModule::reboot() {
    ESP_LOGI(TAG, "Rebooting to new firmware...");
    delay(500);
    ESP.restart();
}

uint8_t OtaModule::getProgress() {
    if (totalSize_ == 0) return 0;
    return (uint8_t)((bytesReceived_ * 100) / totalSize_);
}
