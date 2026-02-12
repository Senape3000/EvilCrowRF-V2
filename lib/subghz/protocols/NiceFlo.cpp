#include "NiceFlo.h"

bool NiceFloProtocol::parse(File &file) {
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

            if (key == "Button") {
                uint64_t parsed;
                if (readHexKey(value, parsed)) {
                    this->button = parsed;
                }
            } else if (key == "Serial") {
                uint64_t parsed;
                if (readHexKey(value, parsed)) {
                    this->serial = parsed;
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
        te = 320;  // 320us typical for Nice FLO
    }

    if (repeat == 0) {
        repeat = 3;
    }

    return (button != 0 || serial != 0) && te != 0;
}

void NiceFloProtocol::encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const {
    // Nice FLO uses different encoding than CAME
    if (bit) {
        pulses.push_back(std::make_pair(te * 3, true));
        pulses.push_back(std::make_pair(te, false));
    } else {
        pulses.push_back(std::make_pair(te, true));
        pulses.push_back(std::make_pair(te * 2, false));
    }
}

std::vector<std::pair<uint32_t, bool>> NiceFloProtocol::getPulseData() const {
    if (pulseData.empty()) {
        generatePulseData();
    }
    return pulseData;
}

void NiceFloProtocol::generatePulseData() const {
    pulseData.clear();
    
    if (te == 0) {
        return;
    }

    uint16_t totalBits = bit_count;
    if (totalBits == 0) {
        totalBits = 24;  // Typical Nice FLO is 24 bits
    }

    // Preamble
    pulseData.push_back(std::make_pair(te * 8, true));
    pulseData.push_back(std::make_pair(te * 4, false));

    // Encode data
    uint64_t data = (serial << 4) | (button & 0x0F);
    
    for (int i = totalBits - 1; i >= 0; i--) {
        bool bit = (data >> i) & 0x01;
        encodeBit(bit, pulseData);
    }

    // Footer
    pulseData.push_back(std::make_pair(te, true));
    pulseData.push_back(std::make_pair(te * 6, false));
}

uint32_t NiceFloProtocol::getRepeatCount() const {
    return repeat > 0 ? repeat : 3;
}

std::string NiceFloProtocol::serialize() const {
    std::ostringstream oss;
    if (bit_count > 0) {
        oss << "Bit: " << bit_count << "\r\n";
    }
    if (button != 0) {
        oss << "Button: " << std::hex << button << "\r\n";
    }
    if (serial != 0) {
        oss << "Serial: " << std::hex << serial << "\r\n";
    }
    if (te > 0) {
        oss << "TE: " << te << "\r\n";
    }
    oss << "Repeat: " << getRepeatCount() << "\n";
    return oss.str();
}

std::unique_ptr<SubGhzProtocol> createNiceFloProtocol() {
    return std::make_unique<NiceFloProtocol>();
}


