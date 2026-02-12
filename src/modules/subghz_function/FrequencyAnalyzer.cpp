#include "FrequencyAnalyzer.h"
#include "esp_log.h"

static const char* TAG = "FrequencyAnalyzer";

extern ModuleCc1101 moduleCC1101State[CC1101_NUM_MODULES];

FrequencyAnalyzer frequencyAnalyzer;

FrequencyAnalyzer::FrequencyAnalyzer() 
    : active(false)
    , currentModule(0)
    , startFreq(0.0f)
    , endFreq(0.0f)
    , step(0.0f)
    , currentFreq(0.0f)
    , dwellTime(50)
    , lastScanTime(0)
    , scanStartTime(0) {
}

void FrequencyAnalyzer::startScan(int module, float startFreq, float endFreq, float step, uint32_t dwellTime) {
    if (module < 0 || module >= CC1101_NUM_MODULES) {
        ESP_LOGE(TAG, "Invalid module: %d", module);
        return;
    }
    
    if (startFreq >= endFreq || step <= 0) {
        ESP_LOGE(TAG, "Invalid frequency range: %.2f - %.2f, step %.2f", startFreq, endFreq, step);
        return;
    }
    
    this->active = true;
    this->currentModule = module;
    this->startFreq = startFreq;
    this->endFreq = endFreq;
    this->step = step;
    this->currentFreq = startFreq;
    this->dwellTime = dwellTime > 0 ? dwellTime : 50;
    this->lastScanTime = millis();
    this->scanStartTime = millis();
    
    spectrum.clear();
    spectrum.reserve(static_cast<size_t>((endFreq - startFreq) / step) + 1);
    
    ESP_LOGI(TAG, "Starting frequency scan on module %d: %.2f - %.2f MHz, step %.2f MHz, dwell %u ms",
             module, startFreq, endFreq, step, dwellTime);
    
    // Initialize CC1101 for scanning
    moduleCC1101State[module].changeFrequency(currentFreq);
}

void FrequencyAnalyzer::stopScan() {
    if (!active) {
        return;
    }
    
    ESP_LOGI(TAG, "Stopping frequency scan. Collected %zu points", spectrum.size());
    
    active = false;
    
    // Return module to idle
    moduleCC1101State[currentModule].setSidle();
}

void FrequencyAnalyzer::process() {
    if (!active) {
        return;
    }
    
    uint32_t now = millis();
    
    // Check if we should scan current frequency
    if ((now - lastScanTime) >= dwellTime) {
        scanCurrentFrequency();
        lastScanTime = now;
        
        // Move to next frequency
        currentFreq += step;
        
        if (currentFreq > endFreq) {
            // Scan complete
            ESP_LOGI(TAG, "Frequency scan complete: %zu points collected", spectrum.size());
            stopScan();
            return;
        }
        
        // Change to next frequency
        moduleCC1101State[currentModule].changeFrequency(currentFreq);
        
        // Small delay for frequency settling
        vTaskDelay(pdMS_TO_TICKS(1));
    }
}

void FrequencyAnalyzer::scanCurrentFrequency() {
    FrequencyPoint point;
    point.frequency = currentFreq;
    point.rssi = static_cast<int8_t>(moduleCC1101State[currentModule].getRssi());
    point.lqi = moduleCC1101State[currentModule].getLqi();
    point.timestamp = millis() - scanStartTime;
    
    spectrum.push_back(point);
    
    ESP_LOGD(TAG, "Scan point: %.2f MHz, RSSI=%d, LQI=%u", 
             point.frequency, point.rssi, point.lqi);
}

void FrequencyAnalyzer::clearSpectrum() {
    spectrum.clear();
}

bool FrequencyAnalyzer::findPeak(float& freq, int8_t& rssi) const {
    if (spectrum.empty()) {
        return false;
    }
    
    const FrequencyPoint* peak = &spectrum[0];
    
    for (const auto& point : spectrum) {
        if (point.rssi > peak->rssi) {
            peak = &point;
        }
    }
    
    freq = peak->frequency;
    rssi = peak->rssi;
    
    return true;
}


