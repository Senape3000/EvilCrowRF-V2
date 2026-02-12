#ifndef BinRAW_Protocol_h
#define BinRAW_Protocol_h

#include "SubGhzProtocol.h"
#include "compatibility.h"
#include <sstream>
#include <vector>
#include <utility>
#include <memory>

class BinRAWProtocol : public SubGhzProtocol {
public:
    bool parse(File &file) override;
    std::vector<std::pair<uint32_t, bool>> getPulseData() const override;  // Marked as const
    uint32_t getRepeatCount() const override;  // Marked as const
    std::string serialize() const override;  // Marked as const

private:
    mutable std::vector<std::pair<uint32_t, bool>> pulseData;  // Mutable to allow modification in const context
    void generatePulseData(const std::vector<uint8_t>& rawData, uint32_t bitRaw, uint32_t te) const;  // Marked as const

    uint32_t bitCount = 0;
    uint32_t te = 0;
};

// Factory function
std::unique_ptr<SubGhzProtocol> createBinRAWProtocol();

#endif // BinRAW_Protocol_h
