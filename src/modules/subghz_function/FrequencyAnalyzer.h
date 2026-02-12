#ifndef FREQUENCY_ANALYZER_H
#define FREQUENCY_ANALYZER_H

#include <vector>
#include <cstdint>
#include <string>
#include "config.h"
#include "modules/CC1101_driver/CC1101_Module.h"

/**
 * Frequency analyzer / spectrum scanner
 * Scans frequency range and collects RSSI data for visualization
 */
struct FrequencyPoint {
    float frequency;
    int8_t rssi;
    uint8_t lqi;        // Link Quality Indicator
    uint32_t timestamp; // ms since start of scan
};

class FrequencyAnalyzer {
public:
    FrequencyAnalyzer();
    
    /**
     * Start spectrum scan
     * @param module CC1101 module to use
     * @param startFreq Start frequency in MHz
     * @param endFreq End frequency in MHz
     * @param step Step size in MHz
     * @param dwellTime Time to spend on each frequency in ms
     */
    void startScan(int module, float startFreq, float endFreq, float step, uint32_t dwellTime = 50);
    
    /**
     * Stop scan
     */
    void stopScan();
    
    /**
     * Process scan (call periodically from worker loop)
     */
    void process();
    
    /**
     * Check if scan is active
     */
    bool isActive() const { return active; }
    
    /**
     * Get current spectrum data
     */
    std::vector<FrequencyPoint> getSpectrum() const { return spectrum; }
    
    /**
     * Clear spectrum data
     */
    void clearSpectrum();
    
    /**
     * Find peak frequency (highest RSSI)
     */
    bool findPeak(float& freq, int8_t& rssi) const;
    
private:
    bool active;
    int currentModule;
    float startFreq;
    float endFreq;
    float step;
    float currentFreq;
    uint32_t dwellTime;
    uint32_t lastScanTime;
    uint32_t scanStartTime;
    
    std::vector<FrequencyPoint> spectrum;
    
    void scanCurrentFrequency();
};

extern FrequencyAnalyzer frequencyAnalyzer;

#endif // FREQUENCY_ANALYZER_H


