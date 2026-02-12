#ifndef BRUTER_PROTOCOL_SMC5326_H
#define BRUTER_PROTOCOL_SMC5326_H

#include "protocol.h"

namespace bruter {

class protocol_smc5326 : public c_rf_protocol {
public:
    protocol_smc5326() {
        // T=320us. Similar al Princeton pero con espacios diferentes.
        transposition_table['0'] = {320, -960, 320, -960};
        transposition_table['1'] = {960, -320, 960, -320};
        transposition_table['F'] = {320, -960, 960, -320};
        pilot_period = {320, -11520};
        stop_bit = {};
    }
};

} // namespace bruter

#endif // BRUTER_PROTOCOL_SMC5326_H