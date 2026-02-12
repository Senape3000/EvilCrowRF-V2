#include "Holtek.h"

bool HoltekProtocol::parse(File &file) {
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

            if (key == "Address") {
                uint64_t parsed;
                if (readHexKey(value, parsed)) {
                    this->address = (uint16_t)(parsed & 0xFFF);
                }
            } else if (key == "Data") {
                uint64_t parsed;
                if (readHexKey(value, parsed)) {
                    this->data = (uint8_t)(parsed & 0xF);
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
            }
        }
    }

    if (te == 0) {
        te = 500;  // 500us typical for Holtek
    }

    if (repeat == 0) {
        repeat = 5;
    }

    return address != 0 && te != 0;
}

void HoltekProtocol::encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const {
    // Holtek encoding: 0 = short high + long low, 1 = long high + short low
    if (bit) {
        pulses.push_back(std::make_pair(te * 3, true));
        pulses.push_back(std::make_pair(te, false));
    } else {
        pulses.push_back(std::make_pair(te, true));
        pulses.push_back(std::make_pair(te * 3, false));
    }
}

std::vector<std::pair<uint32_t, bool>> HoltekProtocol::getPulseData() const {
    if (pulseData.empty()) {
        generatePulseData();
    }
    return pulseData;
}

void HoltekProtocol::generatePulseData() const {
    pulseData.clear();
    
    if (te == 0) {
        return;
    }

    // Sync bit
    pulseData.push_back(std::make_pair(te * 12, true));
    pulseData.push_back(std::make_pair(te * 4, false));

    // Encode 12-bit address (MSB first)
    for (int i = 11; i >= 0; i--) {
        bool bit = (address >> i) & 0x01;
        encodeBit(bit, pulseData);
    }

    // Encode 4-bit data (MSB first)
    for (int i = 3; i >= 0; i--) {
        bool bit = (data >> i) & 0x01;
        encodeBit(bit, pulseData);
    }

    // End bit
    pulseData.push_back(std::make_pair(te, true));
    pulseData.push_back(std::make_pair(te * 10, false));
}

uint32_t HoltekProtocol::getRepeatCount() const {
    return repeat > 0 ? repeat : 5;
}

std::string HoltekProtocol::serialize() const {
    std::ostringstream oss;
    oss << "Bit: 16\r\n";  // 12 address + 4 data
    oss << "Address: " << std::hex << address << "\r\n";
    oss << "Data: " << std::hex << (int)data << "\r\n";
    if (te > 0) {
        oss << "TE: " << te << "\r\n";
    }
    oss << "Repeat: " << getRepeatCount() << "\n";
    return oss.str();
}

std::unique_ptr<SubGhzProtocol> createHoltekProtocol() {
    return std::make_unique<HoltekProtocol>();
}


