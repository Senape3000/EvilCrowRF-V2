#ifndef BRUTER_PROTOCOL_HORMANN_H
#define BRUTER_PROTOCOL_HORMANN_H

#include "protocol.h"

namespace bruter {

// Hormann garage door remote protocol (Germany)
// T=500us, classic grey remote with blue (868) or yellow (433) buttons
// Typically used at 868.35 MHz
class protocol_hormann : public c_rf_protocol {
public:
    protocol_hormann() {
        transposition_table['0'] = {500, -500};
        transposition_table['1'] = {1000, -500};
        pilot_period = {500, -10000};
        stop_bit = {};
    }
};

} // namespace bruter
#endif
