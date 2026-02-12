#ifndef BRUTER_PROTOCOL_DOITRAND_H
#define BRUTER_PROTOCOL_DOITRAND_H

#include "protocol.h"

namespace bruter {

// Doitrand motorized gate remote protocol (France)
// T=400us, inverted logic encoding
class protocol_doitrand : public c_rf_protocol {
public:
    protocol_doitrand() {
        transposition_table['0'] = {-400, 800};
        transposition_table['1'] = {-800, 400};
        pilot_period = {-12000, 400};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
