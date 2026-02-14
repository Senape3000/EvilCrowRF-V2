
/*
  Based on ELECHOUSE_CC1101.cpp - CC1101 module library
*/
#include "SPI.h"
#include "CC1101_Radio.h"
#include <Arduino.h>
#include "driver/gpio.h"

// Helper: wait for MISO to go LOW with timeout (CC1101 ready signal)
// Uses gpio_get_level() instead of digitalRead() to avoid ESP32
// warning when pin is configured for SPI peripheral function.
static inline bool waitMisoLow(byte pin, uint32_t timeoutUs = 1000) {
    uint32_t start = micros();
    while (gpio_get_level((gpio_num_t)pin)) {
        if ((micros() - start) >= timeoutUs) {
            return false;  // Timeout - CC1101 not responding
        }
    }
    return true;
}

/****************************************************************/
#define   WRITE_BURST       0x40            //write burst
#define   READ_SINGLE       0x80            //read single
#define   READ_BURST        0xC0            //read burst
#define   BYTES_IN_RXFIFO   0x7F            //byte number in RXfifo
#define   max_modul 6

SPIClass CCSPI(HSPI);
byte currentModule = 0;
byte modulation[max_modul] = {2,2,2,2,2,2};
byte deviation[max_modul] = {0,0,0,0,0,0};
byte frend0[max_modul];
byte chan[max_modul] = {0,0,0,0,0,0};
int pa[max_modul] = {12,12,12,12,12,12};
byte last_pa[max_modul];
byte SCK_PIN[max_modul];
byte MISO_PIN[max_modul];
byte MOSI_PIN[max_modul];
byte SS_PIN[max_modul];
byte GDO0[max_modul];
byte GDO2[max_modul];

byte gdo_set[max_modul] = {0,0,0,0,0,0};
bool spi[max_modul] = {0,0,0,0,0,0};
bool ccmode[max_modul] = {0,0,0,0,0,0};
float MHz[max_modul] = {433.92,433.92,433.92,433.92,433.92,433.92};
float bwValue[max_modul];
byte m4RxBw[max_modul] = {0,0,0,0,0,0};
float dataRate[max_modul];
byte m4DaRa[max_modul];
bool dcOffFlag[max_modul];
byte m2DCOFF[max_modul];
byte m2MODFM[max_modul];
byte m2MANCH[max_modul];
bool syncModeFlag[max_modul];
byte m2SYNCM[max_modul];
byte m1FEC[max_modul];
byte m1PRE[max_modul];
byte m1CHSP[max_modul];
byte pc1PQT[max_modul];
byte pc1CRC_AF[max_modul];
byte pc1APP_ST[max_modul];
byte pc1ADRCHK[max_modul];
byte pc0WDATA[max_modul];
byte pc0PktForm[max_modul];
byte pc0CRC_EN[max_modul];
byte pc0LenConf[max_modul];
byte trxstate[max_modul] = {0,0,0,0,0,0};
byte clb1[2]= {24,28};
byte clb2[2]= {31,38};
byte clb3[2]= {65,76};
byte clb4[2]= {77,79};

/****************************************************************/
uint8_t PA_TABLE[8]     {0x00,0xC0,0x00,0x00,0x00,0x00,0x00,0x00};
//                       -30  -20  -15  -10   0    5    7    10
uint8_t PA_TABLE_315[8] {0x12,0x0D,0x1C,0x34,0x51,0x85,0xCB,0xC2,};             //300 - 348
uint8_t PA_TABLE_433[8] {0x12,0x0E,0x1D,0x34,0x60,0x84,0xC8,0xC0,};             //387 - 464
//                        -30  -20  -15  -10  -6    0    5    7    10   12
uint8_t PA_TABLE_868[10] {0x03,0x17,0x1D,0x26,0x37,0x50,0x86,0xCD,0xC5,0xC0,};  //779 - 899.99
//                        -30  -20  -15  -10  -6    0    5    7    10   11
uint8_t PA_TABLE_915[10] {0x03,0x0E,0x1E,0x27,0x38,0x8E,0x84,0xCC,0xC3,0xC0,};  //900 - 928
/****************************************************************
*FUNCTION NAME:SpiStart
*FUNCTION     :spi communication start
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SpiStart(void)
{
  // initialize the SPI pins
  pinMode(SCK_PIN[currentModule], OUTPUT);
  pinMode(MOSI_PIN[currentModule], OUTPUT);
  pinMode(MISO_PIN[currentModule], INPUT);
  pinMode(SS_PIN[currentModule], OUTPUT);

  // enable SPI
  #ifdef ESP32
  CCSPI.begin(SCK_PIN[currentModule], MISO_PIN[currentModule], MOSI_PIN[currentModule], SS_PIN[currentModule]);
  #else
  CCSPI.begin();
  #endif
}
/****************************************************************
*FUNCTION NAME:SpiEnd
*FUNCTION     :spi communication disable
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SpiEnd(void)
{
  // disable SPI
  CCSPI.endTransaction();
  CCSPI.end();
}
/****************************************************************
*FUNCTION NAME: GDO_Set()
*FUNCTION     : set GDO0,GDO2 pin for serial pinmode.
*INPUT        : none
*OUTPUT       : none
****************************************************************/
void CC1101_Radio::GDO_Set (void)
{
	pinMode(GDO0[currentModule], OUTPUT);
	pinMode(GDO2[currentModule], INPUT);
}
/****************************************************************
*FUNCTION NAME: GDO_Set()
*FUNCTION     : set GDO0[currentModule] for internal transmission mode.
*INPUT        : none
*OUTPUT       : none
****************************************************************/
void CC1101_Radio::GDO0_Set (void)
{
  pinMode(GDO0[currentModule], INPUT);
}
/****************************************************************
*FUNCTION NAME:Reset
*FUNCTION     :CC1101 reset //details refer datasheet of CC1101/CC1100//
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Reset (void)
{
  SpiStart(); 
	digitalWrite(SS_PIN[currentModule], LOW);
	delay(1);
	digitalWrite(SS_PIN[currentModule], HIGH);
	delay(1);
	digitalWrite(SS_PIN[currentModule], LOW);
	waitMisoLow(MISO_PIN[currentModule], 5000);  // 5ms timeout for reset
  CCSPI.transfer(CC1101_SRES);
  waitMisoLow(MISO_PIN[currentModule], 5000);  // 5ms timeout for reset
	digitalWrite(SS_PIN[currentModule], HIGH);
  SpiEnd();
}
/****************************************************************
*FUNCTION NAME:Init
*FUNCTION     :CC1101 initialization
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Init(void)
{
  setSpi();
  SpiStart();                   //spi initialization
  digitalWrite(SS_PIN[currentModule], HIGH);
#if !defined(ESP32) && !defined(ARDUINO_ARCH_ESP32)
  digitalWrite(SCK_PIN[currentModule], HIGH);
  digitalWrite(MOSI_PIN[currentModule], LOW);
#endif
  SpiEnd();
  Reset();                    //CC1101 reset
  RegConfigSettings();            //CC1101 register config
}
/****************************************************************
*FUNCTION NAME:SpiWriteReg
*FUNCTION     :CC1101 write data to register
*INPUT        :addr: register address; value: register value
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SpiWriteReg(byte addr, byte value)
{
  SpiStart();
  digitalWrite(SS_PIN[currentModule], LOW);
  waitMisoLow(MISO_PIN[currentModule]);
  CCSPI.transfer(addr);
  CCSPI.transfer(value);
  digitalWrite(SS_PIN[currentModule], HIGH);
  SpiEnd();
}
/****************************************************************
*FUNCTION NAME:SpiWriteBurstReg
*FUNCTION     :CC1101 write burst data to register
*INPUT        :addr: register address; buffer:register value array; num:number to write
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SpiWriteBurstReg(byte addr, byte *buffer, byte num)
{
  SpiStart();
  digitalWrite(SS_PIN[currentModule], LOW);
  waitMisoLow(MISO_PIN[currentModule]);

  CCSPI.beginTransaction(SPISettings());  // Begin SPI transaction with appropriate settings
  CCSPI.transfer(addr | WRITE_BURST);                                 // Write the address with burst bit set

  for (byte i = 0; i < num; i++) {
    CCSPI.transfer(buffer[i]);  // Transfer data bytes
  }

  digitalWrite(SS_PIN[currentModule], HIGH);  // Set SS high to end communication
  CCSPI.endTransaction();      // End SPI transaction
  SpiEnd();
}
/****************************************************************
*FUNCTION NAME:SpiStrobe
*FUNCTION     :CC1101 Strobe
*INPUT        :strobe: command; //refer define in CC1101.h//
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SpiStrobe(byte strobe)
{
  SpiStart();
  digitalWrite(SS_PIN[currentModule], LOW);
  waitMisoLow(MISO_PIN[currentModule]);

  CCSPI.beginTransaction(SPISettings());
  CCSPI.transfer(strobe);
  CCSPI.endTransaction();

  digitalWrite(SS_PIN[currentModule], HIGH);
  SpiEnd();
}
/****************************************************************
*FUNCTION NAME:SpiReadReg
*FUNCTION     :CC1101 read data from register
*INPUT        :addr: register address
*OUTPUT       :register value
****************************************************************/
byte CC1101_Radio::SpiReadReg(byte addr) 
{
  SpiStart();
  digitalWrite(SS_PIN[currentModule], LOW);
  waitMisoLow(MISO_PIN[currentModule]);

  CCSPI.beginTransaction(SPISettings());
  CCSPI.transfer(addr | READ_SINGLE);
  byte value = CCSPI.transfer(0);
  CCSPI.endTransaction();

  digitalWrite(SS_PIN[currentModule], HIGH);
  SpiEnd();
  return value;

}

/****************************************************************
*FUNCTION NAME:SpiReadBurstReg
*FUNCTION     :CC1101 read burst data from register
*INPUT        :addr: register address; buffer:array to store register value; num: number to read
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SpiReadBurstReg(byte addr, byte *buffer, byte num)
{
  SpiStart();
  digitalWrite(SS_PIN[currentModule], LOW);
  waitMisoLow(MISO_PIN[currentModule]);

  CCSPI.beginTransaction(SPISettings());
  CCSPI.transfer(addr | READ_BURST);
  for (byte i = 0; i < num; i++) {
    buffer[i] = CCSPI.transfer(0);
  }
  CCSPI.endTransaction();

  digitalWrite(SS_PIN[currentModule], HIGH);
  SpiEnd();
}

/****************************************************************
*FUNCTION NAME:SpiReadStatus
*FUNCTION     :CC1101 read status register
*INPUT        :addr: register address
*OUTPUT       :status value
****************************************************************/
byte CC1101_Radio::SpiReadStatus(byte addr) 
{
  SpiStart();
  digitalWrite(SS_PIN[currentModule], LOW);
  waitMisoLow(MISO_PIN[currentModule]);

  CCSPI.beginTransaction(SPISettings());
  CCSPI.transfer(addr | READ_BURST);
  byte value = CCSPI.transfer(0);
  CCSPI.endTransaction();

  digitalWrite(SS_PIN[currentModule], HIGH);
  SpiEnd();
  return value;
}
/****************************************************************
*FUNCTION NAME:SPI pin Settings
*FUNCTION     :Set Spi pins
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setSpi(void){
  if (spi[currentModule] == 0){
  #if defined __AVR_ATmega168__ || defined __AVR_ATmega328P__
  SCK_PIN[currentModule] = 13; MISO_PIN[currentModule] = 12; MOSI_PIN[currentModule] = 11; SS_PIN[currentModule] = 10;
  #elif defined __AVR_ATmega1280__ || defined __AVR_ATmega2560__
  SCK_PIN[currentModule] = 52; MISO_PIN[currentModule] = 50; MOSI_PIN[currentModule] = 51; SS_PIN[currentModule] = 53;
  #elif ESP8266
  SCK_PIN[currentModule] = 14; MISO_PIN[currentModule] = 12; MOSI_PIN[currentModule] = 13; SS_PIN[currentModule] = 15;
  #elif ESP32
  SCK_PIN[currentModule] = 18; MISO_PIN[currentModule] = 19; MOSI_PIN[currentModule] = 23; SS_PIN[currentModule] = 5;
  #else
  SCK_PIN[currentModule] = 13; MISO_PIN[currentModule] = 12; MOSI_PIN[currentModule] = 11; SS_PIN[currentModule] = 10;
  #endif
}
}
/****************************************************************
*FUNCTION NAME:COSTUM SPI
*FUNCTION     :set costum spi pins.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setSpiPin(byte sck, byte miso, byte mosi, byte ss){
  spi[currentModule] = 1;
  SCK_PIN[currentModule] = sck;
  MISO_PIN[currentModule] = miso;
  MOSI_PIN[currentModule] = mosi;
  SS_PIN[currentModule] = ss;
}
/****************************************************************
*FUNCTION NAME:COSTUM SPI
*FUNCTION     :set costum spi pins.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::addSpiPin(byte sck, byte miso, byte mosi, byte ss, byte modul){
  spi[modul] = 1;
  SCK_PIN[modul] = sck;
  MISO_PIN[modul] = miso;
  MOSI_PIN[modul] = mosi;
  SS_PIN[modul] = ss;
}
/****************************************************************
*FUNCTION NAME:GDO Pin settings
*FUNCTION     :set GDO Pins
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setGDO(byte gdo0, byte gdo2){
GDO0[currentModule] = gdo0;
GDO2[currentModule] = gdo2;  
GDO_Set();
}
/****************************************************************
*FUNCTION NAME:GDO0 Pin setting
*FUNCTION     :set GDO0 Pin
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setGDO0(byte gdo0){
GDO0[currentModule] = gdo0;
GDO0_Set();
}
/****************************************************************
*FUNCTION NAME:GDO Pin settings
*FUNCTION     :add GDO Pins
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::addGDO(byte gdo0, byte gdo2, byte modul){
GDO0[modul] = gdo0;
GDO2[modul] = gdo2;  
gdo_set[modul]=2;
GDO_Set();
}
/****************************************************************
*FUNCTION NAME:add GDO0 Pin
*FUNCTION     :add GDO0 Pin
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::addGDO0(byte gdo0, byte modul){
GDO0[modul] = gdo0;
gdo_set[modul]=1;
GDO0_Set();
}
/****************************************************************
*FUNCTION NAME:set Modul
*FUNCTION     :change modul
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setModul(byte modul){
  // Update currentModule FIRST so GDO_Set/GDO0_Set configure the correct
  // module's pins (they use currentModule internally).
  currentModule = modul;
  if (gdo_set[modul]==1){
  GDO0_Set();
  }
  else if (gdo_set[modul]==2){
  GDO_Set();
  }
}

void CC1101_Radio::selectModule(byte module)
{
  currentModule = module;
}
/****************************************************************
*FUNCTION NAME:CCMode
*FUNCTION     :Format of RX and TX data
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setCCMode(bool s){
ccmode[currentModule] = s;
if (ccmode[currentModule] == 1){
SpiWriteReg(CC1101_IOCFG2,      0x0B);
SpiWriteReg(CC1101_IOCFG0,      0x06);
SpiWriteReg(CC1101_PKTCTRL0,    0x05);
SpiWriteReg(CC1101_MDMCFG3,     0xF8);
SpiWriteReg(CC1101_MDMCFG4,11+m4RxBw[currentModule]);
}else{
SpiWriteReg(CC1101_IOCFG2,      0x0D);
SpiWriteReg(CC1101_IOCFG0,      0x0D);
SpiWriteReg(CC1101_PKTCTRL0,    0x32);
SpiWriteReg(CC1101_MDMCFG3,     0x93);
SpiWriteReg(CC1101_MDMCFG4, 7+m4RxBw[currentModule]);
}
setModulation(modulation[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Modulation
*FUNCTION     :set CC1101 Modulation 
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setModulation(byte m){
  if (m > 4)
    m = 4;

  modulation[currentModule] = m;
  Split_MDMCFG2();

  static const byte modulationModes[] = {0x00, 0x10, 0x30, 0x40, 0x70};
  static const byte frendValues[] = {0x10, 0x10, 0x11, 0x10, 0x10};

  m2MODFM[currentModule] = modulationModes[m];
  frend0[currentModule] = frendValues[m];

  SpiWriteReg(CC1101_MDMCFG2, m2DCOFF[currentModule] + m2MODFM[currentModule] + m2MANCH[currentModule] + m2SYNCM[currentModule]);
  SpiWriteReg(CC1101_FREND0, frend0[currentModule]);
  setPA(pa[currentModule]);
}
/****************************************************************
*FUNCTION NAME:PA Power
*FUNCTION     :set CC1101 PA Power 
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setPA(int p)
{
    int a = 0;  // Default to minimum power if frequency not in any known band
    pa[currentModule] = p;
    float mhz = getFrequency();  // Read actual frequency from registers

if (mhz >= 300 && mhz <= 348){
if (pa[currentModule] <= -30){a = PA_TABLE_315[0];}
else if (pa[currentModule] > -30 && pa[currentModule] <= -20){a = PA_TABLE_315[1];}
else if (pa[currentModule] > -20 && pa[currentModule] <= -15){a = PA_TABLE_315[2];}
else if (pa[currentModule] > -15 && pa[currentModule] <= -10){a = PA_TABLE_315[3];}
else if (pa[currentModule] > -10 && pa[currentModule] <= 0){a = PA_TABLE_315[4];}
else if (pa[currentModule] > 0 && pa[currentModule] <= 5){a = PA_TABLE_315[5];}
else if (pa[currentModule] > 5 && pa[currentModule] <= 7){a = PA_TABLE_315[6];}
else if (pa[currentModule] > 7){a = PA_TABLE_315[7];}
last_pa[currentModule] = 1;
}
else if (mhz >= 378 && mhz <= 464){
if (pa[currentModule] <= -30){a = PA_TABLE_433[0];}
else if (pa[currentModule] > -30 && pa[currentModule] <= -20){a = PA_TABLE_433[1];}
else if (pa[currentModule] > -20 && pa[currentModule] <= -15){a = PA_TABLE_433[2];}
else if (pa[currentModule] > -15 && pa[currentModule] <= -10){a = PA_TABLE_433[3];}
else if (pa[currentModule] > -10 && pa[currentModule] <= 0){a = PA_TABLE_433[4];}
else if (pa[currentModule] > 0 && pa[currentModule] <= 5){a = PA_TABLE_433[5];}
else if (pa[currentModule] > 5 && pa[currentModule] <= 7){a = PA_TABLE_433[6];}
else if (pa[currentModule] > 7){a = PA_TABLE_433[7];}
last_pa[currentModule] = 2;
}
else if (mhz >= 779 && mhz <= 899.99){
if (pa[currentModule] <= -30){a = PA_TABLE_868[0];}
else if (pa[currentModule] > -30 && pa[currentModule] <= -20){a = PA_TABLE_868[1];}
else if (pa[currentModule] > -20 && pa[currentModule] <= -15){a = PA_TABLE_868[2];}
else if (pa[currentModule] > -15 && pa[currentModule] <= -10){a = PA_TABLE_868[3];}
else if (pa[currentModule] > -10 && pa[currentModule] <= -6){a = PA_TABLE_868[4];}
else if (pa[currentModule] > -6 && pa[currentModule] <= 0){a = PA_TABLE_868[5];}
else if (pa[currentModule] > 0 && pa[currentModule] <= 5){a = PA_TABLE_868[6];}
else if (pa[currentModule] > 5 && pa[currentModule] <= 7){a = PA_TABLE_868[7];}
else if (pa[currentModule] > 7 && pa[currentModule] <= 10){a = PA_TABLE_868[8];}
else if (pa[currentModule] > 10){a = PA_TABLE_868[9];}
last_pa[currentModule] = 3;
}
else if (mhz >= 900 && mhz <= 928){
if (pa[currentModule] <= -30){a = PA_TABLE_915[0];}
else if (pa[currentModule] > -30 && pa[currentModule] <= -20){a = PA_TABLE_915[1];}
else if (pa[currentModule] > -20 && pa[currentModule] <= -15){a = PA_TABLE_915[2];}
else if (pa[currentModule] > -15 && pa[currentModule] <= -10){a = PA_TABLE_915[3];}
else if (pa[currentModule] > -10 && pa[currentModule] <= -6){a = PA_TABLE_915[4];}
else if (pa[currentModule] > -6 && pa[currentModule] <= 0){a = PA_TABLE_915[5];}
else if (pa[currentModule] > 0 && pa[currentModule] <= 5){a = PA_TABLE_915[6];}
else if (pa[currentModule] > 5 && pa[currentModule] <= 7){a = PA_TABLE_915[7];}
else if (pa[currentModule] > 7 && pa[currentModule] <= 10){a = PA_TABLE_915[8];}
else if (pa[currentModule] > 10){a = PA_TABLE_915[9];}
last_pa[currentModule] = 4;
}

// Read modulation from MDMCFG2 register instead of using internal variable
// This ensures we always use the actual modulation set in the chip (e.g., from preset)
Split_MDMCFG2();  // Reads MDMCFG2 and extracts m2MODFM[currentModule]

// For ASK/OOK (m2MODFM = 0x30): PA_TABLE[0] = 0, PA_TABLE[1] = value
// For other modulations: PA_TABLE[0] = value, PA_TABLE[1] = 0
if (m2MODFM[currentModule] == 0x30){
PA_TABLE[0] = 0;  
PA_TABLE[1] = a;
}else{
PA_TABLE[0] = a;  
PA_TABLE[1] = 0; 
}
SpiWriteBurstReg(CC1101_PATABLE,PA_TABLE,8);
}
/****************************************************************
*FUNCTION NAME:Frequency Calculator
*FUNCTION     :Calculate the basic frequency.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setMHZ(float mhz){
MHz[currentModule] = mhz;

unsigned long freq = static_cast<unsigned long>((mhz * 65536) / 26.0);
SpiWriteReg(CC1101_FREQ2, (byte)(freq >> 16));
SpiWriteReg(CC1101_FREQ1, (byte)(freq >> 8));
SpiWriteReg(CC1101_FREQ0, (byte)(freq));

Calibrate();
}
/****************************************************************
*FUNCTION NAME:Calibrate
*FUNCTION     :Calibrate frequency
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Calibrate(void){
    float mhz = getFrequency();  // Read actual frequency from registers

if (mhz >= 300 && mhz <= 348){
SpiWriteReg(CC1101_FSCTRL0, (byte)map((long)(mhz * 100), 30000, 34800, clb1[0], clb1[1]));
if (mhz < 322.88){SpiWriteReg(CC1101_TEST0,0x0B);}
else{
SpiWriteReg(CC1101_TEST0,0x09);
int s = this->SpiReadStatus(CC1101_FSCAL2);
if (s<32){SpiWriteReg(CC1101_FSCAL2, s+32);}
if (last_pa[currentModule] != 1){setPA(pa[currentModule]);}
}
}
else if (mhz >= 378 && mhz <= 464){
SpiWriteReg(CC1101_FSCTRL0, (byte)map((long)(mhz * 100), 37800, 46400, clb2[0], clb2[1]));
if (mhz < 430.5){SpiWriteReg(CC1101_TEST0,0x0B);}
else{
SpiWriteReg(CC1101_TEST0,0x09);
int s = this->SpiReadStatus(CC1101_FSCAL2);
if (s<32){SpiWriteReg(CC1101_FSCAL2, s+32);}
if (last_pa[currentModule] != 2){setPA(pa[currentModule]);}
}
}
else if (mhz >= 779 && mhz <= 899.99){
SpiWriteReg(CC1101_FSCTRL0, (byte)map((long)(mhz * 100), 77900, 89900, clb3[0], clb3[1]));
if (mhz < 861){SpiWriteReg(CC1101_TEST0,0x0B);}
else{
SpiWriteReg(CC1101_TEST0,0x09);
int s = this->SpiReadStatus(CC1101_FSCAL2);
if (s<32){SpiWriteReg(CC1101_FSCAL2, s+32);}
if (last_pa[currentModule] != 3){setPA(pa[currentModule]);}
}
}
else if (mhz >= 900 && mhz <= 928){
SpiWriteReg(CC1101_FSCTRL0, (byte)map((long)(mhz * 100), 90000, 92800, clb4[0], clb4[1]));
SpiWriteReg(CC1101_TEST0,0x09);
int s = this->SpiReadStatus(CC1101_FSCAL2);
if (s<32){SpiWriteReg(CC1101_FSCAL2, s+32);}
if (last_pa[currentModule] != 4){setPA(pa[currentModule]);}
}
}
/****************************************************************
*FUNCTION NAME:Calibration offset
*FUNCTION     :Set calibration offset
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setClb(byte b, byte s, byte e){
if (b == 1){
clb1[0]=s;
clb1[1]=e;  
}
else if (b == 2){
clb2[0]=s;
clb2[1]=e;  
}
else if (b == 3){
clb3[0]=s;
clb3[1]=e;  
}
else if (b == 4){
clb4[0]=s;
clb4[1]=e;  
}
}
/****************************************************************
*FUNCTION NAME:getCC1101
*FUNCTION     :Test Spi connection and return 1 when true.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
bool CC1101_Radio::getCC1101(void){
setSpi();
if (SpiReadStatus(0x31)>0){
return 1;
}else{
return 0;
}
}
/****************************************************************
*FUNCTION NAME:getMode
*FUNCTION     :Return the Mode. Sidle = 0, TX = 1, Rx = 2.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
byte CC1101_Radio::getMode(void){
return trxstate[currentModule];
}
/****************************************************************
*FUNCTION NAME:getModeForModule
*FUNCTION     :Return the Mode for a specific module. Sidle = 0, TX = 1, Rx = 2.
*INPUT        :module: The module index to get the mode for.
*OUTPUT       :The mode of the specified module.
****************************************************************/
byte CC1101_Radio::getModeForModule(int module) const {
    extern byte trxstate[];
    return trxstate[module];
}
/****************************************************************
*FUNCTION NAME:Set Sync_Word
*FUNCTION     :Sync Word
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setSyncWord(byte sh, byte sl){
SpiWriteReg(CC1101_SYNC1, sh);
SpiWriteReg(CC1101_SYNC0, sl);
}
/****************************************************************
*FUNCTION NAME:Set ADDR
*FUNCTION     :Address used for packet filtration. Optional broadcast addresses are 0 (0x00) and 255 (0xFF).
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setAddr(byte v){
SpiWriteReg(CC1101_ADDR, v);
}
/****************************************************************
*FUNCTION NAME:Set PQT
*FUNCTION     :Preamble quality estimator threshold
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setPQT(byte v){
Split_PKTCTRL1();
pc1PQT[currentModule] = 0;
if (v>7){v=7;}
pc1PQT[currentModule] = v*32;
SpiWriteReg(CC1101_PKTCTRL1, pc1PQT[currentModule]+pc1CRC_AF[currentModule]+pc1APP_ST[currentModule]+pc1ADRCHK[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set CRC_AUTOFLUSH
*FUNCTION     :Enable automatic flush of RX FIFO when CRC is not OK
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setCRC_AF(bool v){
Split_PKTCTRL1();
pc1CRC_AF[currentModule] = 0;
if (v==1){pc1CRC_AF[currentModule]=8;}
SpiWriteReg(CC1101_PKTCTRL1, pc1PQT[currentModule]+pc1CRC_AF[currentModule]+pc1APP_ST[currentModule]+pc1ADRCHK[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set APPEND_STATUS
*FUNCTION     :When enabled, two status bytes will be appended to the payload of the packet
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setAppendStatus(bool v){
Split_PKTCTRL1();
pc1APP_ST[currentModule] = 0;
if (v==1){pc1APP_ST[currentModule]=4;}
SpiWriteReg(CC1101_PKTCTRL1, pc1PQT[currentModule]+pc1CRC_AF[currentModule]+pc1APP_ST[currentModule]+pc1ADRCHK[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set ADR_CHK
*FUNCTION     :Controls address check configuration of received packages
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setAdrChk(byte v){
Split_PKTCTRL1();
pc1ADRCHK[currentModule] = 0;
if (v>3){v=3;}
pc1ADRCHK[currentModule] = v;
SpiWriteReg(CC1101_PKTCTRL1, pc1PQT[currentModule]+pc1CRC_AF[currentModule]+pc1APP_ST[currentModule]+pc1ADRCHK[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set WHITE_DATA
*FUNCTION     :Turn data whitening on / off.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setWhiteData(bool v){
Split_PKTCTRL0();
pc0WDATA[currentModule] = 0;
if (v == 1){pc0WDATA[currentModule]=64;}
SpiWriteReg(CC1101_PKTCTRL0, pc0WDATA[currentModule]+pc0PktForm[currentModule]+pc0CRC_EN[currentModule]+pc0LenConf[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set PKT_FORMAT
*FUNCTION     :Format of RX and TX data
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setPktFormat(byte v){
Split_PKTCTRL0();
pc0PktForm[currentModule] = 0;
if (v>3){v=3;}
pc0PktForm[currentModule] = v*16;
SpiWriteReg(CC1101_PKTCTRL0, pc0WDATA[currentModule]+pc0PktForm[currentModule]+pc0CRC_EN[currentModule]+pc0LenConf[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set CRC
*FUNCTION     :CRC calculation in TX and CRC check in RX
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setCrc(bool v){
Split_PKTCTRL0();
pc0CRC_EN[currentModule] = 0;
if (v==1){pc0CRC_EN[currentModule]=4;}
SpiWriteReg(CC1101_PKTCTRL0, pc0WDATA[currentModule]+pc0PktForm[currentModule]+pc0CRC_EN[currentModule]+pc0LenConf[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set LENGTH_CONFIG
*FUNCTION     :Configure the packet length
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setLengthConfig(byte v){
Split_PKTCTRL0();
pc0LenConf[currentModule] = 0;
if (v>3){v=3;}
pc0LenConf[currentModule] = v;
SpiWriteReg(CC1101_PKTCTRL0, pc0WDATA[currentModule]+pc0PktForm[currentModule]+pc0CRC_EN[currentModule]+pc0LenConf[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set PACKET_LENGTH
*FUNCTION     :Indicates the packet length
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setPacketLength(byte v){
SpiWriteReg(CC1101_PKTLEN, v);
}
/****************************************************************
*FUNCTION NAME:Set DCFILT_OFF
*FUNCTION     :Disable digital DC blocking filter before demodulator
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setDcFilterOff(bool v){
dcOffFlag[currentModule] = v;
Split_MDMCFG2();
m2DCOFF[currentModule] = 0;
if (v==1){m2DCOFF[currentModule]=128;}
SpiWriteReg(CC1101_MDMCFG2, m2DCOFF[currentModule]+m2MODFM[currentModule]+m2MANCH[currentModule]+m2SYNCM[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set MANCHESTER
*FUNCTION     :Enables Manchester encoding/decoding
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setManchester(bool v){
Split_MDMCFG2();
m2MANCH[currentModule] = 0;
if (v==1){m2MANCH[currentModule]=8;}
SpiWriteReg(CC1101_MDMCFG2, m2DCOFF[currentModule]+m2MODFM[currentModule]+m2MANCH[currentModule]+m2SYNCM[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set SYNC_MODE
*FUNCTION     :Combined sync-word qualifier mode
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setSyncMode(byte v){
syncModeFlag[currentModule] = v;
Split_MDMCFG2();
m2SYNCM[currentModule] = 0;
if (v>7){v=7;}
m2SYNCM[currentModule]=v;
SpiWriteReg(CC1101_MDMCFG2, m2DCOFF[currentModule]+m2MODFM[currentModule]+m2MANCH[currentModule]+m2SYNCM[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set FEC
*FUNCTION     :Enable Forward Error Correction (FEC)
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setFEC(bool v){
Split_MDMCFG1();
m1FEC[currentModule]=0;
if (v==1){m1FEC[currentModule]=128;}
SpiWriteReg(CC1101_MDMCFG1, m1FEC[currentModule]+m1PRE[currentModule]+m1CHSP[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set PRE
*FUNCTION     :Sets the minimum number of preamble bytes to be transmitted.
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setPRE(byte v){
Split_MDMCFG1();
m1PRE[currentModule]=0;
if (v>7){v=7;}
m1PRE[currentModule] = v*16;
SpiWriteReg(CC1101_MDMCFG1, m1FEC[currentModule]+m1PRE[currentModule]+m1CHSP[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set Channel
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setChannel(byte ch){
chan[currentModule] = ch;
SpiWriteReg(CC1101_CHANNR,   chan[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set Channel spacing
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setChsp(float f){
Split_MDMCFG1();
byte MDMCFG0 = 0;
m1CHSP[currentModule] = 0;
if (f > 405.456543){f = 405.456543;}
if (f < 25.390625){f = 25.390625;}
for (int i = 0; i<5; i++){
if (f <= 50.682068){
f -= 25.390625;
f /= 0.0991825;
MDMCFG0 = f;
float s1 = (f - MDMCFG0) *10;
if (s1 >= 5){MDMCFG0++;}
i = 5;
}else{
m1CHSP[currentModule]++;
f/=2;
}
}
SpiWriteReg(19,m1CHSP[currentModule]+m1FEC[currentModule]+m1PRE[currentModule]);
SpiWriteReg(20,MDMCFG0);
}
/****************************************************************
*FUNCTION NAME:Set Receive bandwidth
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setRxBW(float f){
bwValue[currentModule] = f;
Split_MDMCFG4();
int s1 = 3;
int s2 = 3;
for (int i = 0; i<3; i++){
if (f > 101.5625){f/=2; s1--;}
else{i=3;}
}
for (int i = 0; i<3; i++){
if (f > 58.1){f/=1.25; s2--;}
else{i=3;}
}
s1 *= 64;
s2 *= 16;
m4RxBw[currentModule] = s1 + s2;
SpiWriteReg(16,m4RxBw[currentModule]+m4DaRa[currentModule]);
}
/****************************************************************
*FUNCTION NAME:Set Data Rate
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setDRate(float d){
dataRate[currentModule] = d;
Split_MDMCFG4();
float c = d;
byte MDMCFG3 = 0;
if (c > 1621.83){c = 1621.83;}
if (c < 0.0247955){c = 0.0247955;}
m4DaRa[currentModule] = 0;
for (int i = 0; i<20; i++){
if (c <= 0.0494942){
c = c - 0.0247955;
c = c / 0.00009685;
MDMCFG3 = c;
float s1 = (c - MDMCFG3) *10;
if (s1 >= 5){MDMCFG3++;}
i = 20;
}else{
m4DaRa[currentModule]++;
c = c/2;
}
}
SpiWriteReg(16,  m4RxBw[currentModule]+m4DaRa[currentModule]);
SpiWriteReg(17,  MDMCFG3);
}
/****************************************************************
*FUNCTION NAME:Set Devitation
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setDeviation(float d) {
    const float fXOSC = 26e3;
    const float baseDeviation = fXOSC / 131072.0;

    if (d > 380.859375) {
        d = 380.859375;
    } else if (d < 1.586914) {
        d = 1.586914;
    }

    int bestRegisterValue = 0;
    float bestDeviation = 0;
    float smallestDifference = 1e30;

    for (int exponent = 0; exponent < 8; exponent++) {
        for (int mantissa = 0; mantissa < 8; mantissa++) {
            float deviation = baseDeviation * (8 + mantissa) * (1 << exponent);
            float difference = fabs(d - deviation);

            if (difference < smallestDifference) {
                smallestDifference = difference;
                bestDeviation = deviation;
                bestRegisterValue = (exponent << 4) | (mantissa & 0x07);
            }
        }
    }
    bestRegisterValue &= 0x77;
    SpiWriteReg(21, bestRegisterValue);
}

/****************************************************************
*FUNCTION NAME:Split PKTCTRL0
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Split_PKTCTRL1(void){
int calc = SpiReadStatus(7);
pc1PQT[currentModule] = 0;
pc1CRC_AF[currentModule] = 0;
pc1APP_ST[currentModule] = 0;
pc1ADRCHK[currentModule] = 0;
for (bool i = 0; i==0;){
if (calc >= 32){calc-=32; pc1PQT[currentModule]+=32;}
else if (calc >= 8){calc-=8; pc1CRC_AF[currentModule]+=8;}
else if (calc >= 4){calc-=4; pc1APP_ST[currentModule]+=4;}
else {pc1ADRCHK[currentModule] = calc; i=1;}
}
}
/****************************************************************
*FUNCTION NAME:Split PKTCTRL0
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Split_PKTCTRL0(void){
int calc = SpiReadStatus(8);
pc0WDATA[currentModule] = 0;
pc0PktForm[currentModule] = 0;
pc0CRC_EN[currentModule] = 0;
pc0LenConf[currentModule] = 0;
for (bool i = 0; i==0;){
if (calc >= 64){calc-=64; pc0WDATA[currentModule]+=64;}
else if (calc >= 16){calc-=16; pc0PktForm[currentModule]+=16;}
else if (calc >= 4){calc-=4; pc0CRC_EN[currentModule]+=4;}
else {pc0LenConf[currentModule] = calc; i=1;}
}
}
/****************************************************************
*FUNCTION NAME:Split MDMCFG1
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Split_MDMCFG1(void){
int calc = SpiReadStatus(19);
m1FEC[currentModule] = 0;
m1PRE[currentModule] = 0;
m1CHSP[currentModule] = 0;
for (bool i = 0; i==0;){
if (calc >= 128){calc-=128; m1FEC[currentModule]+=128;}
else if (calc >= 16){calc-=16; m1PRE[currentModule]+=16;}
else {m1CHSP[currentModule] = calc; i=1;}
}
}
/****************************************************************
*FUNCTION NAME:Split MDMCFG2
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Split_MDMCFG2(void){
int calc = SpiReadStatus(18);
m2DCOFF[currentModule] = 0;
m2MODFM[currentModule] = 0;
m2MANCH[currentModule] = 0;
m2SYNCM[currentModule] = 0;
for (bool i = 0; i==0;){
if (calc >= 128){calc-=128; m2DCOFF[currentModule]+=128;}
else if (calc >= 16){calc-=16; m2MODFM[currentModule]+=16;}
else if (calc >= 8){calc-=8; m2MANCH[currentModule]+=8;}
else{m2SYNCM[currentModule] = calc; i=1;}
}
}
/****************************************************************
*FUNCTION NAME:Split MDMCFG4
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::Split_MDMCFG4(void){
int calc = SpiReadStatus(16);
m4RxBw[currentModule] = 0;
m4DaRa[currentModule] = 0;
for (bool i = 0; i==0;){
if (calc >= 64){calc-=64; m4RxBw[currentModule]+=64;}
else if (calc >= 16){calc -= 16; m4RxBw[currentModule]+=16;}
else{m4DaRa[currentModule] = calc; i=1;}
}
}
/****************************************************************
*FUNCTION NAME:RegConfigSettings
*FUNCTION     :CC1101 register config //details refer datasheet of CC1101/CC1100//
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::RegConfigSettings(void) 
{   
    SpiWriteReg(CC1101_FSCTRL1,  0x06);
    
    setCCMode(ccmode[currentModule]);
    setMHZ(MHz[currentModule]);
    
    SpiWriteReg(CC1101_MDMCFG1,  0x02);
    SpiWriteReg(CC1101_MDMCFG0,  0xF8);
    SpiWriteReg(CC1101_CHANNR,   chan[currentModule]);
    SpiWriteReg(CC1101_DEVIATN,  0x47);
    SpiWriteReg(CC1101_FREND1,   0x56);
    SpiWriteReg(CC1101_MCSM0 ,   0x18);
    SpiWriteReg(CC1101_FOCCFG,   0x16);
    SpiWriteReg(CC1101_BSCFG,    0x1C);
    SpiWriteReg(CC1101_AGCCTRL2, 0xC7);
    SpiWriteReg(CC1101_AGCCTRL1, 0x00);
    SpiWriteReg(CC1101_AGCCTRL0, 0xB2);
    SpiWriteReg(CC1101_FSCAL3,   0xE9);
    SpiWriteReg(CC1101_FSCAL2,   0x2A);
    SpiWriteReg(CC1101_FSCAL1,   0x00);
    SpiWriteReg(CC1101_FSCAL0,   0x1F);
    SpiWriteReg(CC1101_FSTEST,   0x59);
    SpiWriteReg(CC1101_TEST2,    0x81);
    SpiWriteReg(CC1101_TEST1,    0x35);
    SpiWriteReg(CC1101_TEST0,    0x09);
    SpiWriteReg(CC1101_PKTCTRL1, 0x04);
    SpiWriteReg(CC1101_ADDR,     0x00);
    SpiWriteReg(CC1101_PKTLEN,   0x00);
}
/****************************************************************
*FUNCTION NAME:SetTx
*FUNCTION     :set CC1101 send data
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SetTx(void)
{
  SpiStrobe(CC1101_SIDLE);
  SpiStrobe(CC1101_STX);        //start send
  trxstate[currentModule]=1;
}
/****************************************************************
*FUNCTION NAME:SetRx
*FUNCTION     :set CC1101 to receive state
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SetRx(void)
{
  SpiStrobe(CC1101_SIDLE);
  SpiStrobe(CC1101_SRX);        //start receive
  trxstate[currentModule]=2;
}
/****************************************************************
*FUNCTION NAME:SetTx
*FUNCTION     :set CC1101 send data and change frequency
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SetTx(float mhz)
{
  SpiStrobe(CC1101_SIDLE);
  setMHZ(mhz);
  SpiStrobe(CC1101_STX);        //start send
  trxstate[currentModule]=1;
}
/****************************************************************
*FUNCTION NAME:SetRx
*FUNCTION     :set CC1101 to receive state and change frequency
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SetRx(float mhz)
{
  SpiStrobe(CC1101_SIDLE);
  setMHZ(mhz);
  SpiStrobe(CC1101_SRX);        //start receive
  trxstate[currentModule]=2;
}
/****************************************************************
*FUNCTION NAME:RSSI Level
*FUNCTION     :Calculating the RSSI Level
*INPUT        :none
*OUTPUT       :none
****************************************************************/
int CC1101_Radio::getRssi(void)
{
int rssi;
rssi=SpiReadStatus(CC1101_RSSI);
if (rssi >= 128){rssi = (rssi-256)/2-74;}
else{rssi = (rssi/2)-74;}
return rssi;
}
/****************************************************************
*FUNCTION NAME:LQI Level
*FUNCTION     :get Lqi state
*INPUT        :none
*OUTPUT       :none
****************************************************************/
byte CC1101_Radio::getLqi(void)
{
byte lqi;
lqi=SpiReadStatus(CC1101_LQI);
return lqi;
}
/****************************************************************
*FUNCTION NAME:SetSres
*FUNCTION     :Reset CC1101
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setSres(void)
{
  SpiStrobe(CC1101_SRES);
  trxstate[currentModule]=0;
}
/****************************************************************
*FUNCTION NAME:setSidle
*FUNCTION     :set Rx / TX Off
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::setSidle(void)
{
  SpiStrobe(CC1101_SIDLE);
  // while (digitalRead(MISO)) {
  //   vTaskDelay(1);
  // };  // Wait until MISO goes low

  trxstate[currentModule]=0;
}
/****************************************************************
*FUNCTION NAME:goSleep
*FUNCTION     :set cc1101 Sleep on
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::goSleep(void){
  trxstate[currentModule]=0;
  SpiStrobe(0x36);//Exit RX / TX, turn off frequency synthesizer and exit
  SpiStrobe(0x39);//Enter power down mode when CSn goes high.
}
/****************************************************************
*FUNCTION NAME:Char direct SendData
*FUNCTION     :use CC1101 send data
*INPUT        :txBuffer: data array to send; size: number of data to send, no more than 61
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SendData(char *txchar)
{
int len = strlen(txchar);
byte chartobyte[len];
for (int i = 0; i<len; i++){chartobyte[i] = txchar[i];}
SendData(chartobyte,len);
}
/****************************************************************
*FUNCTION NAME:SendData
*FUNCTION     :use CC1101 send data
*INPUT        :txBuffer: data array to send; size: number of data to send, no more than 61
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SendData(byte *txBuffer,byte size)
{
  SpiWriteReg(CC1101_TXFIFO,size);
  SpiWriteBurstReg(CC1101_TXFIFO,txBuffer,size);      //write data to send
  SpiStrobe(CC1101_SIDLE);
  SpiStrobe(CC1101_STX);                  //start send
    while (!digitalRead(GDO0[currentModule]));               // Wait for GDO0[currentModule] to be set -> sync transmitted  
    while (digitalRead(GDO0[currentModule]));                // Wait for GDO0[currentModule] to be cleared -> end of packet
  SpiStrobe(CC1101_SFTX);                 //flush TXfifo
  trxstate[currentModule]=1;
}
/****************************************************************
*FUNCTION NAME:Char direct SendData
*FUNCTION     :use CC1101 send data without GDO
*INPUT        :txBuffer: data array to send; size: number of data to send, no more than 61
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SendData(char *txchar,int t)
{
int len = strlen(txchar);
byte chartobyte[len];
for (int i = 0; i<len; i++){chartobyte[i] = txchar[i];}
SendData(chartobyte,len,t);
}
/****************************************************************
*FUNCTION NAME:SendData
*FUNCTION     :use CC1101 send data without GDO
*INPUT        :txBuffer: data array to send; size: number of data to send, no more than 61
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::SendData(byte *txBuffer,byte size,int t)
{
  SpiWriteReg(CC1101_TXFIFO,size);
  SpiWriteBurstReg(CC1101_TXFIFO,txBuffer,size);      //write data to send
  SpiStrobe(CC1101_SIDLE);
  SpiStrobe(CC1101_STX);                  //start send
  delay(t);
  SpiStrobe(CC1101_SFTX);                 //flush TXfifo
  trxstate[currentModule]=1;
}
/****************************************************************
*FUNCTION NAME:Check CRC
*FUNCTION     :none
*INPUT        :none
*OUTPUT       :none
****************************************************************/
bool CC1101_Radio::CheckCRC(void){
byte lqi=SpiReadStatus(CC1101_LQI);
bool crc_ok = bitRead(lqi,7);
if (crc_ok == 1){
return 1;
}else{
SpiStrobe(CC1101_SFRX);
SpiStrobe(CC1101_SRX);
return 0;
}
}
/****************************************************************
*FUNCTION NAME:CheckRxFifo
*FUNCTION     :check receive data or not
*INPUT        :none
*OUTPUT       :flag: 0 no data; 1 receive data 
****************************************************************/
bool CC1101_Radio::CheckRxFifo(int t){
if(trxstate[currentModule]!=2){SetRx();}
if(SpiReadStatus(CC1101_RXBYTES) & BYTES_IN_RXFIFO){
delay(t);
return 1;
}else{
return 0;
}
}
/****************************************************************
*FUNCTION NAME:CheckReceiveFlag
*FUNCTION     :check receive data or not
*INPUT        :none
*OUTPUT       :flag: 0 no data; 1 receive data 
****************************************************************/
byte CC1101_Radio::CheckReceiveFlag(void)
{
  if(trxstate[currentModule]!=2){SetRx();}
	if(digitalRead(GDO0[currentModule]))			//receive data
	{
		while (digitalRead(GDO0[currentModule]));
		return 1;
	}
	else							// no data
	{
		return 0;
	}
}
/****************************************************************
*FUNCTION NAME:ReceiveData
*FUNCTION     :read data received from RXfifo
*INPUT        :rxBuffer: buffer to store data
*OUTPUT       :size of data received
****************************************************************/
byte CC1101_Radio::ReceiveData(byte *rxBuffer)
{
	byte size;
	byte status[2];

	if(SpiReadStatus(CC1101_RXBYTES) & BYTES_IN_RXFIFO)
	{
		size=SpiReadReg(CC1101_RXFIFO);
		SpiReadBurstReg(CC1101_RXFIFO,rxBuffer,size);
		SpiReadBurstReg(CC1101_RXFIFO,status,2);
		SpiStrobe(CC1101_SFRX);
    SpiStrobe(CC1101_SRX);
		return size;
	}
	else
	{
		SpiStrobe(CC1101_SFRX);
    SpiStrobe(CC1101_SRX);
 		return 0;
	}
}

byte CC1101_Radio::getState() {
    return SpiReadStatus(CC1101_MARCSTATE);
}

/****************************************************************
*FUNCTION NAME:calibrate
*FUNCTION     :Perform calibration (uses current MHz[currentModule] and updates modulation from register)
*INPUT        :none
*OUTPUT       :none
****************************************************************/
void CC1101_Radio::calibrate()
{
    // Update modulation state from MDMCFG2 register before calibration
    // This ensures calibration uses correct modulation settings
    Split_MDMCFG2();
    
    // Perform calibration using current frequency (MHz[currentModule])
    Calibrate();
}

/****************************************************************
*FUNCTION NAME:waitForCalibration
*FUNCTION     :Wait for calibration to complete
*INPUT        :timeoutMs - timeout in milliseconds (default 100ms)
*OUTPUT       :true if calibration completed, false if timeout
****************************************************************/
bool CC1101_Radio::waitForCalibration(uint32_t timeoutMs)
{
    uint32_t startTime = millis();
    
    while ((millis() - startTime) < timeoutMs) {
        byte marcState = SpiReadStatus(CC1101_MARCSTATE);
        
        // MARCSTATE values:
        // 0x01 = IDLE
        // 0x13 = TX
        // 0x14 = RX
        // 0x16 = FSTXON (Frequency synthesizer on)
        // 0x17 = CALIBRATE (Calibrating)
        // 0x19 = SETTLING
        
        // Calibration is complete when we're not in CALIBRATE state
        // and not in SETTLING state
        if (marcState != 0x17 && marcState != 0x19) {
            // Calibration complete - we're in IDLE, TX, RX, or FSTXON
            return true;
        }
        
        delay(1);  // Small delay to avoid busy-waiting
    }
    
    // Timeout - calibration may still be in progress
    return false;
}

float CC1101_Radio::getFrequency()
{
    byte freqBytes[3];
    SpiReadBurstReg(CC1101_FREQ2, freqBytes, 3);  // Читаем FREQ2, FREQ1, FREQ0 за одну транзакцию
    
    unsigned long freq = ((unsigned long)freqBytes[0] << 16) | ((unsigned long)freqBytes[1] << 8) | (unsigned long)freqBytes[2];
    return (float)freq * 26.0 / (1 << 16);
}

CC1101_Radio cc1101;