#ifndef BRUTER_PROTOCOL_MAGELLEN_H
#define BRUTER_PROTOCOL_MAGELLEN_H

#include "protocol.h"

namespace bruter {

// Magellen security remote protocol
// T=400us, standard binary encoding at 433.92 MHz
class protocol_magellen : public c_rf_protocol {
public:
    protocol_magellen() {
        transposition_table['0'] = {400, -800};
        transposition_table['1'] = {800, -400};
        pilot_period = {400, -12000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
