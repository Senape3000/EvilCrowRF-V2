#pragma once
#include "protocol.h"

namespace bruter {

/**
 * Runtime-configurable generic OOK protocol for De Bruijn and universal sweeps.
 *
 * @param te    Base time element in microseconds
 * @param ratio Pulse width ratio (2 = 1:2 for old PT2262, 3 = 1:3 for EV1527)
 */
class protocol_dynamic : public c_rf_protocol {
public:
    protocol_dynamic(int te, int ratio = 3) {
        int shortPulse = te;
        int longPulse  = te * ratio;

        // Generic OOK: 0 = short HIGH + long LOW, 1 = long HIGH + short LOW
        transposition_table['0'] = { shortPulse, -longPulse };
        transposition_table['1'] = { longPulse,  -shortPulse };

        // Standard sync: 1T HIGH + 31T LOW
        pilot_period = { shortPulse, -(te * 31) };
        stop_bit = {};
    }
};

} // namespace bruter
