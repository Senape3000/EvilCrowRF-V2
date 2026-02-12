/**
 * @file NrfModule.h
 * @brief nRF24L01 hardware abstraction layer for EvilCrow-RF-V2.
 *
 * Provides low-level register access, SPI bus management with CC1101
 * coexistence via shared HSPI mutex, and basic radio operations
 * (channel set, promiscuous RX, TX).
 *
 * Pin assignment (same PCB as EvilMouse):
 *   CE  = GPIO 33   (Chip Enable)
 *   CSN = GPIO 15   (SPI Chip Select)
 *   SCK/MISO/MOSI shared with CC1101 on HSPI (14/12/13)
 */

#ifndef NRF_MODULE_H
#define NRF_MODULE_H

#include <Arduino.h>
#include <SPI.h>
#include <freertos/semphr.h>
#include "config.h"

// ── nRF24L01+ register map (subset we actually use) ──────────────
#define NRF_REG_CONFIG       0x00
#define NRF_REG_EN_AA        0x01
#define NRF_REG_EN_RXADDR    0x02
#define NRF_REG_SETUP_AW     0x03
#define NRF_REG_SETUP_RETR   0x04
#define NRF_REG_RF_CH        0x05
#define NRF_REG_RF_SETUP     0x06
#define NRF_REG_STATUS       0x07
#define NRF_REG_OBSERVE_TX   0x08
#define NRF_REG_RPD          0x09
#define NRF_REG_RX_ADDR_P0   0x0A
#define NRF_REG_RX_ADDR_P1   0x0B
#define NRF_REG_TX_ADDR      0x10
#define NRF_REG_RX_PW_P0     0x11
#define NRF_REG_RX_PW_P1     0x12
#define NRF_REG_FIFO_STATUS  0x17
#define NRF_REG_DYNPD        0x1C
#define NRF_REG_FEATURE      0x1D

// SPI commands
#define NRF_CMD_R_REGISTER    0x00
#define NRF_CMD_W_REGISTER    0x20
#define NRF_CMD_R_RX_PAYLOAD  0x61
#define NRF_CMD_W_TX_PAYLOAD  0xA0
#define NRF_CMD_FLUSH_TX      0xE1
#define NRF_CMD_FLUSH_RX      0xE2
#define NRF_CMD_NOP           0xFF

// Config bits
#define NRF_MASK_RX_DR   (1 << 6)
#define NRF_MASK_TX_DS   (1 << 5)
#define NRF_MASK_MAX_RT  (1 << 4)
#define NRF_EN_CRC       (1 << 3)
#define NRF_CRCO         (1 << 2)
#define NRF_PWR_UP       (1 << 1)
#define NRF_PRIM_RX      (1 << 0)

// RF Setup bits
#define NRF_RF_DR_HIGH   (1 << 3)
#define NRF_RF_DR_LOW    (1 << 5)
#define NRF_RF_PWR_MAX   0x06     // 0dBm

// Data rates
enum NrfDataRate : uint8_t {
    NRF_1MBPS  = 0,
    NRF_2MBPS  = 1,
    NRF_250KBPS = 2
};

/**
 * @class NrfModule
 * @brief Minimal custom nRF24L01+ driver (~3KB) for MouseJack operations.
 *
 * Uses the existing CC1101 SPI mutex (ModuleCc1101::rwSemaphore)
 * for safe bus sharing.
 */
class NrfModule {
public:
    /**
     * Initialize nRF24L01 on shared HSPI bus.
     * Configures CE/CSN pins and verifies chip presence.
     * @return true if nRF24 responds correctly.
     */
    static bool init();

    /// Release SPI and set pins to idle state.
    static void deinit();

    /// @return true if nRF24 hardware is detected and initialized.
    static bool isPresent();

    /// @return true if module has been initialized.
    static bool isInitialized() { return initialized_; }

    // ── SPI bus management (uses CC1101 mutex) ──────────────────
    /// Acquire shared SPI mutex. Deselects all CC1101 CS lines.
    static bool acquireSpi(TickType_t timeout = pdMS_TO_TICKS(200));
    /// Release shared SPI mutex.
    static void releaseSpi();

    // ── Register access ─────────────────────────────────────────
    static uint8_t readRegister(uint8_t reg);
    static void readRegister(uint8_t reg, uint8_t* buf, uint8_t len);
    static void writeRegister(uint8_t reg, uint8_t value);
    static void writeRegister(uint8_t reg, const uint8_t* buf, uint8_t len);

    // ── Radio operations ────────────────────────────────────────
    static void setChannel(uint8_t ch);
    static uint8_t getChannel();
    static void setDataRate(NrfDataRate rate);
    static void setPALevel(uint8_t level);  // 0-3 (min-max)
    static void setAddressWidth(uint8_t width); // 2-5 bytes

    /// Enter promiscuous RX mode for scanning.
    static void setPromiscuousMode();

    /// Configure TX mode with target address.
    static void setTxMode(const uint8_t* addr, uint8_t addrLen);

    /// Attempt to receive a packet.  Returns bytes read, 0 if none.
    static uint8_t receive(uint8_t* buf, uint8_t maxLen);

    /// Transmit a packet (blocking, with retransmit).
    static bool transmit(const uint8_t* buf, uint8_t len);

    /**
     * Non-blocking fast write for jamming data flooding.
     * Loads payload into TX FIFO and pulses CE to transmit immediately.
     * Does NOT wait for TX completion — used for rapid channel-hopping spam.
     * @param buf  Payload data.
     * @param len  Payload length (max 32).
     */
    static void writeFast(const void* buf, uint8_t len);

    /// Set fixed payload size (1-32 bytes).
    static void setPayloadSize(uint8_t size);

    /// Disable CRC checking.
    static void disableCRC();

    /// Enable constant carrier (for jamming).
    static void startConstCarrier(uint8_t channel);

    /// Stop constant carrier.
    static void stopConstCarrier();

    /// Flush TX and RX FIFOs.
    static void flushTx();
    static void flushRx();

    /// Power down the radio.
    static void powerDown();

    /// Power up in standby.
    static void powerUp();

    /// Read RPD (Received Power Detector) — 1 = signal above -64dBm.
    static bool testRPD();

    /// CE pin control.
    static void ceHigh();
    static void ceLow();

private:
    static bool initialized_;
    static bool present_;
    static SPIClass* hspi_;

    /// Raw SPI transfer (must hold mutex).
    static uint8_t spiTransfer(uint8_t cmd);
    static void spiTransfer(uint8_t cmd, uint8_t* buf, uint8_t len);

    /// Begin/end SPI transaction (CSN low/high).
    static void beginTransaction();
    static void endTransaction();
};

#endif // NRF_MODULE_H
