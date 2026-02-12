#include "Princeton.h"

std::pair<uint32_t, bool> level_duration_make(bool level, uint32_t duration) {
    return std::make_pair(duration, level);
}

bool PrincetonProtocol::parse(File &file) {
    char buffer[256];
    while (file.available()) {
        int len = file.readBytesUntil('\n', buffer, sizeof(buffer));
        buffer[len] = '\0'; // Null-terminate the buffer
        std::string line(buffer);

        std::istringstream iss(line);
        std::string key, value;
        if (std::getline(iss, key, ':') && std::getline(iss, value)) {
            key = key.substr(0, key.find_first_of(" \t")); // Trim key
            value = value.substr(value.find_first_not_of(" \t")); // Trim value

            if (key == "Key") {
                uint64_t parsedKey;
                if (!readHexKey(value, parsedKey)) {
                    return false;
                }
                this->key = parsedKey;
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
            } else if (key == "Bit") {
                uint32_t bit;
                if (!readUint32Decimal(value, bit)) {
                    return false;
                }
                this->bit_count = (uint16_t)bit;
            } else if (key == "Guard_time") {
                uint32_t g_time;
                if (readUint32Decimal(value, g_time)) {
                    if ((g_time >= 15) && (g_time <= 72)) {
                        
                        this->guard_time = g_time;
                    }
                } 
            }
        }
    }

    return (this->key != 0 && this->te != 0 && this->repeat != 0 && this->bit_count != 0);
}

std::vector<std::pair<uint32_t, bool>> PrincetonProtocol::getPulseData() const {
    if (pulseData.empty()) {
        generatePulseData();
    }
    return pulseData;
}

void PrincetonProtocol::generatePulseData() const {
    pulseData.clear();

    size_t index = 0;
    size_t payloadSize = (bit_count * 2) + 2;
    pulseData.reserve(payloadSize);

    for (int i = bit_count - 1; i >= 0; --i) {
        bool bit = (key >> i) & 0x01;
        if (bit) {
            pulseData.push_back(level_duration_make(true, te * 3));
            pulseData.push_back(level_duration_make(false, te));
        } else {
            pulseData.push_back(level_duration_make(true, te));
            pulseData.push_back(level_duration_make(false, te * 3));
        }
    }

    // Send Stop bit
    pulseData.push_back(level_duration_make(true, te));
    // Send PT_GUARD_TIME
    pulseData.push_back(level_duration_make(false, te * guard_time));
}

std::string PrincetonProtocol::serialize() const {
    std::ostringstream oss;
    oss << "Bit: " << bit_count << "\r\n";
    oss << "Key: " << std::hex << key << "\r\n";
    oss << "TE: " << te << "\r\n";
    oss << "Guard_time" << guard_time << "\r\n";
    oss << "Repeat: " << repeat << "\n";
    return oss.str();
}

uint32_t PrincetonProtocol::getRepeatCount() const {
    return repeat;
}

std::unique_ptr<SubGhzProtocol> createPrincetonProtocol() {
    return std::make_unique<PrincetonProtocol>();
}