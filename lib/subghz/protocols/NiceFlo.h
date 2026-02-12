#ifndef NICEFLO_PROTOCOL_H
#define NICEFLO_PROTOCOL_H

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>

/**
 * Nice FLO protocol decoder
 * Used for garage doors and gates (popular in Europe)
 * Similar to CAME but with different encoding
 */
class NiceFloProtocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;
    uint32_t getRepeatCount() const override;
    std::string serialize() const override;

private:
    uint64_t button = 0;
    uint64_t serial = 0;
    uint32_t te = 0;
    uint32_t repeat = 0;
    uint16_t bit_count = 0;
    
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;
    void generatePulseData() const;
    void encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const;
};

std::unique_ptr<SubGhzProtocol> createNiceFloProtocol();

#endif // NICEFLO_PROTOCOL_H


