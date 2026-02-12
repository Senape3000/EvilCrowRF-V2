#ifndef Princeton_Protocol_h
#define Princeton_Protocol_h

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>

#define PRINCETON_GUARD_TIME_DEFALUT 30 //GUARD_TIME = PRINCETON_GUARD_TIME_DEFALUT * TE
// Guard Time value should be between 15 -> 72 otherwise default value will be used

class PrincetonProtocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;
    uint32_t getRepeatCount() const override; 
    std::string serialize() const override;

private:
    uint64_t key = 0;
    uint32_t te = 0;
    uint32_t repeat = 0;
    uint16_t bit_count = 0;
    uint32_t guard_time = PRINCETON_GUARD_TIME_DEFALUT;
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;
    void generatePulseData() const;
};

// Factory function
std::unique_ptr<SubGhzProtocol> createPrincetonProtocol();

#endif // Princeton_Protocol_h
