#ifndef BRUTER_PROTOCOL_PHOENIXV2_H
#define BRUTER_PROTOCOL_PHOENIXV2_H

#include "protocol.h"

namespace bruter {

// Phoenix V2 garage door remote protocol (Europe)
// T=500us, inverted logic, commonly used in European garage systems
class protocol_phoenix_v2 : public c_rf_protocol {
public:
    protocol_phoenix_v2() {
        transposition_table['0'] = {-500, 1000};
        transposition_table['1'] = {-1000, 500};
        pilot_period = {-15000, 500};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
