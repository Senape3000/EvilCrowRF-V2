/**
 * @file BatteryModule.h
 * @brief Battery voltage monitoring via ADC for EvilCrow-RF-V2.
 *
 * Reads battery voltage through a voltage divider on GPIO 36 (VP).
 * Typical hardware: LiPo 1000mAh with R1=100K/R2=100K divider.
 *
 * Features:
 *   - Periodic ADC reading with averaging (multisampling)
 *   - Voltage-to-percentage conversion (linear LiPo curve approximation)
 *   - BLE notification (MSG_BATTERY_STATUS = 0xC3)
 *   - FreeRTOS timer for background monitoring
 */

#ifndef BATTERY_MODULE_H
#define BATTERY_MODULE_H

#include <Arduino.h>
#include "config.h"
#include "BinaryMessages.h"

#if BATTERY_MODULE_ENABLED

#include <esp_adc_cal.h>
#include "core/ble/ClientsManager.h"
#include "esp_log.h"

class BatteryModule {
public:
    /**
     * Initialize ADC for battery reading.
     * Configures GPIO 36 with 11dB attenuation (0-3.3V range).
     * Starts periodic timer if interval > 0.
     */
    static void init();

    /**
     * Read current battery voltage (multisampled + calibrated).
     * @return Battery voltage in millivolts (before divider compensation).
     */
    static uint16_t readVoltage();

    /**
     * Convert battery voltage to percentage.
     * Uses piecewise linear approximation of LiPo discharge curve.
     * @param voltage_mv Battery voltage in millivolts.
     * @return Percentage 0-100.
     */
    static uint8_t voltageToPercent(uint16_t voltage_mv);

    /**
     * Check if battery is currently charging.
     * @return true if charging is detected.
     */
    static bool isCharging();

    /**
     * Send battery status via BLE.
     * Called periodically by timer and on demand (e.g., getState).
     */
    static void sendBatteryStatus();

    /// @return Last read voltage in mV.
    static uint16_t getLastVoltage() { return lastVoltage_; }

    /// @return Last calculated percentage.
    static uint8_t getLastPercent() { return lastPercent_; }

    /// @return true if module is initialized.
    static bool isInitialized() { return initialized_; }

private:
    static bool initialized_;
    static uint16_t lastVoltage_;
    static uint8_t lastPercent_;
    static bool lastCharging_;
    static esp_adc_cal_characteristics_t adcChars_;
    static TimerHandle_t readTimer_;

    /// Timer callback — reads voltage and sends BLE notification.
    static void timerCallback(TimerHandle_t xTimer);

    /// Number of ADC samples to average for noise reduction.
    static constexpr int ADC_SAMPLES = 16;
};

#endif // BATTERY_MODULE_ENABLED
#endif // BATTERY_MODULE_H
