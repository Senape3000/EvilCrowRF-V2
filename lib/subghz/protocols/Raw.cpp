#include "Raw.h"
#include <iostream>  // for debugging

bool RawProtocol::parse(File &file) {
    std::string line;
    while (file.available()) {
        line = file.readStringUntil('\n').c_str();
        if (line.find("RAW_Data:") != std::string::npos) {
            std::istringstream iss(line.substr(line.find("RAW_Data:") + 9));
            int32_t duration;
            while (iss >> duration) {
                if (duration != 0) {
                    bool pinState = (duration > 0);
                    pulseData.emplace_back(abs(duration), pinState);
                }
            }
        }
    }
    return true;
}

std::vector<std::pair<uint32_t, bool>> RawProtocol::getPulseData() const {
    return pulseData;
}

uint32_t RawProtocol::getRepeatCount() const {
    return 1;
}

std::string RawProtocol::serialize() const {
    std::ostringstream oss;
    oss << "RAW_Data:";
    for (const auto& pulse : pulseData) {
        int32_t duration = pulse.second ? static_cast<int32_t>(pulse.first) : -static_cast<int32_t>(pulse.first);
        oss << " " << duration;
    }
    return oss.str();
}

std::unique_ptr<SubGhzProtocol> createRawProtocol() {
    return std::make_unique<RawProtocol>();
}
