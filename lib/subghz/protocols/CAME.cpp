#include "CAME.h"

bool CAMEProtocol::parse(File &file) {
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

    // Default TE if not specified (common CAME timing)
    if (te == 0) {
        te = 370;  // 370us typical for CAME
    }

    // Default repeat if not specified
    if (repeat == 0) {
        repeat = 5;  // CAME typically repeats 5 times
    }

    return (button != 0 || serial != 0) && te != 0;
}

void CAMEProtocol::encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const {
    // CAME uses Manchester-like encoding
    // 0 = short high + long low
    // 1 = long high + short low
    if (bit) {
        // Bit 1: long high (3*TE), short low (TE)
        pulses.push_back(std::make_pair(te * 3, true));
        pulses.push_back(std::make_pair(te, false));
    } else {
        // Bit 0: short high (TE), long low (3*TE)
        pulses.push_back(std::make_pair(te, true));
        pulses.push_back(std::make_pair(te * 3, false));
    }
}

std::vector<std::pair<uint32_t, bool>> CAMEProtocol::getPulseData() const {
    if (pulseData.empty()) {
        generatePulseData();
    }
    return pulseData;
}

void CAMEProtocol::generatePulseData() const {
    pulseData.clear();
    
    if (te == 0) {
        return;
    }

    // Calculate bit count if not specified
    uint16_t totalBits = bit_count;
    if (totalBits == 0) {
        // Estimate: button (4 bits) + serial (24 bits) = 28 bits typical
        totalBits = 28;
    }

    // Generate preamble: 4 long pulses
    for (int i = 0; i < 4; i++) {
        pulseData.push_back(std::make_pair(te * 4, true));
        pulseData.push_back(std::make_pair(te * 4, false));
    }

    // Encode button (usually 4 bits, least significant first)
    uint64_t data = (serial << 4) | (button & 0x0F);
    
    // Encode all bits
    for (int i = totalBits - 1; i >= 0; i--) {
        bool bit = (data >> i) & 0x01;
        encodeBit(bit, pulseData);
    }

    // Sync bit
    pulseData.push_back(std::make_pair(te, true));
    pulseData.push_back(std::make_pair(te * 4, false));
}

uint32_t CAMEProtocol::getRepeatCount() const {
    return repeat > 0 ? repeat : 5;
}

std::string CAMEProtocol::serialize() const {
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

std::unique_ptr<SubGhzProtocol> createCAMEProtocol() {
    return std::make_unique<CAMEProtocol>();
}


