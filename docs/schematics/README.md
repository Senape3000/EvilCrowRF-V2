
# **Evil Crow RF V2: Hardware Analysis & Pinout Report**

*(based on: Schematic\_EvilCrow\_RF\_V4\_2021-12-14.pdf)*

## **1\. Core Architecture**

* **MCU:** ESP32-PICO-D4 (System-in-Package).

  * Dual-core Xtensa LX6, 240MHz.  
  * Integrated 4MB SPI Flash.  
  * Crystal: 40MHz.  
* **Programming Interface:** USB-to-UART via **CH340C** (U4).  
  * Auto-reset circuit (Q1) uses DTR/RTS to toggle EN/IO0 for automatic flashing.

## **2\. Power Management System**

The power analysis in the original PDF contained a component identification error regarding the MOSFET.

* **Primary Regulation:** **BL9110-330BPFB** (U6). LDO Regulator providing 3.3V system rail.

* **Battery Charging:** **HP4054** (U5). Linear Li-Ion charger.  
  * Charge Current: Configured via R10. Schematic shows options for 500mA or 1A.  
  * Charging Status LED (Orange): Connected to U5 STAT pin.

* **Battery Monitoring:**  
  * The voltage divider consists of **R14 (100kΩ)** and **R15 (220kΩ)**.  
  * **Topology:** GND \--- R14(100k) \--- GPIO36(VP) \--- R15(220k) \--- VBAT.  
  * **Scaling Factor:** Ratio as 3.2 ($(220+100)/100$).  
  * **Pin:** **GPIO36 (ADC1\_CH0)** (Input Only).

* **SD Card Power Switching:**  
  * **Component:** **Q2** (AO3401 P-Channel MOSFET).  
  * **Function:** Controls the VDD\_SDIO rail.  
  * **Logic:** Controlled by a GPIO (Net label "CS") to hard-reset the SD card logic by cutting power.

## **3\. Storage Interface (SDIO)**

The V4 Schematic utilizes the high-speed SDIO interface, which requires specific GPIOs.

* **Mode:** 4-bit SDIO.  
* **Pinout:**  
  * **CLK:** GPIO14  
  * **CMD:** GPIO15  
  * **D0:** GPIO2  
  * **D1:** GPIO4  
  * **D2:** GPIO12  
  * **D3:** GPIO13

* **Conflict Warning:** The config.h attempts to assign RF modules to GPIOs 2, 4, 12, and 13\. This is **physically impossible** on the V4 hardware if the SD card is in use, as these lines are physically wired to the SD slot.

## **4\. RF Module Configuration**

The board features three RF modules sharing a common SPI bus but utilizing separate Control/Chip Select lines.

### **Shared Bus (VSPI)**

According to Schematic V4 traces (Net labels SCK2, MISO2, MOSI2):

* **SCK:** GPIO18  
* **MISO:** GPIO19  
* **MOSI:** GPIO23

### **Module 1: CC1101 (U2 \- 433MHz)**

* **Function:** Sub-GHz Transceiver.  
* **Chip Select (CS\_A):** Likely **GPIO 5** (based on exclusion, though config.h assigns 5 to SS0, verify strictly as GPIO5 is usually Input Only on some dev boards, but valid output on ESP32 chip).  
  * *Correction:* config.h lists CC1101\_SS0 5\. However, GPIO 5 is also used for VSPI CS on standard mappings.  
* **GDO0 / GDO2:** Must be mapped to available inputs (e.g., GPIO 34, 35\) or free GPIOs (25, 26, 27\) if not used by Module 2\.

### **Module 2: CC1101 (U3 \- 433MHz)**

* **Function:** Sub-GHz Transceiver (Diversity/RX/TX).  
* **Chip Select (CS\_B):** Likely **GPIO 27** (matches config.h CC1101\_SS1).  
* **GDO Pins:** config.h suggests GPIO 25 and 26, which are free on the schematic.

### **Module 3: NRF24L01 (U7 \- 2.4GHz)**

* **Function:** 2.4GHz ISM (MouseJack/KeyJack).  
* **Chip Select (CSN):** Likely **GPIO 15** (per config.h NRF\_CSN 15), BUT GPIO 15 is hardwired to **SD\_CMD** in the schematic.  
  * *Hardware Conflict:* If NRF CSN is physically on 15, it conflicts with SD Card operation.

## **5\. User Interface & GPIO Summary**

### **Buttons**

* **RESET (SW2):** Connected to **EN** (Chip Enable). Hardware reset.  
* **BOOT (SW1):** Connected to **GPIO0**. Used for flashing mode or user input.  
* **User Buttons:** The config.h defines BUTTON1 34 and BUTTON2 35\.  
  * **Schematic Verification:** GPIO 34 and 35 are "Input Only" pins exposed on the header/layout. These match the schematic capabilities.

### **LEDs**

* **LED1 (Red):** Power Indicator (Always ON via resistor to VCC).

* **LED2 (Orange):** Charge Indicator (Controlled by U5).  
* **User LED:** config.h defines LED 32\. GPIO 32 is available on the ESP32 and likely routed to a discrete LED or header.

## **6\. Corrected GPIO Mapping Table (V4)**

| Component | Function | GPIO Pin | Note |
| :---- | :---- | :---- | :---- |
| **SD Card** | CLK | **14** | SDIO 4-Bit |
| **SD Card** | CMD | **15** | SDIO 4-Bit |
| **SD Card** | D0 | **2** | SDIO 4-Bit |
| **SD Card** | D1 | **4** | SDIO 4-Bit |
| **SD Card** | D2 | **12** | SDIO 4-Bit |
| **SD Card** | D3 | **13** | SDIO 4-Bit |
| **RF Bus** | SCK | **18** | VSPI |
| **RF Bus** | MISO | **19** | VSPI |
| **RF Bus** | MOSI | **23** | VSPI |
| **Battery** | Monitor | **36** | Divider 100k/220k |
| **User** | Button 1 | **34** | Input Only |
| **User** | Button 2 | **35** | Input Only |
| **User** | LED | **32** | Output |
| **System** | UART TX | **1** | Console |
| **System** | UART RX | **3** | Console |

**Unassigned / Configurable (RF Control Lines):**

* **GPIO 5:** Likely CC1101 CS (Module A).  
* **GPIO 27:** Likely CC1101 CS (Module B).  
* **GPIO 25:** Available (Likely GDO).  
* **GPIO 26:** Available (Likely GDO).  
* **GPIO 33:** Available.  
* **GPIO 21:** Available.  
* **GPIO 22:** Available.

#### ***This analysis is a draft\!\!\! We need willing people to improve it.***
