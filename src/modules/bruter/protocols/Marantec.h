#ifndef BRUTER_PROTOCOL_MARANTEC_H
#define BRUTER_PROTOCOL_MARANTEC_H

#include "protocol.h"

namespace bruter {

// Marantec garage door remote protocol (Germany)
// T=600us, high-precision protocol with long preamble
// Typically used at 868.35 MHz, includes stop bit
class protocol_marantec : public c_rf_protocol {
public:
    protocol_marantec() {
        transposition_table['0'] = {600, -1200};
        transposition_table['1'] = {1200, -600};
        pilot_period = {600, -15000};
        stop_bit = {600, -25000};
    }
};

} // namespace bruter
#endif
