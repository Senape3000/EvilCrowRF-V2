#ifndef GATETX_PROTOCOL_H
#define GATETX_PROTOCOL_H

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>

/**
 * Gate TX protocol decoder
 * Universal gate/garage door protocol
 */
class GateTXProtocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;
    uint32_t getRepeatCount() const override;
    std::string serialize() const override;

private:
    uint64_t data = 0;        // Combined data
    uint32_t te = 0;
    uint32_t repeat = 0;
    uint16_t bit_count = 0;
    
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;
    void generatePulseData() const;
    void encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const;
};

std::unique_ptr<SubGhzProtocol> createGateTXProtocol();

#endif // GATETX_PROTOCOL_H


