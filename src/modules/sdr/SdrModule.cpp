/**
 * @file SdrModule.cpp
 * @brief SDR mode implementation for EvilCrow-RF-V2.
 *
 * Uses the CC1101 transceiver to provide spectrum scanning, raw RX
 * streaming, and a HackRF-compatible serial command interface.
 *
 * The CC1101 is NOT a true SDR — spectrum data is real RSSI, but
 * "raw RX" data comes from the demodulator, not as raw IQ samples.
 *
 * Thread safety: SDR operations use the CC1101 SPI semaphore
 * (ModuleCc1101::getSpiSemaphore()) for all hardware access.
 */

#include "SdrModule.h"

#if SDR_MODULE_ENABLED

#include "modules/CC1101_driver/CC1101_Worker.h"
#include "CC1101_Radio.h"
#include <cstring>

static const char* TAG = "SDR";

// ── Static member initialization ────────────────────────────────────

bool     SdrModule::active_            = false;
bool     SdrModule::streaming_         = false;
bool     SdrModule::initialized_       = false;
int      SdrModule::sdrModule_         = SDR_DEFAULT_MODULE;
float    SdrModule::currentFreqMHz_    = 433.92f;
int      SdrModule::currentModulation_ = MODULATION_ASK_OOK;
float    SdrModule::currentBandwidthKHz_ = 650.0f;
float    SdrModule::currentDataRate_   = 3.79372f;
uint32_t SdrModule::streamSeqNum_      = 0;
uint32_t SdrModule::totalBytesStreamed_ = 0;
SdrSubMode SdrModule::subMode_         = SdrSubMode::Idle;

// ── Initialization ──────────────────────────────────────────────────

void SdrModule::init() {
    if (initialized_) return;
    ESP_LOGI(TAG, "SDR module initialized (inactive, module=%d)", SDR_DEFAULT_MODULE);
    initialized_ = true;
}

// ── SDR mode lifecycle ──────────────────────────────────────────────

bool SdrModule::enable(int module) {
    if (active_) {
        ESP_LOGW(TAG, "SDR mode already active");
        return true;
    }

    // Validate module index
    if (module < 0 || module >= CC1101_NUM_MODULES) {
        ESP_LOGE(TAG, "Invalid CC1101 module index: %d", module);
        return false;
    }

    // Check that the target module is idle (not doing other work)
    CC1101State currentState = CC1101Worker::getState(module);
    if (currentState != CC1101State::Idle) {
        ESP_LOGE(TAG, "CC1101 module %d is busy (state=%d), cannot enter SDR mode",
                 module, (int)currentState);
        return false;
    }

    sdrModule_ = module;
    active_ = true;
    streaming_ = false;
    subMode_ = SdrSubMode::Idle;
    streamSeqNum_ = 0;
    totalBytesStreamed_ = 0;

    // Put the CC1101 module in idle mode
    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].setSidle();
        xSemaphoreGive(spiMutex);
    }

    ESP_LOGI(TAG, "SDR mode ENABLED on module %d", sdrModule_);
    sendStatus();
    return true;
}

bool SdrModule::disable() {
    if (!active_) {
        ESP_LOGW(TAG, "SDR mode already inactive");
        return true;
    }

    // Stop streaming if active
    if (streaming_) {
        stopRawRx();
    }

    // Put module back in idle
    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].setSidle();
        xSemaphoreGive(spiMutex);
    }

    active_ = false;
    subMode_ = SdrSubMode::Idle;

    ESP_LOGI(TAG, "SDR mode DISABLED");
    sendStatus();
    return true;
}

SdrState SdrModule::getState() {
    SdrState state;
    state.active         = active_;
    state.subMode        = subMode_;
    state.module         = sdrModule_;
    state.centerFreqMHz  = currentFreqMHz_;
    state.modulation     = currentModulation_;
    state.samplesStreamed = totalBytesStreamed_;
    return state;
}

// ── Frequency and configuration ─────────────────────────────────────

bool SdrModule::isValidFrequency(float freqMHz) {
    // CC1101 supported bands: 300-348, 387-464, 779-928 MHz
    return (freqMHz >= 300.0f && freqMHz <= 348.0f) ||
           (freqMHz >= 387.0f && freqMHz <= 464.0f) ||
           (freqMHz >= 779.0f && freqMHz <= 928.0f);
}

bool SdrModule::setFrequency(float freqMHz) {
    if (!active_) {
        ESP_LOGW(TAG, "Cannot set frequency: SDR mode not active");
        return false;
    }

    if (!isValidFrequency(freqMHz)) {
        ESP_LOGW(TAG, "Frequency %.2f MHz out of CC1101 range", freqMHz);
        return false;
    }

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].changeFrequency(freqMHz);
        currentFreqMHz_ = freqMHz;
        xSemaphoreGive(spiMutex);
        ESP_LOGI(TAG, "Frequency set to %.3f MHz", freqMHz);
        return true;
    }

    ESP_LOGE(TAG, "Failed to acquire SPI mutex for setFrequency");
    return false;
}

bool SdrModule::setModulation(int mod) {
    if (!active_) return false;

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        // Apply modulation via full config (keeps other settings)
        moduleCC1101State[sdrModule_].setConfig(
            MODE_RECEIVE, currentFreqMHz_, true, mod,
            currentBandwidthKHz_, 1.58f, currentDataRate_);
        moduleCC1101State[sdrModule_].initConfig();
        currentModulation_ = mod;
        xSemaphoreGive(spiMutex);
        ESP_LOGI(TAG, "Modulation set to %d", mod);
        return true;
    }
    return false;
}

bool SdrModule::setBandwidth(float bwKHz) {
    if (!active_) return false;

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].setReceiveConfig(
            currentFreqMHz_, true, currentModulation_,
            bwKHz, 1.58f, currentDataRate_);
        moduleCC1101State[sdrModule_].initConfig();
        currentBandwidthKHz_ = bwKHz;
        xSemaphoreGive(spiMutex);
        ESP_LOGI(TAG, "Bandwidth set to %.1f kHz", bwKHz);
        return true;
    }
    return false;
}

bool SdrModule::setDataRate(float rate) {
    if (!active_) return false;

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].setReceiveConfig(
            currentFreqMHz_, true, currentModulation_,
            currentBandwidthKHz_, 1.58f, rate);
        moduleCC1101State[sdrModule_].initConfig();
        currentDataRate_ = rate;
        xSemaphoreGive(spiMutex);
        ESP_LOGI(TAG, "Data rate set to %.2f kBaud", rate);
        return true;
    }
    return false;
}

// ── RSSI reading ────────────────────────────────────────────────────

int SdrModule::readRssi() {
    // The CC1101 provides RSSI in its status register.
    // moduleCC1101State[].getRssi() handles SPI read and dBm conversion.
    return moduleCC1101State[sdrModule_].getRssi();
}

// ── Spectrum scan ───────────────────────────────────────────────────

int SdrModule::spectrumScan(const SpectrumScanConfig& config) {
    if (!active_) {
        ESP_LOGW(TAG, "Cannot scan: SDR mode not active");
        return 0;
    }

    subMode_ = SdrSubMode::SpectrumScan;

    // Calculate total points
    float range = config.endFreqMHz - config.startFreqMHz;
    int totalPoints = (int)(range / config.stepMHz) + 1;
    if (totalPoints > SDR_MAX_SPECTRUM_POINTS) {
        totalPoints = SDR_MAX_SPECTRUM_POINTS;
    }
    if (totalPoints <= 0) {
        ESP_LOGW(TAG, "Invalid spectrum scan range");
        subMode_ = SdrSubMode::Idle;
        return 0;
    }

    ESP_LOGI(TAG, "Spectrum scan: %.2f-%.2f MHz, step=%.3f MHz, %d points",
             config.startFreqMHz, config.endFreqMHz, config.stepMHz, totalPoints);

    // Chunk size for BLE transmission (limited by BLE MTU ~120 bytes usable)
    const int chunkSize = 60;  // RSSI values per chunk
    int totalChunks = (totalPoints + chunkSize - 1) / chunkSize;

    // Allocate a small buffer for one chunk of RSSI values
    int8_t rssiBuffer[chunkSize];
    int pointsScanned = 0;
    int chunkIndex = 0;
    int bufferIdx = 0;
    float chunkStartFreqMHz = config.startFreqMHz;

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();

    for (int i = 0; i < totalPoints; i++) {
        float freq = config.startFreqMHz + i * config.stepMHz;

        // Skip frequencies outside valid CC1101 bands
        if (!isValidFrequency(freq)) {
            rssiBuffer[bufferIdx++] = -128;  // Mark as invalid
        } else {
            if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(50))) {
                // Set frequency
                moduleCC1101State[sdrModule_].changeFrequency(freq);

                // Enter RX mode for RSSI measurement
                cc1101.setModul(sdrModule_);
                cc1101.SetRx(freq);

                xSemaphoreGive(spiMutex);

                // Wait for RSSI to settle
                delayMicroseconds(SDR_RSSI_SETTLE_US);

                // Read RSSI (thread-safe via SPI semaphore inside getRssi)
                if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(50))) {
                    int rssi = moduleCC1101State[sdrModule_].getRssi();
                    rssiBuffer[bufferIdx++] = (int8_t)constrain(rssi, -128, 0);
                    xSemaphoreGive(spiMutex);
                } else {
                    rssiBuffer[bufferIdx++] = -128;
                }
            } else {
                rssiBuffer[bufferIdx++] = -128;
            }
        }

        pointsScanned++;

        // Send chunk when buffer full or last point
        if (bufferIdx >= chunkSize || i == totalPoints - 1) {
            uint32_t startKhz = (uint32_t)(chunkStartFreqMHz * 1000.0f);
            uint16_t stepKhz = (uint16_t)(config.stepMHz * 1000.0f);
            sendSpectrumChunk(rssiBuffer, bufferIdx, startKhz, stepKhz,
                              chunkIndex, totalChunks);

            chunkIndex++;
            chunkStartFreqMHz = config.startFreqMHz + (i + 1) * config.stepMHz;
            bufferIdx = 0;
        }

        // Yield to prevent WDT (spectrum scan can be slow)
        if (i % 20 == 0) {
            taskYIELD();
        }
    }

    // Return to idle after scan
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].setSidle();
        xSemaphoreGive(spiMutex);
    }

    subMode_ = SdrSubMode::Idle;
    ESP_LOGI(TAG, "Spectrum scan complete: %d points", pointsScanned);
    return pointsScanned;
}

// ── Raw RX streaming ────────────────────────────────────────────────

bool SdrModule::startRawRx() {
    if (!active_) {
        ESP_LOGW(TAG, "Cannot start RX: SDR mode not active");
        return false;
    }

    if (streaming_) {
        ESP_LOGW(TAG, "Raw RX already streaming");
        return true;
    }

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        // Configure CC1101 for RX at current frequency
        moduleCC1101State[sdrModule_].setReceiveConfig(
            currentFreqMHz_, true, currentModulation_,
            currentBandwidthKHz_, 1.58f, currentDataRate_);
        moduleCC1101State[sdrModule_].initConfig();

        // Enter RX mode
        cc1101.setModul(sdrModule_);
        cc1101.SetRx(currentFreqMHz_);

        xSemaphoreGive(spiMutex);
    } else {
        ESP_LOGE(TAG, "Failed to acquire SPI mutex for startRawRx");
        return false;
    }

    streaming_ = true;
    streamSeqNum_ = 0;
    totalBytesStreamed_ = 0;
    subMode_ = SdrSubMode::RawRx;

    ESP_LOGI(TAG, "Raw RX started at %.3f MHz, mod=%d, bw=%.0f kHz",
             currentFreqMHz_, currentModulation_, currentBandwidthKHz_);
    return true;
}

void SdrModule::stopRawRx() {
    if (!streaming_) return;

    streaming_ = false;
    subMode_ = SdrSubMode::Idle;

    // Put CC1101 back to idle
    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(100))) {
        moduleCC1101State[sdrModule_].setSidle();
        xSemaphoreGive(spiMutex);
    }

    ESP_LOGI(TAG, "Raw RX stopped. Total bytes streamed: %u", totalBytesStreamed_);
}

void SdrModule::pollRawRx() {
    if (!streaming_) return;

    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    if (!xSemaphoreTake(spiMutex, pdMS_TO_TICKS(10))) {
        return;  // Don't block if SPI is busy
    }

    // Check how many bytes are in the RX FIFO
    cc1101.setModul(sdrModule_);
    byte rxBytes = cc1101.SpiReadStatus(CC1101_RXBYTES) & 0x7F;

    if (rxBytes > 0) {
        // Read up to 64 bytes from FIFO (CC1101 FIFO is 64 bytes)
        uint8_t buffer[64];
        uint8_t toRead = (rxBytes > 64) ? 64 : rxBytes;

        // Read data from RX FIFO
        cc1101.SpiReadBurstReg(CC1101_RXFIFO + 0xC0, buffer, toRead);

        xSemaphoreGive(spiMutex);

        // Send via serial (binary: raw bytes)
        Serial.write(buffer, toRead);

        // Also send via BLE if clients connected
        sendRawDataChunk(buffer, toRead);

        streamSeqNum_++;
        totalBytesStreamed_ += toRead;
    } else {
        xSemaphoreGive(spiMutex);
    }

    // Check for FIFO overflow and flush if needed
    if (rxBytes & 0x80) {
        if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(10))) {
            cc1101.SpiStrobe(CC1101_SFRX);  // Flush RX FIFO
            cc1101.SetRx(currentFreqMHz_);   // Re-enter RX
            xSemaphoreGive(spiMutex);
            ESP_LOGW(TAG, "RX FIFO overflow — flushed");
        }
    }
}

// ── Serial SDR command interface (HackRF-compatible) ────────────────

bool SdrModule::processSerialCommand(const String& command) {
    String cmd = command;
    cmd.trim();

    // ── Bootstrap commands (work even when SDR is NOT active) ──────

    // sdr_enable — enable SDR mode via serial (no app/BLE needed)
    if (cmd.equalsIgnoreCase("sdr_enable")) {
        if (active_) {
            Serial.println("HACKRF_SUCCESS");
            Serial.println("SDR mode already active");
        } else {
            if (enable()) {
                Serial.println("HACKRF_SUCCESS");
                Serial.println("SDR mode enabled via serial");
            } else {
                Serial.println("HACKRF_ERROR");
                Serial.println("Failed to enable SDR mode (CC1101 may be busy)");
            }
        }
        return true;
    }

    // sdr_disable — disable SDR mode via serial
    if (cmd.equalsIgnoreCase("sdr_disable")) {
        if (disable()) {
            Serial.println("HACKRF_SUCCESS");
            Serial.println("SDR mode disabled");
        } else {
            Serial.println("HACKRF_ERROR");
        }
        return true;
    }

    // sdr_info — show CC1101 SDR parameter limits (always available)
    if (cmd.equalsIgnoreCase("sdr_info")) {
        Serial.println("HACKRF_SUCCESS");
        Serial.println("=== EvilCrow RF v2 SDR — CC1101 Parameter Limits ===");
        Serial.println("Frequency bands:");
        Serial.println("  Band 1: 300.000 - 348.000 MHz");
        Serial.println("  Band 2: 387.000 - 464.000 MHz");
        Serial.println("  Band 3: 779.000 - 928.000 MHz");
        Serial.println("Modulation: 0=2FSK, 1=GFSK, 2=ASK/OOK, 3=4FSK, 4=MSK");
        Serial.println("Bandwidth (kHz): 58 68 81 102 116 135 162 203 232 270 325 406 464 541 650 812");
        Serial.println("Data rate: 0.6 - 500.0 kBaud (600 - 500000 Baud)");
        Serial.println("Gain: AGC controlled (not user-adjustable)");
        Serial.println("FIFO: 64 bytes RX / 64 bytes TX");
        Serial.printf("SDR Active: %s\n", active_ ? "YES" : "NO");
        Serial.printf("Current: %.3f MHz, mod=%d, bw=%.0f kHz, rate=%.2f kBaud\n",
                       currentFreqMHz_, currentModulation_,
                       currentBandwidthKHz_, currentDataRate_);
        return true;
    }

    // board_id_read — identify as EvilCrow SDR (works always)
    if (cmd.equalsIgnoreCase("board_id_read")) {
        Serial.println("HACKRF_SUCCESS");
        Serial.println("Board ID: EvilCrow_RF_v2_SDR");
        Serial.printf("Frequency: %.3f MHz\n", currentFreqMHz_);
        Serial.printf("Module: %d\n", sdrModule_);
        Serial.printf("SDR Active: %s\n", active_ ? "YES" : "NO");
        return true;
    }

    // set_freq <Hz> — set center frequency
    if (cmd.startsWith("set_freq ")) {
        uint64_t freqHz = strtoull(cmd.substring(9).c_str(), nullptr, 10);
        float freqMHz = freqHz / 1000000.0f;
        if (setFrequency(freqMHz)) {
            Serial.println("HACKRF_SUCCESS");
            Serial.printf("Frequency: %.3f MHz\n", currentFreqMHz_);
        } else {
            Serial.println("HACKRF_ERROR");
            Serial.println("Invalid frequency (CC1101 range: 300-348, 387-464, 779-928 MHz)");
        }
        return true;
    }

    // set_sample_rate <Hz> — maps to CC1101 data rate
    if (cmd.startsWith("set_sample_rate ")) {
        uint32_t rate = cmd.substring(16).toInt();
        // CC1101 data rate range: 0.6–500 kBaud
        float kBaud = rate / 1000.0f;
        if (kBaud >= 0.6f && kBaud <= 500.0f) {
            setDataRate(kBaud);
            Serial.println("HACKRF_SUCCESS");
            Serial.printf("Data rate: %.2f kBaud\n", kBaud);
        } else {
            Serial.println("HACKRF_ERROR");
            Serial.println("Rate out of range (600 - 500000 Baud)");
        }
        return true;
    }

    // set_gain <dB> — maps to CC1101 LNA setting (limited)
    if (cmd.startsWith("set_gain ")) {
        int gain = cmd.substring(9).toInt();
        // CC1101 gain is controlled via AGC, not directly settable as dB
        // We acknowledge the command for compatibility but log a note
        ESP_LOGI(TAG, "Gain set request: %d dB (CC1101 uses AGC, limited control)", gain);
        Serial.println("HACKRF_SUCCESS");
        Serial.printf("Gain: %d dB (CC1101 AGC mode)\n", gain);
        return true;
    }

    // set_bandwidth <kHz> — set RX bandwidth
    if (cmd.startsWith("set_bandwidth ")) {
        float bw = cmd.substring(14).toFloat();
        if (setBandwidth(bw)) {
            Serial.println("HACKRF_SUCCESS");
            Serial.printf("Bandwidth: %.1f kHz\n", bw);
        } else {
            Serial.println("HACKRF_ERROR");
        }
        return true;
    }

    // set_modulation <type> — 0=2FSK, 2=ASK/OOK
    if (cmd.startsWith("set_modulation ")) {
        int mod = cmd.substring(15).toInt();
        if (setModulation(mod)) {
            Serial.println("HACKRF_SUCCESS");
            Serial.printf("Modulation: %d\n", mod);
        } else {
            Serial.println("HACKRF_ERROR");
        }
        return true;
    }

    // rx_start — start raw RX streaming via serial
    if (cmd.equalsIgnoreCase("rx_start")) {
        if (startRawRx()) {
            Serial.println("HACKRF_SUCCESS");
            Serial.println("RX streaming started");
        } else {
            Serial.println("HACKRF_ERROR");
        }
        return true;
    }

    // rx_stop — stop raw RX streaming
    if (cmd.equalsIgnoreCase("rx_stop")) {
        stopRawRx();
        Serial.println("HACKRF_SUCCESS");
        Serial.println("RX streaming stopped");
        return true;
    }

    // spectrum_scan [start_mhz] [end_mhz] [step_khz]
    if (cmd.startsWith("spectrum_scan")) {
        SpectrumScanConfig scanCfg;
        // Parse optional parameters
        int firstSpace = cmd.indexOf(' ');
        if (firstSpace > 0) {
            String params = cmd.substring(firstSpace + 1);
            int p1 = params.indexOf(' ');
            if (p1 > 0) {
                scanCfg.startFreqMHz = params.substring(0, p1).toFloat();
                int p2 = params.indexOf(' ', p1 + 1);
                if (p2 > 0) {
                    scanCfg.endFreqMHz = params.substring(p1 + 1, p2).toFloat();
                    scanCfg.stepMHz = params.substring(p2 + 1).toFloat() / 1000.0f;
                } else {
                    scanCfg.endFreqMHz = params.substring(p1 + 1).toFloat();
                }
            } else {
                scanCfg.startFreqMHz = params.toFloat();
            }
        }
        Serial.println("HACKRF_SUCCESS");
        Serial.printf("Scanning %.2f - %.2f MHz (step %.3f MHz)...\n",
                       scanCfg.startFreqMHz, scanCfg.endFreqMHz, scanCfg.stepMHz);
        int points = spectrumScan(scanCfg);
        Serial.printf("Scan complete: %d points\n", points);
        return true;
    }

    // sdr_status — get current status
    if (cmd.equalsIgnoreCase("sdr_status")) {
        Serial.println("HACKRF_SUCCESS");
        Serial.printf("Active: %s\n", active_ ? "YES" : "NO");
        Serial.printf("Mode: %d\n", (int)subMode_);
        Serial.printf("Frequency: %.3f MHz\n", currentFreqMHz_);
        Serial.printf("Modulation: %d\n", currentModulation_);
        Serial.printf("Bandwidth: %.1f kHz\n", currentBandwidthKHz_);
        Serial.printf("Streaming: %s\n", streaming_ ? "YES" : "NO");
        Serial.printf("Bytes streamed: %u\n", totalBytesStreamed_);
        return true;
    }

    // help — list available commands
    if (cmd.equalsIgnoreCase("help") || cmd.equalsIgnoreCase("?")) {
        Serial.println("EvilCrow RF v2 SDR Commands:");
        Serial.println("  sdr_enable                 — Enable SDR mode (no app needed)");
        Serial.println("  sdr_disable                — Disable SDR mode");
        Serial.println("  sdr_info                   — Show CC1101 parameter limits");
        Serial.println("  board_id_read              — Device info");
        Serial.println("  set_freq <Hz>              — Set frequency");
        Serial.println("  set_sample_rate <Hz>       — Set data rate");
        Serial.println("  set_gain <dB>              — Set gain (AGC)");
        Serial.println("  set_bandwidth <kHz>        — Set RX bandwidth");
        Serial.println("  set_modulation <type>      — 0=2FSK, 2=ASK/OOK");
        Serial.println("  rx_start                   — Start RX streaming");
        Serial.println("  rx_stop                    — Stop RX streaming");
        Serial.println("  spectrum_scan [s] [e] [st]  — Scan spectrum (MHz)");
        Serial.println("  sdr_status                 — Show status");
        Serial.println("  help                       — This help");
        return true;
    }

    return false;  // Command not recognized
}

// ── BLE notification helpers ────────────────────────────────────────

void SdrModule::sendStatus() {
    BinarySdrStatus msg;
    msg.active     = active_ ? 1 : 0;
    msg.module     = (uint8_t)sdrModule_;
    msg.freq_khz   = (uint32_t)(currentFreqMHz_ * 1000.0f);
    msg.modulation = (uint8_t)currentModulation_;

    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::SdrEvent,
        reinterpret_cast<const uint8_t*>(&msg),
        sizeof(msg));
}

void SdrModule::sendSpectrumChunk(const int8_t* rssiValues, uint8_t count,
                                  uint32_t startFreqKhz, uint16_t stepKhz,
                                  uint8_t chunkIndex, uint8_t totalChunks) {
    // Build packet: header + RSSI data
    uint8_t packet[sizeof(BinarySdrSpectrumHeader) + 60];

    BinarySdrSpectrumHeader* hdr = reinterpret_cast<BinarySdrSpectrumHeader*>(packet);
    hdr->messageType     = MSG_SDR_SPECTRUM_DATA;
    hdr->chunkIndex      = chunkIndex;
    hdr->totalChunks     = totalChunks;
    hdr->pointsInChunk   = count;
    hdr->startFreq_khz   = startFreqKhz;
    hdr->stepSize_khz    = stepKhz;

    // Copy RSSI values after header
    memcpy(packet + sizeof(BinarySdrSpectrumHeader), rssiValues, count);

    size_t totalLen = sizeof(BinarySdrSpectrumHeader) + count;

    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::SdrEvent,
        packet, totalLen);
}

void SdrModule::sendRawDataChunk(const uint8_t* data, uint8_t len) {
    uint8_t packet[sizeof(BinarySdrRawDataHeader) + 64];

    BinarySdrRawDataHeader* hdr = reinterpret_cast<BinarySdrRawDataHeader*>(packet);
    hdr->messageType = MSG_SDR_RAW_DATA;
    hdr->seqNum      = (uint16_t)(streamSeqNum_ & 0xFFFF);
    hdr->dataLen     = len;

    memcpy(packet + sizeof(BinarySdrRawDataHeader), data, len);

    size_t totalLen = sizeof(BinarySdrRawDataHeader) + len;

    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::SdrEvent,
        packet, totalLen);
}

#endif // SDR_MODULE_ENABLED
