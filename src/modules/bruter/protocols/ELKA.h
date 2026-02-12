#ifndef BRUTER_PROTOCOL_ELKA_H
#define BRUTER_PROTOCOL_ELKA_H

#include "protocol.h"

namespace bruter {

// ELKA gate/barrier remote protocol
// T=400us, standard binary encoding at 433.92 MHz
class protocol_elka : public c_rf_protocol {
public:
    protocol_elka() {
        transposition_table['0'] = {400, -800};
        transposition_table['1'] = {800, -400};
        pilot_period = {400, -12000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
