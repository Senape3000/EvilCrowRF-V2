#ifndef BRUTER_PROTOCOL_NERO_H
#define BRUTER_PROTOCOL_NERO_H

#include "protocol.h"

namespace bruter {

// Nero motorized roller shutter remote protocol
// T=450us, used at 433.92 MHz and 434.42 MHz
class protocol_nero : public c_rf_protocol {
public:
    protocol_nero() {
        transposition_table['0'] = {450, -900};
        transposition_table['1'] = {900, -450};
        pilot_period = {450, -13500};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
