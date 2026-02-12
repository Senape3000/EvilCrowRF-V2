#ifndef CAME_PROTOCOL_H
#define CAME_PROTOCOL_H

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>

/**
 * CAME protocol decoder
 * Used for garage doors, gates (popular in Europe)
 * Format: Button code + Serial number
 */
class CAMEProtocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;
    uint32_t getRepeatCount() const override;
    std::string serialize() const override;

private:
    uint64_t button = 0;      // Button code (usually 4-8 bits)
    uint64_t serial = 0;      // Serial number (usually 20-28 bits)
    uint32_t te = 0;          // Timing element in microseconds
    uint32_t repeat = 0;      // Repeat count
    uint16_t bit_count = 0;   // Total bit count
    
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;
    void generatePulseData() const;
    
    // Helper to encode bit in CAME format (Manchester-like)
    void encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const;
};

// Factory function
std::unique_ptr<SubGhzProtocol> createCAMEProtocol();

#endif // CAME_PROTOCOL_H


