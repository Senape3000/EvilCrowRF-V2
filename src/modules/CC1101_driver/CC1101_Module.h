#ifndef ModuleCc1101State_h
#define ModuleCc1101State_h

typedef unsigned char byte;

#include <Arduino.h>

#include "CC1101_Radio.h"
#include "config.h"
#include <algorithm>  // For std::copy
#include <array>      // For std::array
#include "esp_log.h"
// #include "Cc1101Mode.h" // REMOVED - no longer needed with worker architecture

// CC1101 Settings
#define MODULE_1 0
#define MODULE_2 1

// Modulation types
#define MODULATION_2_FSK 0
#define MODULATION_ASK_OOK 2

// Available modes
#define MODE_TRANSMIT 1
#define MODE_RECEIVE 0

typedef struct
{
  float deviation = 1.58;
  float frequency = 433.92;
  int modulation = 2;  // ASK/OOK
  bool dcFilterOff = true;
  float rxBandwidth = 650.0;
  float dataRate = 3.79372;
  bool transmitMode = false;
  bool initialized = false;
} CC1101ModuleConfig;

class ModuleCc1101
{
private:
  CC1101ModuleConfig config;
  CC1101ModuleConfig tmpConfig;
  byte id;
  byte inputPin;
  byte outputPin;
  SemaphoreHandle_t stateChangeSemaphore;
  static SemaphoreHandle_t rwSemaphore;

public:
  /// Thread-safe access to the shared SPI mutex.
  /// All code that touches the CC1101 SPI bus (including the bruter)
  /// MUST take/give this semaphore around every transaction.
  static SemaphoreHandle_t getSpiSemaphore() { return rwSemaphore; }

private:
  // OperationMode removed - no longer used with worker architecture

public:
  /*
   * SPI (Serial Peripheral Interface) pins
   * sck - Serial Clock
   * miso - Master In Slave Out
   * mosi - Master Out Slave In
   * ss - Slave Select
   * ip - Input pin
   * op - Output pin
   * module - select cc1101 module 0 or 1
   */
  ModuleCc1101(byte sck, byte miso, byte mosi, byte ss, byte io, byte op, byte module);

  ModuleCc1101 backupConfig();
  ModuleCc1101 restoreConfig();
  ModuleCc1101 setConfig(int mode, float frequency, bool dcFilterOff, int modulation, float rxBandwidth, float deviation, float dataRate);
  ModuleCc1101 setConfig(CC1101ModuleConfig config);
  ModuleCc1101 setReceiveConfig(float frequency, bool dcFilterOff, int modulation, float rxBandwidth, float deviation, float dataRate);
  ModuleCc1101 changeFrequency(float frequency);
  ModuleCc1101 setTransmitConfig(float frequency, int modulation, float deviation);
  ModuleCc1101 initConfig();
  void applySubConfiguration(const uint8_t *byteArray, int length);
  void setTx(float frequency);
  void setTxWithPreset(float frequency, const uint8_t *presetBytes, int presetLength);
  void sendData(byte *txBuffer, byte size);
  void sendDataNonBlocking(byte *txBuffer, byte size, int delayMs);  // Non-blocking version for jamming
    // setMode/getMode removed - no longer used with worker architecture
    // void setMode(OperationMode m) { mode = m; }
    // OperationMode getMode() const { return mode; }

  CC1101ModuleConfig getCurrentConfig();
  int getModulation();
  byte getId();
  void init();
  void reset();
  byte getInputPin();
  byte getOutputPin();
  int getRssi();
  byte getLqi();
  void setSidle();
  void goSleep();
  SemaphoreHandle_t getStateChangeSemaphore();
  void unlock();
  byte getRegisterValue(byte address);
  std::array<byte,8> getPATableValues();
  void readAllConfigRegisters(byte *buffer, byte num);
  float getFrequency();
  void setPA(int power);  // Set power in dBm (-30 to 10)
  void calibrate();  // Perform calibration (uses current frequency and updates modulation from register)
  bool waitForCalibration(uint32_t timeoutMs = 100);  // Wait for calibration to complete
  void enableContinuousTx();  // Enable continuous transmission mode for jamming
  void writeToTxFifo(byte *data, byte size);  // Write data directly to TX FIFO
};

extern ModuleCc1101 moduleCC1101State[];

#endif