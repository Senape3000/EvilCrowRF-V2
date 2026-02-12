#ifndef BRUTER_PROTOCOL_CLEMSA_H
#define BRUTER_PROTOCOL_CLEMSA_H

#include "protocol.h"

namespace bruter {

// Clemsa garage door remote protocol (Spain)
// T=400us, common in older fixed-code models
// Inverted logic: '0' starts LOW, '1' starts LOW
class protocol_clemsa : public c_rf_protocol {
public:
    protocol_clemsa() {
        transposition_table['0'] = {-400, 800};
        transposition_table['1'] = {-800, 400};
        pilot_period = {-12000, 400};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
