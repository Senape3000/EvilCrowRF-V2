#ifndef BRUTER_PROTOCOL_NICEFLO_H
#define BRUTER_PROTOCOL_NICEFLO_H

#include "protocol.h"

namespace bruter {

class protocol_niceflo : public c_rf_protocol {
public:
    protocol_niceflo() {
        transposition_table['0'] = {-700, 1400};
        transposition_table['1'] = {-1400, 700};
        pilot_period = {-25200, 700};
        stop_bit = {};
    }
};

} // namespace bruter

#endif // BRUTER_PROTOCOL_NICEFLO_H