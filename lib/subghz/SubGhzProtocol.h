#ifndef SUB_GHZ_PROTOCOL_H
#define SUB_GHZ_PROTOCOL_H

#include <iostream>
#include <string>
#include <vector>
#include <memory>
#include <unordered_map>
#include <SD.h>
#include <Arduino.h>
#include <stdint.h>
#include <string>

// Base SubGhzProtocol class
class SubGhzProtocol {
public:
    virtual ~SubGhzProtocol() {}
    virtual bool parse(File &file) = 0;
    virtual std::vector<std::pair<uint32_t, bool>> getPulseData() const = 0;  // Marked as const
    virtual uint32_t getRepeatCount() const = 0;  // Marked as const
    virtual std::string serialize() const = 0;  // Marked as const

    static SubGhzProtocol* create(const std::string &name);
    static void registerProtocol(const std::string &name, std::unique_ptr<SubGhzProtocol> (*creator)());
    bool readHexKey(const std::string &value, uint64_t &result);
    bool readUint32Decimal(const std::string &value, uint32_t &result);
};

// Registry to manage protocols
class SubGhzProtocolRegistry {
public:
    static SubGhzProtocolRegistry& instance();
    void registerProtocol(const std::string &name, std::unique_ptr<SubGhzProtocol> (*creator)());
    SubGhzProtocol* create(const std::string &name);
    void printRegisteredProtocols() const;

private:
    std::unordered_map<std::string, std::unique_ptr<SubGhzProtocol> (*)(void)> registry;
};

#endif // SUB_GHZ_PROTOCOL_H
