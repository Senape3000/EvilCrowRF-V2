#ifndef BRUTER_PROTOCOL_FIREFLY_H
#define BRUTER_PROTOCOL_FIREFLY_H

#include "protocol.h"

namespace bruter {

// Firefly garage door remote protocol (USA)
// T=400us, typically uses 10-bit codes at 300 MHz
class protocol_firefly : public c_rf_protocol {
public:
    protocol_firefly() {
        transposition_table['0'] = {400, -800};
        transposition_table['1'] = {800, -400};
        pilot_period = {400, -12000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
