#ifndef CommandHandler_h
#define CommandHandler_h

#include <Arduino.h>
#include <map>
#include <functional>
#include <stdint.h>

class CommandHandler {
public:
    using CommandFunc = std::function<bool(const uint8_t*, size_t)>;
    
    volatile bool isExecuting = false;
    
    void registerCommand(uint8_t id, CommandFunc func) {
        commands_[id] = func;
        ESP_LOGI("CommandHandler", "Registered command: 0x%02X", id);
    }
    
    bool executeCommand(uint8_t id, const uint8_t* data, size_t len) {
        auto it = commands_.find(id);
        if (it != commands_.end()) {
            ESP_LOGD("CommandHandler", "Executing command: 0x%02X", id);
            isExecuting = true;
            bool result = it->second(data, len);
            isExecuting = false;
            return result;
        }
        ESP_LOGW("CommandHandler", "Command not found: 0x%02X", id);
        return false;
    }
    
    bool hasCommand(uint8_t id) const {
        return commands_.find(id) != commands_.end();
    }
    
    size_t getCommandCount() const {
        return commands_.size();
    }
    
    void disableCommand(uint8_t id) {
        commands_.erase(id);
        ESP_LOGI("CommandHandler", "Disabled command: 0x%02X", id);
    }

private:
    std::map<uint8_t, CommandFunc> commands_;
};

// Global instance
extern CommandHandler commandHandler;

#endif


