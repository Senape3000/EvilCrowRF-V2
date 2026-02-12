#ifndef BRUTER_PROTOCOL_PRASTEL_H
#define BRUTER_PROTOCOL_PRASTEL_H

#include "protocol.h"

namespace bruter {

// Prastel gate/barrier remote protocol (France)
// T=400us, inverted logic encoding at 433.92 MHz
class protocol_prastel : public c_rf_protocol {
public:
    protocol_prastel() {
        transposition_table['0'] = {-400, 800};
        transposition_table['1'] = {-800, 400};
        pilot_period = {-12000, 400};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
