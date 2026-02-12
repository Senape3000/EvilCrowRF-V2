#ifndef BRUTER_PROTOCOL_PHOX_H
#define BRUTER_PROTOCOL_PHOX_H

#include "protocol.h"

namespace bruter {

// Phox gate remote protocol
// T=400us, inverted logic encoding at 433.92 MHz
class protocol_phox : public c_rf_protocol {
public:
    protocol_phox() {
        transposition_table['0'] = {-400, 800};
        transposition_table['1'] = {-800, 400};
        pilot_period = {-12000, 400};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
