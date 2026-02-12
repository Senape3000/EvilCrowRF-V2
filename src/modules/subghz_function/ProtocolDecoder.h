#ifndef PROTOCOL_DECODER_H
#define PROTOCOL_DECODER_H

#include <string>
#include <vector>
#include <cstdint>
#include <memory>
#include "SubGhzProtocol.h"

/**
 * Real-time protocol decoder for SubGHz signals
 * Attempts to decode RAW samples into known protocols
 */
class ProtocolDecoder {
public:
    struct DecodedSignal {
        std::string protocol;
        uint64_t data = 0;
        uint32_t bitCount = 0;
        uint32_t te = 0;  // Timing element (microseconds)
        int rssi = 0;
        float frequency = 0.0f;
        uint32_t repeat = 1;
        
        // Additional protocol-specific data
        std::string key;  // Hex string representation
        
        bool isValid() const {
            return !protocol.empty() && bitCount > 0;
        }
    };
    
    /**
     * Attempt to decode RAW pulse samples into a known protocol
     * @param samples Vector of pulse durations in microseconds (positive = high, negative = low)
     * @param frequency Frequency in MHz
     * @param rssi RSSI value
     * @param result Output decoded signal
     * @return true if successfully decoded, false otherwise
     */
    static bool decode(const std::vector<unsigned long>& samples, 
                      float frequency, 
                      int rssi,
                      DecodedSignal& result);
    
    /**
     * Convert RAW samples to pulse data format (duration, level)
     * Helper function for protocol matching
     */
    static std::vector<std::pair<uint32_t, bool>> samplesToPulses(
        const std::vector<unsigned long>& samples);
    
private:
    /**
     * Try to match samples against a specific protocol
     * Creates a temporary protocol instance and attempts decoding
     */
    static bool tryProtocol(const std::string& protocolName,
                           const std::vector<std::pair<uint32_t, bool>>& pulses,
                           DecodedSignal& result);
    
    /**
     * Extract basic signal parameters from RAW samples
     */
    static void analyzeSignal(const std::vector<unsigned long>& samples,
                             DecodedSignal& result);
};

#endif // PROTOCOL_DECODER_H


