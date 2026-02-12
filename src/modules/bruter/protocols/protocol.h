#ifndef BRUTER_PROTOCOL_H
#define BRUTER_PROTOCOL_H

#include <map>
#include <stdint.h>
#include <vector>

namespace bruter {

// Base class for all RF protocols
class c_rf_protocol {
public:
    std::map<char, std::vector<int>> transposition_table;
    std::vector<int> pilot_period;
    std::vector<int> stop_bit;

    c_rf_protocol() = default;
    virtual ~c_rf_protocol() = default;
};

} // namespace bruter

#endif // BRUTER_PROTOCOL_H