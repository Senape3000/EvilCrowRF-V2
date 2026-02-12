/**
 * @file BatteryModule.cpp
 * @brief Battery voltage monitoring implementation.
 *
 * Uses ESP32 ADC1 with calibration for accurate voltage readings.
 * GPIO 36 (VP) is an input-only pin with ADC1_CHANNEL_0.
 *
 * LiPo discharge curve approximation (3.7V nominal):
 *   4.20V = 100%
 *   4.10V = 90%
 *   3.95V = 75%
 *   3.80V = 50%
 *   3.70V = 25%
 *   3.50V = 10%
 *   3.20V = 0% (cutoff)
 */

#include "BatteryModule.h"

#if BATTERY_MODULE_ENABLED

#include <driver/adc.h>

static const char* TAG = "Battery";

// Static members
bool     BatteryModule::initialized_  = false;
uint16_t BatteryModule::lastVoltage_  = 0;
uint8_t  BatteryModule::lastPercent_  = 0;
bool     BatteryModule::lastCharging_ = false;
esp_adc_cal_characteristics_t BatteryModule::adcChars_ = {};
TimerHandle_t BatteryModule::readTimer_ = nullptr;

void BatteryModule::init() {
    if (initialized_) return;

    // Configure ADC1 channel 0 (GPIO 36) with 11dB attenuation
    // 11dB attenuation allows reading up to ~3.3V (with some non-linearity above 2.6V)
    adc1_config_width(ADC_WIDTH_BIT_12);
    adc1_config_channel_atten(ADC1_CHANNEL_0, ADC_ATTEN_DB_12);

    // Characterize ADC for voltage conversion (uses factory calibration if available)
    esp_adc_cal_value_t calType = esp_adc_cal_characterize(
        ADC_UNIT_1, ADC_ATTEN_DB_12, ADC_WIDTH_BIT_12, 1100, &adcChars_);

    const char* calStr = "None";
    if (calType == ESP_ADC_CAL_VAL_EFUSE_TP)       calStr = "Two Point";
    else if (calType == ESP_ADC_CAL_VAL_EFUSE_VREF) calStr = "eFuse Vref";
    else if (calType == ESP_ADC_CAL_VAL_DEFAULT_VREF) calStr = "Default Vref";

    ESP_LOGI(TAG, "ADC calibration: %s", calStr);

    // Take initial reading
    lastVoltage_ = readVoltage();
    lastPercent_ = voltageToPercent(lastVoltage_);
    lastCharging_ = isCharging();

    ESP_LOGI(TAG, "Battery init: %dmV (%d%%) charging=%d",
             lastVoltage_, lastPercent_, lastCharging_);

    // Start periodic timer
    if (BATTERY_READ_INTERVAL_MS > 0) {
        readTimer_ = xTimerCreate(
            "BattTimer",
            pdMS_TO_TICKS(BATTERY_READ_INTERVAL_MS),
            pdTRUE,    // Auto-reload
            nullptr,
            timerCallback
        );
        if (readTimer_) {
            xTimerStart(readTimer_, 0);
            ESP_LOGI(TAG, "Periodic reading every %dms", BATTERY_READ_INTERVAL_MS);
        }
    }

    initialized_ = true;
}

uint16_t BatteryModule::readVoltage() {
    // Multisample for noise reduction
    uint32_t adcSum = 0;
    for (int i = 0; i < ADC_SAMPLES; i++) {
        adcSum += adc1_get_raw(ADC1_CHANNEL_0);
    }
    uint32_t adcAvg = adcSum / ADC_SAMPLES;

    // Convert averaged raw ADC reading to calibrated voltage
    uint32_t voltage_mv = esp_adc_cal_raw_to_voltage(adcAvg, &adcChars_);

    // Apply voltage divider ratio to get actual battery voltage
    uint16_t batteryVoltage = (uint16_t)(voltage_mv * BATTERY_DIVIDER_RATIO);

    return batteryVoltage;
}

uint8_t BatteryModule::voltageToPercent(uint16_t voltage_mv) {
    // Piecewise linear approximation of LiPo discharge curve
    // Based on typical 3.7V LiPo cell characteristics
    struct VoltagePoint {
        uint16_t mv;
        uint8_t pct;
    };

    // Discharge curve lookup table (descending voltage)
    static const VoltagePoint curve[] = {
        {4200, 100},
        {4150,  95},
        {4100,  90},
        {4000,  80},
        {3950,  75},
        {3900,  70},
        {3850,  60},
        {3800,  50},
        {3750,  40},
        {3700,  30},
        {3650,  20},
        {3500,  10},
        {3300,   5},
        {3200,   0},
    };
    static const int curveSize = sizeof(curve) / sizeof(curve[0]);

    // Clamp to range
    if (voltage_mv >= curve[0].mv) return 100;
    if (voltage_mv <= curve[curveSize - 1].mv) return 0;

    // Linear interpolation between curve points
    for (int i = 0; i < curveSize - 1; i++) {
        if (voltage_mv >= curve[i + 1].mv) {
            uint16_t vRange = curve[i].mv - curve[i + 1].mv;
            uint8_t  pRange = curve[i].pct - curve[i + 1].pct;
            uint16_t vDelta = voltage_mv - curve[i + 1].mv;
            return curve[i + 1].pct + (uint8_t)((uint32_t)vDelta * pRange / vRange);
        }
    }

    return 0;
}

bool BatteryModule::isCharging() {
    // Charging detection: if voltage is above 4.15V and still rising,
    // it's likely charging. A more robust approach would use a dedicated
    // CHRG pin from the TP4056, but we approximate it from voltage.
    //
    // Heuristic: voltage > 4.15V suggests active charging or fully charged.
    // The TP4056 CHRG pin (if connected to a GPIO) would be more reliable.
    //
    // TODO: If the schematic confirms a CHRG pin on a GPIO, read it directly.
    return (lastVoltage_ > 4150);
}

void BatteryModule::sendBatteryStatus() {
    if (!initialized_) return;

    BinaryBatteryStatus msg;
    msg.voltage_mv = lastVoltage_;
    msg.percentage = lastPercent_;
    msg.charging   = lastCharging_ ? 1 : 0;

    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::DeviceInfo,
        reinterpret_cast<const uint8_t*>(&msg),
        sizeof(msg));

    ESP_LOGD(TAG, "Battery: %dmV %d%% charging=%d",
             lastVoltage_, lastPercent_, lastCharging_);
}

void BatteryModule::timerCallback(TimerHandle_t /*xTimer*/) {
    uint16_t prevVoltage = lastVoltage_;
    lastVoltage_ = readVoltage();
    lastPercent_ = voltageToPercent(lastVoltage_);
    lastCharging_ = isCharging();

    // Only send BLE notification if value changed significantly (±50mV or ±2%)
    int16_t vDiff = (int16_t)lastVoltage_ - (int16_t)prevVoltage;
    if (vDiff < -50 || vDiff > 50) {
        sendBatteryStatus();
    }
}

#endif // BATTERY_MODULE_ENABLED
