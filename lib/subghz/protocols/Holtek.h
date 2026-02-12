#ifndef HOLTEK_PROTOCOL_H
#define HOLTEK_PROTOCOL_H

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>

/**
 * Holtek HT12X protocol decoder
 * Common in Chinese-made remote controls
 * 12-bit address + 4-bit data format
 */
class HoltekProtocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;
    uint32_t getRepeatCount() const override;
    std::string serialize() const override;

private:
    uint16_t address = 0;     // 12-bit address
    uint8_t data = 0;         // 4-bit data
    uint32_t te = 0;
    uint32_t repeat = 0;
    
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;
    void generatePulseData() const;
    void encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const;
};

std::unique_ptr<SubGhzProtocol> createHoltekProtocol();

#endif // HOLTEK_PROTOCOL_H


