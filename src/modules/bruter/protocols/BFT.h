#ifndef BRUTER_PROTOCOL_BFT_H
#define BRUTER_PROTOCOL_BFT_H

#include "protocol.h"

namespace bruter {

class protocol_bft : public c_rf_protocol {
public:
    protocol_bft() {
        // T=400us.
        transposition_table['0'] = {-400, 800};
        transposition_table['1'] = {-800, 400};
        pilot_period = {-12000, 400};
        stop_bit = {};
    }
};

} // namespace bruter

#endif // BRUTER_PROTOCOL_BFT_H