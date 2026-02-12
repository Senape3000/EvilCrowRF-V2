#ifndef BRUTER_PROTOCOL_BERNER_H
#define BRUTER_PROTOCOL_BERNER_H

#include "protocol.h"

namespace bruter {

// Berner garage door remote protocol
// T=400us, standard binary encoding
// Works at 868.35 MHz and 433.92 MHz depending on model
class protocol_berner : public c_rf_protocol {
public:
    protocol_berner() {
        transposition_table['0'] = {400, -800};
        transposition_table['1'] = {800, -400};
        pilot_period = {400, -12000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
