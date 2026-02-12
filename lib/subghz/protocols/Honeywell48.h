#ifndef HONEYWELL48_PROTOCOL_H
#define HONEYWELL48_PROTOCOL_H

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>

/**
 * Honeywell 48-bit protocol decoder/encoder
 * Used in Honeywell wireless security sensors
 * 48-bit data format with Manchester encoding
 */
class Honeywell48Protocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;
    uint32_t getRepeatCount() const override;
    std::string serialize() const override;

private:
    uint64_t key = 0;        // 48-bit key/data
    uint32_t te = 0;         // Timing element (pulse width in microseconds)
    uint32_t repeat = 0;     // Number of repeats
    uint32_t guard_time = 0; // Guard time between packets
    
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;
    void generatePulseData() const;
    void encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const;
};

std::unique_ptr<SubGhzProtocol> createHoneywell48Protocol();

#endif // HONEYWELL48_PROTOCOL_H

