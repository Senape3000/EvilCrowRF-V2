#ifndef BRUTER_PROTOCOL_INTERTECHNOV3_H
#define BRUTER_PROTOCOL_INTERTECHNOV3_H

#include "protocol.h"

namespace bruter {

// Intertechno V3 home automation protocol
// T=250us, specific PWM encoding, 32-bit codes at 433.92 MHz
// 4-element transposition table for each bit value
class protocol_intertechno_v3 : public c_rf_protocol {
public:
    protocol_intertechno_v3() {
        transposition_table['0'] = {250, -250, 250, -1250};
        transposition_table['1'] = {250, -1250, 250, -250};
        pilot_period = {250, -2500};
        stop_bit = {250, -10000};
    }
};

} // namespace bruter
#endif
