#ifndef BRUTER_PROTOCOL_GATETX_H
#define BRUTER_PROTOCOL_GATETX_H

#include "protocol.h"

namespace bruter {

// GateTX universal gate remote protocol
// T=350us, inverted logic encoding at 433.92 MHz
class protocol_gate_tx : public c_rf_protocol {
public:
    protocol_gate_tx() {
        transposition_table['0'] = {-350, 700};
        transposition_table['1'] = {-700, 350};
        pilot_period = {-11000, 350};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
