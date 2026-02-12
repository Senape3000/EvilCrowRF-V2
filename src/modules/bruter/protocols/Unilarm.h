#ifndef BRUTER_PROTOCOL_UNILARM_H
#define BRUTER_PROTOCOL_UNILARM_H

#include "protocol.h"

namespace bruter {

// Unilarm alarm/security remote protocol
// T=350us, 4-element transposition (similar to Princeton)
// Used at 433.42 MHz
class protocol_unilarm : public c_rf_protocol {
public:
    protocol_unilarm() {
        transposition_table['0'] = {350, -1050, 350, -1050};
        transposition_table['1'] = {1050, -350, 1050, -350};
        pilot_period = {350, -10850};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
