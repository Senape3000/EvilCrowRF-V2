#include "SubGhzProtocol.h"
#include <sstream>

SubGhzProtocolRegistry& SubGhzProtocolRegistry::instance() {
    static SubGhzProtocolRegistry instance;
    return instance;
}

void SubGhzProtocolRegistry::registerProtocol(const std::string &name, std::unique_ptr<SubGhzProtocol> (*creator)()) {
    registry[name] = creator;
}

SubGhzProtocol* SubGhzProtocolRegistry::create(const std::string &name) {
    auto it = registry.find(name);
    if (it != registry.end()) {
        return it->second().release();
    }
    return nullptr;
}

SubGhzProtocol* SubGhzProtocol::create(const std::string &name) {
    return SubGhzProtocolRegistry::instance().create(name);
}

void SubGhzProtocol::registerProtocol(const std::string &name, std::unique_ptr<SubGhzProtocol> (*creator)()) {
    SubGhzProtocolRegistry::instance().registerProtocol(name, creator);
}

void SubGhzProtocolRegistry::printRegisteredProtocols() const {
    Serial.println("Registered protocols:");
    for (const auto& entry : registry) {
        Serial.println(entry.first.c_str());
    }
}

bool hexCharToUint8(char high, char low, uint8_t &value) {
    auto hexValue = [](char c) -> uint8_t {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        return 0;
    };

    value = (hexValue(high) << 4) | hexValue(low);
    return true;
}

bool SubGhzProtocol::readHexKey(const std::string &value, uint64_t &result) {
    const char* hexStr = value.c_str();
    hexStr += strspn(hexStr, " \t"); // Skip any spaces or tabs

    uint8_t byteValue;
    result = 0;

    while (*hexStr && *(hexStr + 1)) {
        if (hexCharToUint8(*hexStr, *(hexStr + 1), byteValue)) {
            result = (result << 8) | byteValue;
        }
        hexStr += 2;
        hexStr += strspn(hexStr, " \t"); // Skip any spaces or tabs between hex pairs
    }

    return true;
}

bool SubGhzProtocol::readUint32Decimal(const std::string &value, uint32_t &result) {
    const char* valueStr = value.c_str();
    valueStr += strspn(valueStr, " \t"); // Skip any spaces or tabs

    result = strtoul(valueStr, nullptr, 10);
    return true;
}