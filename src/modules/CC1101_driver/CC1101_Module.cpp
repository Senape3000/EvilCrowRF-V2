#include "CC1101_Module.h"

SemaphoreHandle_t ModuleCc1101::rwSemaphore = xSemaphoreCreateMutex();

static const char* TAG = "Cc1101Config";

ModuleCc1101 moduleCC1101State[] = {ModuleCc1101(CC1101_SCK, CC1101_MISO, CC1101_MOSI, CC1101_SS0, MOD0_GDO2, MOD0_GDO0, MODULE_1),
                                    ModuleCc1101(CC1101_SCK, CC1101_MISO, CC1101_MOSI, CC1101_SS1, MOD1_GDO2, MOD1_GDO0, MODULE_2)};

ModuleCc1101::ModuleCc1101(byte sck, byte miso, byte mosi, byte ss, byte ip, byte op, byte module)
{
    stateChangeSemaphore = xSemaphoreCreateBinary();
    cc1101.addSpiPin(sck, miso, mosi, ss, module);
    cc1101.addGDO(op, ip, module);
    inputPin = ip;
    outputPin = op;
    id = module;
}

SemaphoreHandle_t ModuleCc1101::getStateChangeSemaphore()
{
    return stateChangeSemaphore;
}

void ModuleCc1101::unlock()
{
    xSemaphoreGive(stateChangeSemaphore);
}

ModuleCc1101 ModuleCc1101::backupConfig()
{
    tmpConfig = config;
    return *this;
}

ModuleCc1101 ModuleCc1101::restoreConfig()
{
    config = tmpConfig;
    return *this;
}

ModuleCc1101 ModuleCc1101::setConfig(int mode, float frequency, bool dcFilterOff, int modulation, float rxBandwidth, float deviation, float dataRate)
{
    config.transmitMode = mode == MODE_TRANSMIT;
    config.frequency = frequency;
    config.deviation = deviation;
    config.modulation = modulation;
    config.dcFilterOff = dcFilterOff;
    config.rxBandwidth = rxBandwidth;
    config.dataRate = dataRate;

    return *this;
}

ModuleCc1101 ModuleCc1101::setConfig(CC1101ModuleConfig config)
{
    this->config = config;
    return *this;
}

ModuleCc1101 ModuleCc1101::setReceiveConfig(float frequency, bool dcFilterOff, int modulation, float rxBandwidth, float deviation, float dataRate)
{
    // Always update config to ensure it's applied, even if values are the same
    // This is important for recording to ensure CC1101 is properly configured
    config.transmitMode = false;
    config.frequency = frequency;
    config.deviation = deviation;
    config.modulation = modulation;
    config.dcFilterOff = dcFilterOff;
    config.rxBandwidth = rxBandwidth;
    config.dataRate = dataRate;
    
    ESP_LOGD(TAG, "Config set: freq=%.2f, mod=%d, dev=%.2f, bw=%.2f, rate=%.2f", 
             frequency, modulation, deviation, rxBandwidth, dataRate);
    
    return *this;
}

ModuleCc1101 ModuleCc1101::changeFrequency(float frequency)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    config.frequency = frequency;
    cc1101.setModul(id);
    cc1101.setSidle();
    cc1101.setMHZ(frequency);
    cc1101.SetRx();
    cc1101.setDRate(config.dataRate);
    cc1101.setRxBW(config.rxBandwidth);
    xSemaphoreGive(rwSemaphore);
    return *this;
}

ModuleCc1101 ModuleCc1101::setTransmitConfig(float frequency, int modulation, float deviation)
{
    config.transmitMode = true;
    config.frequency = frequency;
    config.deviation = deviation;
    config.modulation = modulation;
    return *this;
}

CC1101ModuleConfig ModuleCc1101::getCurrentConfig()
{
    return config;
}

byte ModuleCc1101::getId()
{
    return id;
}

int ModuleCc1101::getModulation()
{
    return config.modulation;
}

void ModuleCc1101::init()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.Init();
    xSemaphoreGive(rwSemaphore);
}

ModuleCc1101 ModuleCc1101::initConfig()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    
    // Force CC1101 to idle before reconfiguring
    cc1101.setSidle();
    delay(10);  // Give CC1101 time to enter idle state
    
    cc1101.setModulation(config.modulation);  // set modulation mode. 0 = 2-FSK, 1 = GFSK, 2 = ASK/OOK, 3 = 4-FSK, 4 = MSK.
    cc1101.setDeviation(config.deviation);  // Set the Frequency deviation in kHz. Value from 1.58 to 380.85. Default is 47.60 kHz.
    cc1101.setMHZ(config.frequency);

    if (config.transmitMode) {
        cc1101.SetTx();
    } else {
        cc1101.setDcFilterOff(config.dcFilterOff);
        cc1101.setSyncMode(0);  // Combined sync-word qualifier mode. 0 = No preamble/sync. 1 = 16 sync word bits detected. 2 = 16/16 sync word bits detected. 3 =
                                // 30/32 sync word bits detected. 4 = No preamble/sync, carrier-sense above threshold. 5 = 15/16 + carrier-sense above threshold. 6
                                // = 16/16 + carrier-sense above threshold. 7 = 30/32 + carrier-sense above threshold.
        cc1101.setPktFormat(3);  // Format of RX and TX data. 0 = Normal mode, use FIFOs for RX and TX. 1 = Synchronous serial mode, Data in on GDO0 and data out on
                                 // either of the GDOx pins. 2 = Random TX mode; sends random data using PN9 generator. Used for t. Works as normal mode, setting 0
                                 // (00), in RX. 3 = Asynchronous serial mode, Data in on GDO0 and data out on either of the GDOx pins.
        cc1101.setDRate(config.dataRate);
        cc1101.setRxBW(config.rxBandwidth);
        
        // Force transition to RX mode
        cc1101.SetRx();
        delay(10);  // Give CC1101 time to enter RX state
        
        ESP_LOGI(TAG, "CC1101 module %d configured for RX: freq=%.2f, mod=%d, dev=%.2f", 
                 id, config.frequency, config.modulation, config.deviation);
    }
    xSemaphoreGive(rwSemaphore);

    return *this;
}

void ModuleCc1101::setTx(float frequency)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSidle();
    cc1101.Init();
    cc1101.setMHZ(frequency);
    cc1101.SetTx();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::setTxWithPreset(float frequency, const uint8_t *presetBytes, int presetLength)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSidle();
    delay(10);
    cc1101.Init();  // Reset all registers to defaults
    delay(10);
    
    // Set frequency first (before applying preset)
    cc1101.setMHZ(frequency);  // This will also call Calibrate()
    delay(10);
    
    // Apply preset configuration - presets now contain correct values
    if (presetBytes != nullptr && presetLength > 0) {
        int index = 0;
        
        // Apply all registers from preset
        while (index < presetLength) {
            uint8_t addr = presetBytes[index++];
            uint8_t value = presetBytes[index++];
            
            if (addr == 0x00 && value == 0x00) {
                break;
            }
            
            // Write each register - preset values are correct now
            cc1101.SpiWriteReg(addr, value);
        }
        
        // Apply PA table (last 8 bytes)
        std::array<uint8_t, 8> paValue;
        std::copy(presetBytes + index, presetBytes + index + paValue.size(), paValue.begin());
        cc1101.SpiWriteBurstReg(CC1101_PATABLE, paValue.data(), paValue.size());
    }
    
    delay(10);
    cc1101.SetTx();  // Enter TX mode
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::applySubConfiguration(const uint8_t *byteArray, int length)
{
    int index = 0;

    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    while (index < length) {
        uint8_t addr = byteArray[index++];
        uint8_t value = byteArray[index++];

        if (addr == 0x00 && value == 0x00) {
            break;
        }
        cc1101.SpiWriteReg(addr, value);
    }

    std::array<uint8_t, 8> paValue;
    std::copy(byteArray + index, byteArray + index + paValue.size(), paValue.begin());
    cc1101.SpiWriteBurstReg(CC1101_PATABLE, paValue.data(), paValue.size());
    xSemaphoreGive(rwSemaphore);
}

byte ModuleCc1101::getInputPin()
{
    return inputPin;
}

byte ModuleCc1101::getOutputPin()
{
    return outputPin;
}

int ModuleCc1101::getRssi()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    int rssi = cc1101.getRssi();
    xSemaphoreGive(rwSemaphore);
    return rssi;
    }

byte ModuleCc1101::getLqi()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    byte lqi = cc1101.getLqi();
    xSemaphoreGive(rwSemaphore);
    return lqi;
}

void ModuleCc1101::setSidle()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSidle();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::reset()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setSres();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::goSleep()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.goSleep();
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::sendData(byte *txBuffer, byte size)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.SendData(txBuffer, size);
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::sendDataNonBlocking(byte *txBuffer, byte size, int delayMs)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    // Use SendData version with a delay instead of waiting for GDO0
    // This does not block execution of other tasks
    cc1101.SendData(txBuffer, size, delayMs);
    xSemaphoreGive(rwSemaphore);
}

byte ModuleCc1101::getRegisterValue(byte address)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    byte value = cc1101.SpiReadReg(address);
    xSemaphoreGive(rwSemaphore);
    return value;
}

std::array<byte,8> ModuleCc1101::getPATableValues()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    std::array<byte,8> paTable;
    cc1101.setModul(id);
    cc1101.SpiReadBurstReg(0x3E, paTable.data(), paTable.size());
    xSemaphoreGive(rwSemaphore);
    return paTable;
}

void ModuleCc1101::readAllConfigRegisters(byte *buffer, byte num)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.selectModule(id);
    cc1101.SpiReadBurstReg(0x00, buffer, num); // 0x00 is the start address for configuration registers
    xSemaphoreGive(rwSemaphore);
}

float ModuleCc1101::getFrequency()
{
    float fq;
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    fq = cc1101.getFrequency(); // 0x00 is the start address for configuration registers
    xSemaphoreGive(rwSemaphore);
    return fq;
}

void ModuleCc1101::setPA(int power)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.setPA(power);
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::calibrate()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    cc1101.calibrate();
    xSemaphoreGive(rwSemaphore);
}

bool ModuleCc1101::waitForCalibration(uint32_t timeoutMs)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    bool result = cc1101.waitForCalibration(timeoutMs);
    xSemaphoreGive(rwSemaphore);
    return result;
}

void ModuleCc1101::enableContinuousTx()
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    // Set PKTLEN to 0 for infinite packet length (continuous transmission)
    cc1101.SpiWriteReg(CC1101_PKTLEN, 0x00);
    // Ensure packet format is set correctly for continuous mode
    // PKTCTRL0: bit 1-0 = 00 (fixed packet length), but with PKTLEN=0 it becomes infinite
    xSemaphoreGive(rwSemaphore);
}

void ModuleCc1101::writeToTxFifo(byte *data, byte size)
{
    xSemaphoreTake(rwSemaphore, portMAX_DELAY);
    cc1101.setModul(id);
    // Write data directly to TX FIFO (burst write)
    cc1101.SpiWriteBurstReg(CC1101_TXFIFO, data, size);
    xSemaphoreGive(rwSemaphore);
}