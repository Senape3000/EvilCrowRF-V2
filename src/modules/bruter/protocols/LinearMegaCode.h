#ifndef BRUTER_PROTOCOL_LINEAR_MEGACODE_H
#define BRUTER_PROTOCOL_LINEAR_MEGACODE_H

#include "protocol.h"

namespace bruter {

// Linear MegaCode garage door remote protocol (USA)
// T=500us, 24-bit codes at 318 MHz
class protocol_linear_megacode : public c_rf_protocol {
public:
    protocol_linear_megacode() {
        transposition_table['0'] = {500, -1000};
        transposition_table['1'] = {1000, -500};
        pilot_period = {500, -15000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
