#ifndef BRUTER_PROTOCOL_STARLINE_H
#define BRUTER_PROTOCOL_STARLINE_H

#include "protocol.h"

namespace bruter {

// StarLine vehicle alarm remote protocol
// T=500us, inverted pilot period at 433.92 MHz
class protocol_starline : public c_rf_protocol {
public:
    protocol_starline() {
        transposition_table['0'] = {500, -1000};
        transposition_table['1'] = {1000, -500};
        pilot_period = {-10000, 500};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
