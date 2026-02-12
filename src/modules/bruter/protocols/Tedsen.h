#ifndef BRUTER_PROTOCOL_TEDSEN_H
#define BRUTER_PROTOCOL_TEDSEN_H

#include "protocol.h"

namespace bruter {

// Tedsen garage door remote protocol (Germany)
// T=600us, robust protocol with inverted pilot period
class protocol_tedsen : public c_rf_protocol {
public:
    protocol_tedsen() {
        transposition_table['0'] = {600, -1200};
        transposition_table['1'] = {1200, -600};
        pilot_period = {-15000, 600};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
