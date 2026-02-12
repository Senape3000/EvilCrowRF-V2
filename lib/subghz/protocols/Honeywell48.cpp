#include "Honeywell48.h"

static std::pair<uint32_t, bool> level_duration_make(bool level, uint32_t duration) {
    return std::make_pair(duration, level);
}

bool Honeywell48Protocol::parse(File &file) {
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

            if (key == "Key") {
                uint64_t parsedKey;
                if (!readHexKey(value, parsedKey)) {
                    return false;
                }
                // Mask to 48 bits
                this->key = parsedKey & 0xFFFFFFFFFFFFULL;
            } else if (key == "TE") {
                uint32_t te;
                if (!readUint32Decimal(value, te)) {
                    return false;
                }
                this->te = te;
            } else if (key == "Repeat") {
                uint32_t repeat;
                if (!readUint32Decimal(value, repeat)) {
                    return false;
                }
                this->repeat = repeat;
            } else if (key == "Guard_time") {
                uint32_t g_time;
                if (readUint32Decimal(value, g_time)) {
                    this->guard_time = g_time;
                }
            }
        }
    }

    // Default values if not specified
    if (te == 0) {
        te = 500;  // 500us typical for Honeywell
    }
    if (repeat == 0) {
        repeat = 5;  // Default 5 repeats
    }
    if (guard_time == 0) {
        guard_time = 30;  // Default guard time multiplier
    }

    return (this->key != 0 && this->te != 0);
}

void Honeywell48Protocol::encodeBit(bool bit, std::vector<std::pair<uint32_t, bool>>& pulses) const {
    // Honeywell uses Manchester encoding:
    // 0 = low-high (short low, long high)
    // 1 = high-low (long high, short low)
    // Or OOK encoding (depending on variant):
    // 0 = short pulse
    // 1 = long pulse
    
    // Using Manchester-like encoding similar to Princeton
    if (bit) {
        // Bit 1: long high, short low
        pulses.push_back(level_duration_make(true, te * 3));
        pulses.push_back(level_duration_make(false, te));
    } else {
        // Bit 0: short high, long low
        pulses.push_back(level_duration_make(true, te));
        pulses.push_back(level_duration_make(false, te * 3));
    }
}

std::vector<std::pair<uint32_t, bool>> Honeywell48Protocol::getPulseData() const {
    if (pulseData.empty()) {
        generatePulseData();
    }
    return pulseData;
}

void Honeywell48Protocol::generatePulseData() const {
    pulseData.clear();

    if (te == 0 || key == 0) {
        return;
    }

    // Sync/preamble bits (typical for Honeywell)
    // Long sync pulse
    pulseData.push_back(level_duration_make(true, te * 12));
    pulseData.push_back(level_duration_make(false, te * 4));

    // Encode 48 bits (MSB first)
    for (int i = 47; i >= 0; --i) {
        bool bit = (key >> i) & 0x01;
        encodeBit(bit, pulseData);
    }

    // Stop bit
    pulseData.push_back(level_duration_make(true, te));
    
    // Guard time
    pulseData.push_back(level_duration_make(false, te * guard_time));
}

uint32_t Honeywell48Protocol::getRepeatCount() const {
    return repeat > 0 ? repeat : 5;
}

std::string Honeywell48Protocol::serialize() const {
    std::ostringstream oss;
    oss << "Bit: 48\r\n";
    oss << "Key: " << std::hex << key << "\r\n";
    oss << "TE: " << te << "\r\n";
    if (guard_time > 0) {
        oss << "Guard_time: " << guard_time << "\r\n";
    }
    oss << "Repeat: " << getRepeatCount() << "\n";
    return oss.str();
}

std::unique_ptr<SubGhzProtocol> createHoneywell48Protocol() {
    return std::make_unique<Honeywell48Protocol>();
}

