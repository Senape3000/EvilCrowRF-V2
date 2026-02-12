#pragma once
#include "protocol.h"

namespace bruter {

class protocol_princeton : public c_rf_protocol {
public:
    protocol_princeton() {
        // T=350us típico
        transposition_table['0'] = {350, -1050, 350, -1050}; // 00
        transposition_table['1'] = {1050, -350, 1050, -350}; // 11
        transposition_table['F'] = {350, -1050, 1050, -350}; // 01 (Float)
        pilot_period = {350, -10850};
        stop_bit = {};
    }
};

} // namespace bruter