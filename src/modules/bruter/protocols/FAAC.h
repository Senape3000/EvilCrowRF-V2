#ifndef BRUTER_PROTOCOL_FAAC_H
#define BRUTER_PROTOCOL_FAAC_H

#include "protocol.h"

namespace bruter {

class protocol_faac : public c_rf_protocol {
public:
    protocol_faac() {
        // Protocolo FAAC Fixed 12 bits
        transposition_table['0'] = {-1200, 400};
        transposition_table['1'] = {-400, 1200};
        pilot_period = {-16000, 400};
        stop_bit = {};
    }
};

} // namespace bruter

#endif // BRUTER_PROTOCOL_FAAC_H