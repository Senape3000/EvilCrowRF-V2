#ifndef BleAdapter_h
#define BleAdapter_h

#include <Arduino.h>
#include "config.h"
#include "ControllerAdapter.h"
#include <string>
#include <vector>
// #include <sstream>  // Removed — unused in BleAdapter
#include <map>
#include <stdint.h>
#include <atomic>
#include "CommandHandler.h"

// NimBLE — lightweight BLE stack (replaces Bluedroid, saves ~30-40 KB RAM)
#include <NimBLEDevice.h>
#include "FS.h"

class BleAdapter : public ControllerAdapter {
public:
    BleAdapter();
    ~BleAdapter();
    void begin();
    void notify(String type, std::string message) override;
    String getName() override { return "BleAdapter"; }
    bool isConnected() const override { return deviceConnected; }
    
    // Set CommandHandler
    void setCommandHandler(CommandHandler* handler) { commandHandler_ = handler; }
    
    // File streaming method (public for FileCommands access)
    void streamFileData(const uint8_t* header, size_t headerSize, File& file, size_t fileSize);
    
    // Binary protocol method (public for serial command processing)
    void processBinaryData(uint8_t *data, size_t len);
    
    // Set serial command flag (atomic — safe from any core)
    void setSerialCommand(bool flag) { isSerialCommand.store(flag); }
    
    // Get instance (public for FileCommands access)
    static BleAdapter* getInstance() { return instance; }

private:
    // Server callbacks
    class ServerCallbacks : public NimBLEServerCallbacks {
        BleAdapter* adapter;
    public:
        ServerCallbacks(BleAdapter* adapter) : adapter(adapter) {}
        void onConnect(NimBLEServer* pServer) override;
        void onDisconnect(NimBLEServer* pServer) override;
    };
    
    // Characteristic callbacks for RX (incoming data)
    class CharacteristicCallbacks : public NimBLECharacteristicCallbacks {
        BleAdapter* adapter;
    public:
        CharacteristicCallbacks(BleAdapter* adapter) : adapter(adapter) {}
        void onWrite(NimBLECharacteristic* pCharacteristic) override;
    };
    
    NimBLEServer* pServer;
    NimBLEService* pService;
    NimBLECharacteristic* pTxCharacteristic;
    NimBLECharacteristic* pRxCharacteristic;
    
    ServerCallbacks* serverCallbacks;
    CharacteristicCallbacks* characteristicCallbacks;
    
    bool deviceConnected = false;
    
    // BLE UUIDs
    static const char* SERVICE_UUID;
    static const char* CHARACTERISTIC_UUID_TX;
    static const char* CHARACTERISTIC_UUID_RX;
    
    // Binary protocol constants
    static const uint8_t MAGIC_BYTE = 0xAA;
    static const uint16_t MAX_CHUNK_SIZE = 500; // Safe maximum: BLE notify limit is 509 bytes, so 509 - 7 (header) - 1 (checksum) - 1 (safety) = 500
    static const uint8_t PACKET_HEADER_SIZE = 7; // Increased from 6: dataLen is now 2 bytes
    
    // File upload structure (minimal memory usage - writes chunks directly to file)
    struct FileUploadState {
        File file;
        uint8_t totalChunks;
        uint8_t receivedChunks;
        uint32_t timestamp;
        bool isActive;
        char filePath[256];  // Static buffer for path
    };
    
    std::map<uint8_t, FileUploadState> fileUploads;
    
    // CommandHandler for executing commands
    CommandHandler* commandHandler_ = nullptr;
    
    // Flag to indicate if current command is from serial (atomic for cross-core safety)
    std::atomic<bool> isSerialCommand{false};
    
    // Command execution is delegated to CommandHandler via handleSingleCommand()
    
    // Binary protocol methods
    void handleSingleCommand(uint8_t *payload, size_t payloadLength);
    void handleChunkedCommand(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, uint8_t *payload, size_t payloadLength);
    void sendBinaryResponse(const String& data);
    void sendChunkedResponse(const String& data);
    void sendSingleChunk(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, const char* chunkData, uint16_t dataLen);
    uint8_t calculateChecksum(const uint8_t *data, size_t len);
    
    // Utility methods
    bool moduleExists(uint8_t module);
    void notifyError(const char *errorMsg);
    void cleanupOldUploads();
    bool handleUploadChunk(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, uint8_t *payload, size_t payloadLength);
    
    // Static instance for callbacks
    static BleAdapter* instance;
    
    // Mutex protecting static buffer in sendSingleChunk (cross-core safety)
    static SemaphoreHandle_t sendChunkMutex;
};

#endif // BleAdapter_h
