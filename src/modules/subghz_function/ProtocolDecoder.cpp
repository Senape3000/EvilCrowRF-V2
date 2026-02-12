#include "ProtocolDecoder.h"
#include "SubGhzProtocol.h"
#include "esp_log.h"

static const char* TAG = "ProtocolDecoder";

// Minimum samples required for decoding
static constexpr size_t MIN_SAMPLES_FOR_DECODE = 10;

// Maximum samples to analyze (for performance)
static constexpr size_t MAX_SAMPLES_FOR_DECODE = 5000;

// Protocols to try in order (most common first)
static const char* PROTOCOL_ORDER[] = {
    "RAW",       // Fallback - always works
    "Princeton",
    "BinRAW",
    "CAME",
    "Nice FLO",
    "Gate TX",
    "Holtek",
};

static constexpr size_t PROTOCOL_ORDER_SIZE = sizeof(PROTOCOL_ORDER) / sizeof(PROTOCOL_ORDER[0]);

std::vector<std::pair<uint32_t, bool>> ProtocolDecoder::samplesToPulses(
    const std::vector<unsigned long>& samples) {
    
    std::vector<std::pair<uint32_t, bool>> pulses;
    
    if (samples.empty()) {
        return pulses;
    }
    
    // Estimate capacity to avoid reallocations
    pulses.reserve(samples.size());
    
    // Convert alternating samples to pulse data
    // Sample format: positive = high duration, next = low duration (or vice versa)
    // We need to detect the pattern
    
    bool currentLevel = true;  // Assume starting with high
    for (size_t i = 0; i < samples.size(); i++) {
        uint32_t duration = static_cast<uint32_t>(samples[i]);
        
        // Filter out noise (very short pulses)
        if (duration < 50) {  // Less than 50us is likely noise
            continue;
        }
        
        // Cap duration to prevent overflow
        if (duration > 100000) {  // Max 100ms pulse
            duration = 100000;
        }
        
        pulses.emplace_back(duration, currentLevel);
        currentLevel = !currentLevel;
    }
    
    return pulses;
}

void ProtocolDecoder::analyzeSignal(const std::vector<unsigned long>& samples,
                                   DecodedSignal& result) {
    if (samples.empty()) {
        return;
    }
    
    // Calculate average pulse duration (estimate of TE)
    uint64_t totalDuration = 0;
    size_t count = 0;
    
    // Limit analysis to first part for performance
    size_t analyzeCount = samples.size() < MAX_SAMPLES_FOR_DECODE ? samples.size() : MAX_SAMPLES_FOR_DECODE;
    
    for (size_t i = 0; i < analyzeCount; i++) {
        if (samples[i] > 50 && samples[i] < 100000) {  // Filter noise and outliers
            totalDuration += samples[i];
            count++;
        }
    }
    
    if (count > 0) {
        result.te = static_cast<uint32_t>(totalDuration / count);
    }
    
    // Estimate bit count (rough approximation)
    if (result.te > 0) {
        uint64_t totalTime = 0;
        for (size_t i = 0; i < analyzeCount && i < 1000; i++) {  // Analyze first 1000 samples
            totalTime += samples[i];
        }
        result.bitCount = static_cast<uint32_t>(totalTime / (result.te * 2));  // Approximate: 2 pulses per bit
    }
}

bool ProtocolDecoder::tryProtocol(const std::string& protocolName,
                                 const std::vector<std::pair<uint32_t, bool>>& pulses,
                                 DecodedSignal& result) {
    
    // Create protocol instance
    std::unique_ptr<SubGhzProtocol> protocol(SubGhzProtocol::create(protocolName));
    
    if (!protocol) {
        // Protocol not available
        return false;
    }
    
    // For RAW protocol, it always succeeds (fallback)
    if (protocolName == "RAW") {
        result.protocol = "RAW";
        result.bitCount = pulses.size();
        return true;
    }
    
    // For other protocols, we would need to:
    // 1. Create a temporary .sub file in memory
    // 2. Write pulse data in RAW format
    // 3. Parse it with the protocol
    // 
    // However, this is complex. Instead, for now we'll do a simpler approach:
    // - Try to estimate if samples match protocol characteristics
    // - For protocols that support it, directly decode from pulses
    
    // Basic validation: check if we have enough pulses
    if (pulses.size() < MIN_SAMPLES_FOR_DECODE) {
        return false;
    }
    
    // For Princeton and similar protocols, we can try pattern matching
    // This is a simplified version - full implementation would require
    // protocol-specific decoders
    
    // For now, only RAW is guaranteed to work
    // Other protocols require file-based parsing (existing SubFileParser)
    
    return false;
}

bool ProtocolDecoder::decode(const std::vector<unsigned long>& samples,
                            float frequency,
                            int rssi,
                            DecodedSignal& result) {
    
    // Initialize result
    result = DecodedSignal();
    result.frequency = frequency;
    result.rssi = rssi;
    
    // Check minimum requirements
    if (samples.empty() || samples.size() < MIN_SAMPLES_FOR_DECODE) {
        ESP_LOGD(TAG, "Not enough samples for decoding: %zu", samples.size());
        return false;
    }
    
    ESP_LOGD(TAG, "Attempting to decode %zu samples at %.2f MHz, RSSI=%d", 
             samples.size(), frequency, rssi);
    
    // Analyze signal to extract basic parameters
    analyzeSignal(samples, result);
    
    // Convert samples to pulse format
    std::vector<std::pair<uint32_t, bool>> pulses = samplesToPulses(samples);
    
    if (pulses.empty()) {
        ESP_LOGD(TAG, "No valid pulses extracted from samples");
        return false;
    }
    
    ESP_LOGD(TAG, "Extracted %zu pulses, TE≈%u us", pulses.size(), result.te);
    
    // Try protocols in order
    for (size_t i = 0; i < PROTOCOL_ORDER_SIZE; i++) {
        const char* protocolName = PROTOCOL_ORDER[i];
        
        ESP_LOGD(TAG, "Trying protocol: %s", protocolName);
        
        DecodedSignal candidate;
        candidate.frequency = frequency;
        candidate.rssi = rssi;
        
        if (tryProtocol(protocolName, pulses, candidate)) {
            // Success!
            result = candidate;
            result.repeat = candidate.repeat > 0 ? candidate.repeat : 1;
            
            ESP_LOGI(TAG, "Decoded as %s: %zu bits, TE=%u us, repeat=%u", 
                     result.protocol.c_str(), result.bitCount, result.te, result.repeat);
            
            return true;
        }
    }
    
    // No protocol matched - return as RAW
    result.protocol = "RAW";
    result.bitCount = pulses.size();
    result.repeat = 1;
    
    ESP_LOGD(TAG, "No specific protocol matched, treating as RAW");
    return true;  // RAW is always valid
}

