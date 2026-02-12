#include "BinRAW.h"
#include <iostream>

bool BinRAWProtocol::parse(File &file) {
    pulseData.clear();
    std::string line;
    uint32_t bitRaw = 0;
    std::vector<uint8_t> rawData;
    
    while (file.available()) {
        line = file.readStringUntil('\n').c_str();
        
        if (line.find("Bit:") != std::string::npos) {
            std::istringstream iss(line.substr(line.find("Bit:") + 4));
            iss >> bitCount;
        } else if (line.find("TE:") != std::string::npos) {
            std::istringstream iss(line.substr(line.find("TE:") + 3));
            iss >> te;
        } else if (line.find("Bit_RAW:") != std::string::npos) {
            std::istringstream iss(line.substr(line.find("Bit_RAW:") + 8));
            iss >> bitRaw;
        } else if (line.find("Data_RAW:") != std::string::npos) {
            std::istringstream iss(line.substr(line.find("Data_RAW:") + 9));
            uint32_t byte;
            while (iss >> std::hex >> byte) {
                rawData.push_back(static_cast<uint8_t>(byte));
            }
            generatePulseData(rawData, bitRaw, te);
            rawData.clear();
        }
    }
    return true;
}

std::vector<std::pair<uint32_t, bool>> BinRAWProtocol::getPulseData() const {
    return pulseData;
}

uint32_t BinRAWProtocol::getRepeatCount() const {
    return 1;
}

std::string BinRAWProtocol::serialize() const {
    std::ostringstream oss;
    oss << "Protocol: BinRAW\n";
    oss << "Bit: " << bitCount << "\n";
    oss << "TE: " << te << "\n";
    oss << "Bit_RAW: " << pulseData.size() / 2 << "\n";  // Assuming pulseData is always even
    oss << "Data_RAW:";
    for (const auto& pulse : pulseData) {
        int32_t duration = pulse.second ? static_cast<int32_t>(pulse.first) : -static_cast<int32_t>(pulse.first);
        oss << " " << std::hex << duration;
    }
    return oss.str();
}

void BinRAWProtocol::generatePulseData(const std::vector<uint8_t>& rawData, uint32_t bitRaw, uint32_t te) const {
    bool currentState = false;
    uint32_t currentDuration = 0;

    for (uint32_t i = 0; i < bitRaw; ++i) {
        bool bit = (rawData[i / 8] >> (7 - (i % 8))) & 0x01;
        if (bit == currentState) {
            currentDuration += te;
        } else {
            if (currentDuration > 0) {
                pulseData.emplace_back(currentDuration, currentState);
            }
            currentState = bit;
            currentDuration = te;
        }
    }
    // Add the last pulse if it exists
    if (currentDuration > 0) {
        pulseData.emplace_back(currentDuration, currentState);
    }
}

std::unique_ptr<SubGhzProtocol> createBinRAWProtocol() {
    return std::make_unique<BinRAWProtocol>();
}
