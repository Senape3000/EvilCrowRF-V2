#ifndef BRUTER_PROTOCOL_CHAMBERLAIN_H
#define BRUTER_PROTOCOL_CHAMBERLAIN_H

#include "protocol.h"

namespace bruter {

class protocol_chamberlain : public c_rf_protocol {
public:
    protocol_chamberlain() {
        transposition_table['0'] = {-870, 430};
        transposition_table['1'] = {-430, 870};
        pilot_period = {};
        stop_bit = {-3000, 1000};
    }
};

} // namespace bruter

#endif // BRUTER_PROTOCOL_CHAMBERLAIN_H