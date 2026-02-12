#ifndef BRUTER_PROTOCOL_DOOYA_H
#define BRUTER_PROTOCOL_DOOYA_H

#include "protocol.h"

namespace bruter {

// Dooya motorized blinds/awnings remote protocol
// T=350us, typically uses 24-bit codes at 433.92 MHz
class protocol_dooya : public c_rf_protocol {
public:
    protocol_dooya() {
        transposition_table['0'] = {350, -700};
        transposition_table['1'] = {700, -350};
        pilot_period = {350, -7000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
