/**
 * @file NrfModule.cpp
 * @brief nRF24L01+ hardware abstraction — minimal custom driver.
 *
 * Shares HSPI bus with CC1101 modules via ModuleCc1101::rwSemaphore.
 * Only implements the subset needed for MouseJack + spectrum + jammer.
 */

#include "NrfModule.h"
#include "modules/CC1101_driver/CC1101_Module.h"
#include "CC1101_Radio.h"  // For cc1101 global — setSidle() before NRF bus switch
#include "esp_log.h"

static const char* TAG = "NrfModule";

// Static members
bool NrfModule::initialized_ = false;
bool NrfModule::present_     = false;
SPIClass* NrfModule::hspi_   = nullptr;

// ── Initialization ──────────────────────────────────────────────

bool NrfModule::init() {
#if !NRF_MODULE_ENABLED
    ESP_LOGI(TAG, "NRF module disabled in config");
    return false;
#endif

    if (initialized_) {
        ESP_LOGW(TAG, "Already initialized");
        return present_;
    }

    // Configure control pins
    pinMode(NRF_CE, OUTPUT);
    digitalWrite(NRF_CE, LOW);

    pinMode(NRF_CSN, OUTPUT);
    digitalWrite(NRF_CSN, HIGH);

    // Use the existing HSPI instance shared with CC1101
    // The CC1101 Radio code uses global SPIClass CCSPI(HSPI)
    // We create our own reference but on the same hardware bus
    static SPIClass nrfSpi(HSPI);
    hspi_ = &nrfSpi;

    // Verify chip presence by reading STATUS register
    if (!acquireSpi(pdMS_TO_TICKS(500))) {
        ESP_LOGE(TAG, "Failed to acquire SPI mutex during init");
        return false;
    }

    // Initialize HSPI with our pins
    hspi_->begin(CC1101_SCK, CC1101_MISO, CC1101_MOSI, NRF_CSN);

    // Read status register — should return valid value (not 0x00 or 0xFF)
    uint8_t status = readRegister(NRF_REG_STATUS);
    ESP_LOGI(TAG, "nRF24L01 STATUS register: 0x%02X", status);

    if (status == 0x00 || status == 0xFF) {
        ESP_LOGE(TAG, "nRF24L01 not detected (STATUS=0x%02X)", status);
        present_ = false;
        releaseSpi();
        initialized_ = true;  // Mark initialized to prevent retries
        return false;
    }

    // Basic configuration: power up, disable auto-ack, CRC off
    writeRegister(NRF_REG_CONFIG, NRF_PWR_UP);
    delay(2);  // Power-up delay (1.5ms typ)

    writeRegister(NRF_REG_EN_AA, 0x00);       // Disable auto-ack on all pipes
    writeRegister(NRF_REG_EN_RXADDR, 0x03);   // Enable pipes 0 and 1
    writeRegister(NRF_REG_SETUP_AW, 0x03);    // 5-byte address width
    writeRegister(NRF_REG_SETUP_RETR, 0x0F);  // 500µs retransmit delay, 15 retries
    writeRegister(NRF_REG_RF_CH, 0x02);       // Channel 2 default
    writeRegister(NRF_REG_RF_SETUP, NRF_RF_DR_HIGH | NRF_RF_PWR_MAX); // 2Mbps, 0dBm
    writeRegister(NRF_REG_DYNPD, 0x00);       // Disable dynamic payload
    writeRegister(NRF_REG_FEATURE, 0x00);     // Disable features

    // Flush FIFOs
    flushTx();
    flushRx();

    // Clear status flags
    writeRegister(NRF_REG_STATUS, 0x70);

    releaseSpi();

    present_ = true;
    initialized_ = true;
    ESP_LOGI(TAG, "nRF24L01 initialized successfully");
    return true;
}

void NrfModule::deinit() {
    if (!initialized_) return;

    if (acquireSpi()) {
        powerDown();
        releaseSpi();
    }

    digitalWrite(NRF_CE, LOW);
    digitalWrite(NRF_CSN, HIGH);

    initialized_ = false;
    present_ = false;
    ESP_LOGI(TAG, "nRF24L01 deinitialized");
}

bool NrfModule::isPresent() {
    return present_;
}

// ── SPI Bus Management ──────────────────────────────────────────

bool NrfModule::acquireSpi(TickType_t timeout) {
    SemaphoreHandle_t mutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(mutex, timeout) != pdTRUE) {
        ESP_LOGW(TAG, "SPI mutex timeout");
        return false;
    }

    // Put both CC1101 modules into idle before switching bus to NRF.
    // This prevents spurious CC1101 SPI activity and ensures clean handover.
    cc1101.setModul(MODULE_1);
    cc1101.setSidle();
    cc1101.setModul(MODULE_2);
    cc1101.setSidle();

    // Deselect all CC1101 CS lines to avoid bus contention
    digitalWrite(CC1101_SS0, HIGH);
    digitalWrite(CC1101_SS1, HIGH);

    // Small delay to let CC1101 settle into idle
    delayMicroseconds(100);

    // Re-initialize HSPI for NRF pin configuration.
    // CC1101 Radio calls SPI.end() on some paths, so we must re-begin.
    hspi_->begin(CC1101_SCK, CC1101_MISO, CC1101_MOSI, NRF_CSN);

    return true;
}

void NrfModule::releaseSpi() {
    // Ensure CE is low (not listening/transmitting)
    digitalWrite(NRF_CE, LOW);
    // Deselect NRF chip select
    digitalWrite(NRF_CSN, HIGH);

    // End our SPI bus usage so CC1101 can re-initialize cleanly.
    // NOTE: Do NOT call endTransaction() here — individual register
    // read/write operations already manage their own transactions.
    // Calling endTransaction() without a matching beginTransaction()
    // corrupts the SPI driver state and breaks subsequent CC1101 use.
    hspi_->end();

    SemaphoreHandle_t mutex = ModuleCc1101::getSpiSemaphore();
    xSemaphoreGive(mutex);
}

// ── SPI Transaction Helpers ─────────────────────────────────────

void NrfModule::beginTransaction() {
    hspi_->beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
    digitalWrite(NRF_CSN, LOW);
}

void NrfModule::endTransaction() {
    digitalWrite(NRF_CSN, HIGH);
    hspi_->endTransaction();
}

uint8_t NrfModule::spiTransfer(uint8_t cmd) {
    return hspi_->transfer(cmd);
}

void NrfModule::spiTransfer(uint8_t cmd, uint8_t* buf, uint8_t len) {
    hspi_->transfer(cmd);
    for (uint8_t i = 0; i < len; i++) {
        buf[i] = hspi_->transfer(buf[i]);
    }
}

// ── Register Access ─────────────────────────────────────────────

uint8_t NrfModule::readRegister(uint8_t reg) {
    beginTransaction();
    spiTransfer(NRF_CMD_R_REGISTER | (reg & 0x1F));
    uint8_t val = spiTransfer(NRF_CMD_NOP);
    endTransaction();
    return val;
}

void NrfModule::readRegister(uint8_t reg, uint8_t* buf, uint8_t len) {
    beginTransaction();
    spiTransfer(NRF_CMD_R_REGISTER | (reg & 0x1F));
    for (uint8_t i = 0; i < len; i++) {
        buf[i] = spiTransfer(NRF_CMD_NOP);
    }
    endTransaction();
}

void NrfModule::writeRegister(uint8_t reg, uint8_t value) {
    beginTransaction();
    spiTransfer(NRF_CMD_W_REGISTER | (reg & 0x1F));
    spiTransfer(value);
    endTransaction();
}

void NrfModule::writeRegister(uint8_t reg, const uint8_t* buf, uint8_t len) {
    beginTransaction();
    spiTransfer(NRF_CMD_W_REGISTER | (reg & 0x1F));
    for (uint8_t i = 0; i < len; i++) {
        spiTransfer(buf[i]);
    }
    endTransaction();
}

// ── Radio Operations ────────────────────────────────────────────

void NrfModule::setChannel(uint8_t ch) {
    writeRegister(NRF_REG_RF_CH, ch & 0x7F);
}

uint8_t NrfModule::getChannel() {
    return readRegister(NRF_REG_RF_CH);
}

void NrfModule::setDataRate(NrfDataRate rate) {
    uint8_t setup = readRegister(NRF_REG_RF_SETUP);
    setup &= ~(NRF_RF_DR_HIGH | NRF_RF_DR_LOW);  // Clear rate bits

    switch (rate) {
        case NRF_1MBPS:
            // Both bits 0
            break;
        case NRF_2MBPS:
            setup |= NRF_RF_DR_HIGH;
            break;
        case NRF_250KBPS:
            setup |= NRF_RF_DR_LOW;
            break;
    }
    writeRegister(NRF_REG_RF_SETUP, setup);
}

void NrfModule::setPALevel(uint8_t level) {
    uint8_t setup = readRegister(NRF_REG_RF_SETUP);
    setup &= ~0x06;  // Clear PA bits
    setup |= ((level & 0x03) << 1);
    writeRegister(NRF_REG_RF_SETUP, setup);
}

void NrfModule::setAddressWidth(uint8_t width) {
    if (width < 2) width = 2;
    if (width > 5) width = 5;
    writeRegister(NRF_REG_SETUP_AW, width - 2);
}

void NrfModule::setPromiscuousMode() {
    ceLow();

    // Disable CRC, enable RX mode
    writeRegister(NRF_REG_CONFIG, NRF_PWR_UP | NRF_PRIM_RX);

    // Disable auto-ack
    writeRegister(NRF_REG_EN_AA, 0x00);

    // 2-byte address width for promiscuous (reverse engineering trick)
    setAddressWidth(2);

    // Set known preamble addresses for noise detection
    const uint8_t addr0[] = {0x55, 0x55};
    const uint8_t addr1[] = {0xAA, 0xAA};
    writeRegister(NRF_REG_RX_ADDR_P0, addr0, 2);
    writeRegister(NRF_REG_RX_ADDR_P1, addr1, 2);

    // Enable pipes 0 and 1
    writeRegister(NRF_REG_EN_RXADDR, 0x03);

    // Max payload size for sniffing
    writeRegister(NRF_REG_RX_PW_P0, 32);
    writeRegister(NRF_REG_RX_PW_P1, 32);

    // Flush RX FIFO
    flushRx();

    // Clear status
    writeRegister(NRF_REG_STATUS, 0x70);

    // Start listening
    ceHigh();
}

void NrfModule::setTxMode(const uint8_t* addr, uint8_t addrLen) {
    ceLow();

    // Set address width
    setAddressWidth(addrLen);

    // Set TX and RX_P0 addresses (for auto-ack)
    writeRegister(NRF_REG_TX_ADDR, addr, addrLen);
    writeRegister(NRF_REG_RX_ADDR_P0, addr, addrLen);

    // Configure for TX
    uint8_t config = readRegister(NRF_REG_CONFIG);
    config &= ~NRF_PRIM_RX;  // TX mode
    config |= NRF_PWR_UP;
    writeRegister(NRF_REG_CONFIG, config);

    // Flush TX FIFO
    flushTx();

    // Clear status
    writeRegister(NRF_REG_STATUS, 0x70);
}

uint8_t NrfModule::receive(uint8_t* buf, uint8_t maxLen) {
    uint8_t status = readRegister(NRF_REG_STATUS);

    if (!(status & (1 << 6))) {
        return 0;  // No RX data ready
    }

    // Read payload
    uint8_t pipeNo = (status >> 1) & 0x07;
    uint8_t payloadWidth = readRegister(NRF_REG_RX_PW_P0 + pipeNo);
    if (payloadWidth > maxLen) payloadWidth = maxLen;
    if (payloadWidth > 32) payloadWidth = 32;

    beginTransaction();
    spiTransfer(NRF_CMD_R_RX_PAYLOAD);
    for (uint8_t i = 0; i < payloadWidth; i++) {
        buf[i] = spiTransfer(NRF_CMD_NOP);
    }
    endTransaction();

    // Clear RX_DR flag
    writeRegister(NRF_REG_STATUS, (1 << 6));

    return payloadWidth;
}

bool NrfModule::transmit(const uint8_t* buf, uint8_t len) {
    if (len > 32) len = 32;

    // Write TX payload
    beginTransaction();
    spiTransfer(NRF_CMD_W_TX_PAYLOAD);
    for (uint8_t i = 0; i < len; i++) {
        spiTransfer(buf[i]);
    }
    endTransaction();

    // Pulse CE to transmit
    ceHigh();
    delayMicroseconds(15);
    ceLow();

    // Wait for TX complete or MAX_RT (timeout ~4ms with 15 retries)
    uint32_t startMs = millis();
    while (millis() - startMs < 50) {
        uint8_t status = readRegister(NRF_REG_STATUS);
        if (status & NRF_MASK_TX_DS) {
            // TX success
            writeRegister(NRF_REG_STATUS, NRF_MASK_TX_DS);
            return true;
        }
        if (status & NRF_MASK_MAX_RT) {
            // Max retransmits reached
            writeRegister(NRF_REG_STATUS, NRF_MASK_MAX_RT);
            flushTx();
            return false;
        }
        delayMicroseconds(100);
    }

    // Timeout
    flushTx();
    return false;
}

void NrfModule::writeFast(const void* buf, uint8_t len) {
    if (len > 32) len = 32;

    // Write TX payload
    beginTransaction();
    spiTransfer(NRF_CMD_W_TX_PAYLOAD);
    const uint8_t* p = static_cast<const uint8_t*>(buf);
    for (uint8_t i = 0; i < len; i++) {
        spiTransfer(p[i]);
    }
    endTransaction();

    // Pulse CE to trigger transmission (non-blocking)
    ceHigh();
    delayMicroseconds(15);
    ceLow();
}

void NrfModule::setPayloadSize(uint8_t size) {
    if (size > 32) size = 32;
    writeRegister(NRF_REG_RX_PW_P0, size);
    writeRegister(NRF_REG_RX_PW_P1, size);
}

void NrfModule::disableCRC() {
    uint8_t config = readRegister(NRF_REG_CONFIG);
    config &= ~NRF_EN_CRC;
    writeRegister(NRF_REG_CONFIG, config);
}

void NrfModule::startConstCarrier(uint8_t channel) {
    ceLow();

    // Power up, TX mode
    writeRegister(NRF_REG_CONFIG, NRF_PWR_UP);
    delay(2);

    // Set max power, force PLL lock, set data rate
    uint8_t rfSetup = readRegister(NRF_REG_RF_SETUP);
    rfSetup |= 0x90;  // CONT_WAVE + PLL_LOCK
    rfSetup |= NRF_RF_PWR_MAX;
    writeRegister(NRF_REG_RF_SETUP, rfSetup);

    setChannel(channel);

    // Disable auto-ack
    writeRegister(NRF_REG_EN_AA, 0x00);

    ceHigh();
    ESP_LOGI(TAG, "Constant carrier on channel %d", channel);
}

void NrfModule::stopConstCarrier() {
    ceLow();

    uint8_t rfSetup = readRegister(NRF_REG_RF_SETUP);
    rfSetup &= ~0x90;  // Clear CONT_WAVE + PLL_LOCK
    writeRegister(NRF_REG_RF_SETUP, rfSetup);

    powerDown();
    ESP_LOGI(TAG, "Constant carrier stopped");
}

void NrfModule::flushTx() {
    beginTransaction();
    spiTransfer(NRF_CMD_FLUSH_TX);
    endTransaction();
}

void NrfModule::flushRx() {
    beginTransaction();
    spiTransfer(NRF_CMD_FLUSH_RX);
    endTransaction();
}

void NrfModule::powerDown() {
    ceLow();
    uint8_t config = readRegister(NRF_REG_CONFIG);
    config &= ~NRF_PWR_UP;
    writeRegister(NRF_REG_CONFIG, config);
}

void NrfModule::powerUp() {
    uint8_t config = readRegister(NRF_REG_CONFIG);
    config |= NRF_PWR_UP;
    writeRegister(NRF_REG_CONFIG, config);
    delay(2);
}

bool NrfModule::testRPD() {
    return readRegister(NRF_REG_RPD) & 0x01;
}

void NrfModule::ceHigh() {
    digitalWrite(NRF_CE, HIGH);
}

void NrfModule::ceLow() {
    digitalWrite(NRF_CE, LOW);
}
