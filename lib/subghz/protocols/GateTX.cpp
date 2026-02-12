#include "GateTX.h"

bool GateTXProtocol::parse(File &file) {
    char buffer[256];
    while (file.available()) {
        int len = file.readBytesUntil('\n', buffer, sizeof(buffer));
        buffer[len] = '\0';
        std::string line(buffer);

        std::istringstream iss(line);
        std::string key, value;
        if (std::getline(iss, key, ':') && std::getline(iss, value)) {
            key = key.substr(0, key.find_first_of(" \t"));
            value = value.substr(value.find_first_not_of(" \t"));

            if (key == "Data" || key == "Key") {
                uint64_t parsed;
                if (readHexKey(value, parsed)) {
                    this->data = parsed;
                }
            } else if (key == "TE") {
                uint32_t te;
                if (readUint32Decimal(value, te)) {
                    this->te = te;
                }
            } else if (key == "Repeat") {
                uint32_t repeat;
                if (readUint32Decimal(value, repeat)) {
                    this->repeat = repeat;
                }
            } else if (key == "Bit") {
                uint32_t bit;
                if (readUint32Decimal(value, bit)) {
                    this->bit_count = (uint16_t)bit;
                }
            }
        }
    }

    if (te == 0) {
        te = 500;  // 500us typical for Gate TX
    }

    if (repeat == 0) {
        repeat = 4;
    }

    return data != 0 && te != 0;
}

void GateTXProtocol::encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const {
    // Gate TX simple encoding
    if (bit) {
        pulses.push_back(std::make_pair(te * 2, true));
        pulses.push_back(std::make_pair(te, false));
    } else {
        pulses.push_back(std::make_pair(te, true));
        pulses.push_back(std::make_pair(te * 2, false));
    }
}

std::vector<std::pair<uint32_t, bool>> GateTXProtocol::getPulseData() const {
    if (pulseData.empty()) {
        generatePulseData();
    }
    return pulseData;
}

void GateTXProtocol::generatePulseData() const {
    pulseData.clear();
    
    if (te == 0) {
        return;
    }

    uint16_t totalBits = bit_count;
    if (totalBits == 0) {
        totalBits = 24;  // Default 24 bits
    }

    // Preamble
    for (int i = 0; i < 2; i++) {
        pulseData.push_back(std::make_pair(te * 4, true));
        pulseData.push_back(std::make_pair(te * 4, false));
    }

    // Encode data
    for (int i = totalBits - 1; i >= 0; i--) {
        bool bit = (data >> i) & 0x01;
        encodeBit(bit, pulseData);
    }

    // Footer
    pulseData.push_back(std::make_pair(te * 2, true));
    pulseData.push_back(std::make_pair(te * 8, false));
}

uint32_t GateTXProtocol::getRepeatCount() const {
    return repeat > 0 ? repeat : 4;
}

std::string GateTXProtocol::serialize() const {
    std::ostringstream oss;
    if (bit_count > 0) {
        oss << "Bit: " << bit_count << "\r\n";
    }
    oss << "Data: " << std::hex << data << "\r\n";
    if (te > 0) {
        oss << "TE: " << te << "\r\n";
    }
    oss << "Repeat: " << getRepeatCount() << "\n";
    return oss.str();
}

std::unique_ptr<SubGhzProtocol> createGateTXProtocol() {
    return std::make_unique<GateTXProtocol>();
}


