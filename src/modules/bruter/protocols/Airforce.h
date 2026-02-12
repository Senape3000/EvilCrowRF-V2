#ifndef BRUTER_PROTOCOL_AIRFORCE_H
#define BRUTER_PROTOCOL_AIRFORCE_H

#include "protocol.h"

namespace bruter {

// Airforce remote protocol
// Similar to Princeton but with different pilot period
// T=350us, 4-element transposition (binary attack), 433.92 MHz
class protocol_airforce : public c_rf_protocol {
public:
    protocol_airforce() {
        transposition_table['0'] = {350, -1050, 350, -1050};
        transposition_table['1'] = {1050, -350, 1050, -350};
        pilot_period = {350, -10850};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
