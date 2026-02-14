#include "BleAdapter.h"
#include "Request.h"
#include "ClientsManager.h"
#include "SD.h"
#include <LittleFS.h>
#include <algorithm>
#include <cstring>
#include <cstdio>
#include "ConfigManager.h"

static const char* TAG = "BleAdapter";

extern ClientsManager& clients;

// Static member definitions
const char* BleAdapter::SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const char* BleAdapter::CHARACTERISTIC_UUID_TX = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
const char* BleAdapter::CHARACTERISTIC_UUID_RX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

BleAdapter* BleAdapter::instance = nullptr;
SemaphoreHandle_t BleAdapter::sendChunkMutex = nullptr;

BleAdapter::BleAdapter() : pServer(nullptr), pService(nullptr), pTxCharacteristic(nullptr), pRxCharacteristic(nullptr), serverCallbacks(nullptr), characteristicCallbacks(nullptr) {
    instance = this;
    // Create mutex for sendSingleChunk static buffer protection
    if (sendChunkMutex == nullptr) {
        sendChunkMutex = xSemaphoreCreateMutex();
    }
}

BleAdapter::~BleAdapter() {
    // Clean up callback objects
    if (serverCallbacks) {
        delete serverCallbacks;
        serverCallbacks = nullptr;
    }
    if (characteristicCallbacks) {
        delete characteristicCallbacks;
        characteristicCallbacks = nullptr;
    }
}

void BleAdapter::begin() {
    ESP_LOGI(TAG, "Initializing NimBLE adapter");
    ESP_LOGI(TAG, "Free heap before BLE init: %d bytes", ESP.getFreeHeap());
    
    // Initialize NimBLE device with configurable name from settings
    const char* bleName = ConfigManager::getDeviceName();
    NimBLEDevice::init(bleName);
    ESP_LOGI(TAG, "NimBLE device initialized with name: %s", bleName);
    
    // Request higher MTU for better throughput
    NimBLEDevice::setMTU(512);
    ESP_LOGI(TAG, "NimBLE MTU set to 512 bytes");
    
    // Create BLE server
    pServer = NimBLEDevice::createServer();
    ESP_LOGD(TAG, "NimBLE server created");
    
    // Create callbacks with proper memory management
    serverCallbacks = new ServerCallbacks(this);
    characteristicCallbacks = new CharacteristicCallbacks(this);
    
    if (serverCallbacks == nullptr || characteristicCallbacks == nullptr) {
        ESP_LOGE(TAG, "Failed to allocate memory for BLE callbacks");
        if (serverCallbacks) delete serverCallbacks;
        if (characteristicCallbacks) delete characteristicCallbacks;
        return; // Cannot continue without callbacks
    }
    
    ESP_LOGD(TAG, "NimBLE callbacks created");
    pServer->setCallbacks(serverCallbacks);
    
    // Create BLE service
    pService = pServer->createService(SERVICE_UUID);
    ESP_LOGD(TAG, "NimBLE service created with UUID: %s", SERVICE_UUID);
    
    // Create TX characteristic (notify)
    // NimBLE auto-creates the CCCD (0x2902) descriptor when NOTIFY property is set
    pTxCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID_TX,
        NIMBLE_PROPERTY::NOTIFY
    );
    ESP_LOGD(TAG, "TX characteristic created with UUID: %s", CHARACTERISTIC_UUID_TX);
    
    // Create RX characteristic (write)
    pRxCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID_RX,
        NIMBLE_PROPERTY::WRITE
    );
    pRxCharacteristic->setCallbacks(characteristicCallbacks);
    ESP_LOGD(TAG, "RX characteristic created with UUID: %s", CHARACTERISTIC_UUID_RX);
    
    // Start the service
    pService->start();
    ESP_LOGD(TAG, "NimBLE service started");
    
    // Start advertising
    NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->start();
    ESP_LOGD(TAG, "NimBLE advertising started");
    
    ESP_LOGI(TAG, "NimBLE Server started, waiting for connections...");
    ESP_LOGI(TAG, "Free heap after BLE init: %d bytes", ESP.getFreeHeap());
}

void BleAdapter::notify(String type, std::string message) {
    if (!message.empty()) {
        // Check if this is a binary message (0x80-0xFF)
        // Use unsigned char to avoid sign issues
        uint8_t firstByte = static_cast<uint8_t>(static_cast<unsigned char>(message[0]));
        ESP_LOGD(TAG, "notify: firstByte=0x%02X, length=%d", firstByte, message.length());
        
        // Declare variables for both BLE and Serial
        String binaryData;
        String response;
        
        if (firstByte >= 0x80) {
            // BINARY MESSAGE: Send directly without JSON wrapper
            ESP_LOGD(TAG, "Binary message detected: 0x%02X, length=%d bytes", firstByte, message.length());
            // Convert std::string to String (binary data preserved)
            binaryData.reserve(message.length());
            for (size_t i = 0; i < message.length(); i++) {
                binaryData += (char)message[i];
            }
            if (deviceConnected) {
                sendBinaryResponse(binaryData);
            }
        } else {
            // JSON MESSAGE: Wrap in JSON structure
            response.reserve(message.length() + type.length() + 50); // +50 for JSON structure
            
            if (message[0] != '{' && message[0] != '[') {
                response = "{\"type\":\"" + type + "\", \"data\":\"" + String(message.c_str()) + "\"}";
            } else {
                response = "{\"type\":\"" + type + "\", \"data\":" + String(message.c_str()) + "}";
            }
            
            ESP_LOGD(TAG, "notify: response length=%d", response.length());
            if (response.length() > 100) {
                ESP_LOGD(TAG, "Response start: %.100s", response.c_str());
                ESP_LOGD(TAG, "Response end: %s", response.c_str() + response.length() - 100);
            }
            
            if (deviceConnected) {
                // Send response using binary protocol
                sendBinaryResponse(response);
            }
        }
        
        // If command was from serial, also send to Serial
        if (isSerialCommand) {
            if (firstByte >= 0x80) {
                // Binary message: send raw bytes
                Serial.write(binaryData.c_str(), binaryData.length());
            } else {
                // JSON message: send as string
                Serial.println(response);
            }
            // Reset flag after sending
            isSerialCommand = false;
        }
    }
}

void BleAdapter::processBinaryData(uint8_t *data, size_t len) {
    ESP_LOGD(TAG, "Processing binary data, length: %zu", len);
    
    // Small hex preview for short binary messages to aid debugging (works for both BLE and serial)
    if (len > 0 && len <= 16) {
        char hexPreview[3 * 16 + 1] = {0};
        for (size_t i = 0; i < len; ++i) {
            snprintf(hexPreview + i * 3, 4, "%02X ", data[i]);
        }
        ESP_LOGI(TAG, "payload preview (%zu bytes): %s", len, hexPreview);
    }

    // Cleanup old uploads periodically (every 100 packets to avoid overhead)
    static uint32_t cleanupCounter = 0;
    if (++cleanupCounter % 100 == 0) {
        cleanupOldUploads();
    }
    
    if (len < PACKET_HEADER_SIZE + 1) { // header (7 bytes) + checksum (1 byte) = 8 bytes minimum
        ESP_LOGW(TAG, "Message too short: %zu bytes", len);
        notifyError("Message too short");
        return;
    }
    
    // Extract packet fields (enhanced protocol format)
    // Format: [Magic:1][Type:1][ChunkID:1][ChunkNum:1][TotalChunks:1][DataLen:2][Data:variable][Checksum:1]
    uint8_t magic = data[0];
    uint8_t packetType = data[1];
    uint8_t chunkId = data[2];
    uint8_t chunkNum = data[3];
    uint8_t totalChunks = data[4];
    uint16_t dataLength = data[5] | (data[6] << 8);  // Little-endian: 2 bytes
    
    // Validate magic byte
    if (magic != MAGIC_BYTE) {
        ESP_LOGW(TAG, "Invalid magic byte: 0x%02X", magic);
        notifyError("Invalid magic byte");
        return;
    }
    
    // Validate packet type
    if (packetType != 0x01) { // DATA packet type
        ESP_LOGW(TAG, "Invalid packet type: 0x%02X", packetType);
        notifyError("Invalid packet type");
        return;
    }
    
    // Validate data length
    if (len < PACKET_HEADER_SIZE + dataLength + 1) {
        ESP_LOGW(TAG, "Packet length mismatch: expected %d, got %zu", PACKET_HEADER_SIZE + dataLength + 1, len);
        notifyError("Packet length mismatch");
        return;
    }
    
    // Extract payload and checksum
    uint8_t *payload = &data[PACKET_HEADER_SIZE];
    uint8_t receivedChecksum = data[PACKET_HEADER_SIZE + dataLength];
    
    // Calculate checksum (XOR of all bytes except checksum)
    uint8_t calculatedChecksum = 0;
    for (size_t i = 0; i < PACKET_HEADER_SIZE + dataLength; i++) {
        calculatedChecksum ^= data[i];
    }
    
    if (receivedChecksum != calculatedChecksum) {
        ESP_LOGW(TAG, "Invalid checksum: received 0x%02X, calculated 0x%02X", receivedChecksum, calculatedChecksum);
        notifyError("Invalid checksum");
        return;
    }
    
    // Handle chunked vs single packet
    if (totalChunks > 1) {
        ESP_LOGD(TAG, "Processing chunked packet: chunkId=%d, chunkNum=%d/%d", chunkId, chunkNum, totalChunks);
        handleChunkedCommand(chunkId, chunkNum, totalChunks, payload, dataLength);
    } else {
        ESP_LOGD(TAG, "Processing single packet: chunkId=%d", chunkId);
        handleSingleCommand(payload, dataLength);
    }
}

void BleAdapter::handleSingleCommand(uint8_t *payload, size_t payloadLength) {
    if (payloadLength < 1) {
        notifyError("Empty payload");
        return;
    }
    
    uint8_t messageType = payload[0];
    
    // Check if this is an upload command (0x0D) - handle specially even for single packet
    // (though uploads should normally be chunked, we handle single packet case too)
    if (messageType == 0x0D) {
        // Treat as single chunk upload (chunkId=0, chunkNum=1, totalChunks=1)
        handleUploadChunk(0, 1, 1, payload, payloadLength);
        return; // Always return — don't fall through to CommandHandler on failure
    }
    
    uint8_t *commandPayload = &payload[1];
    size_t commandPayloadLength = payloadLength - 1;
    
    ESP_LOGD(TAG, "Handling single command: type=0x%02X, payloadLen=%zu", messageType, commandPayloadLength);
    
    // Use CommandHandler to execute the command
    if (commandHandler_ && commandHandler_->executeCommand(messageType, commandPayload, commandPayloadLength)) {
        ESP_LOGD(TAG, "Command executed successfully: 0x%02X", messageType);
    } else {
        ESP_LOGW(TAG, "Command execution failed: 0x%02X", messageType);
        notifyError("Command not supported or execution failed");
    }
}

void BleAdapter::handleChunkedCommand(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, uint8_t *payload, size_t payloadLength) {
    ESP_LOGD(TAG, "Handling chunked command: chunkId=%d, chunkNum=%d/%d, payloadLength=%zu", chunkId, chunkNum, totalChunks, payloadLength);
    
    // Check if this is an upload command - check by chunkId (if upload is active) or by first byte
    bool isUploadCommand = false;
    
    // Check if we have an active upload for this chunkId
    auto uploadIt = fileUploads.find(chunkId);
    if (uploadIt != fileUploads.end() && uploadIt->second.isActive) {
        isUploadCommand = true;
    } else if (payloadLength > 0 && payload[0] == 0x0D) {
        // First chunk of upload command
        isUploadCommand = true;
    }
    
    if (isUploadCommand) {
        if (handleUploadChunk(chunkId, chunkNum, totalChunks, payload, payloadLength)) {
            return; // Upload handled
        }
    }
    
    // For other chunked commands, use default behavior
    if (chunkNum == 1) {
        // First chunk - extract command type
        if (payloadLength < 1) {
            notifyError("Empty chunked command");
            return;
        }
        
        uint8_t messageType = payload[0];
        ESP_LOGD(TAG, "Chunked command type: 0x%02X", messageType);
        
        // For chunked commands, we'll process them as single commands for now
        // In a full implementation, you'd accumulate all chunks first
        handleSingleCommand(payload, payloadLength);
    } else {
        ESP_LOGD(TAG, "Received chunk %d/%d for chunkId %d", chunkNum, totalChunks, chunkId);
        // In a full implementation, you'd accumulate this chunk
        // For now, we'll just log it
    }
}

void BleAdapter::sendBinaryResponse(const String& data) {
    if (!deviceConnected || !pTxCharacteristic) return;
    
    const char* dataPtr = data.c_str();
    uint16_t dataLen = data.length();
    
    // Check if this is a binary message (first byte >= 0x80)
    bool isBinaryMessage = (dataLen > 0 && static_cast<uint8_t>(static_cast<unsigned char>(dataPtr[0])) >= 0x80);
    
    if (isBinaryMessage) {
        // For small binary messages (like ModeSwitch = 4 bytes, SignalDetected = 12 bytes),
        // send as single packet to avoid chunking overhead and BLE truncation issues
        // For large binary messages (like State = 102 bytes, FileList), use chunking
        if (dataLen <= MAX_CHUNK_SIZE) {
            sendSingleChunk(0, 1, 1, dataPtr, dataLen);
        } else {
            // Large binary messages (like MSG_FILE_LIST 0xA1) should use chunking protocol
            sendChunkedResponse(data);
        }
    } else {
        // For small text responses, send as single packet
        if (dataLen <= MAX_CHUNK_SIZE) {
            sendSingleChunk(0, 1, 1, dataPtr, dataLen);
        } else {
            // For large text responses, use chunking
            sendChunkedResponse(data);
        }
    }
}

void BleAdapter::sendChunkedResponse(const String& data) {
    uint8_t chunkId = esp_random() % 255; // Random chunk ID
    uint16_t dataLen = data.length();
    uint8_t totalChunks = (dataLen + MAX_CHUNK_SIZE - 1) / MAX_CHUNK_SIZE;
    
    ESP_LOGI(TAG, "sendChunkedResponse: data length=%d, totalChunks=%d, chunkId=%d", dataLen, totalChunks, chunkId);
    
    // CRITICAL: Copy data pointer before loop to ensure it remains valid
    // String reference might be destroyed, so we need to ensure data stays alive
    const char* dataPtr = data.c_str();
    
    // Validate pointer before use
    if (dataPtr == nullptr) {
        ESP_LOGE(TAG, "Invalid data pointer in sendChunkedResponse");
        return;
    }
    
    for (uint8_t i = 0; i < totalChunks; i++) {
        uint8_t chunkNum = i + 1;
        uint16_t startPos = i * MAX_CHUNK_SIZE;
        uint16_t endPos = std::min((uint16_t)(startPos + MAX_CHUNK_SIZE), dataLen);
        uint16_t chunkLen = endPos - startPos;
        
        // Validate chunk parameters
        if (startPos >= dataLen || chunkLen == 0) {
            ESP_LOGE(TAG, "Invalid chunk parameters: startPos=%d, dataLen=%d, chunkLen=%d", 
                     startPos, dataLen, chunkLen);
            break;
        }
        
        ESP_LOGI(TAG, "Sending chunk %d/%d: chunkId=%d, startPos=%d, chunkLen=%d", 
                 chunkNum, totalChunks, chunkId, startPos, chunkLen);
        
        // Use pointer directly instead of String::substring to avoid memory allocation
        // sendSingleChunk now waits for BLE confirmation via semaphore
        sendSingleChunk(chunkId, chunkNum, totalChunks, dataPtr + startPos, chunkLen);
        
        // CRITICAL: Increased delay between chunks to ensure BLE stack processes each chunk
        // BLE notifications are queued, but we need to give the stack time to send them
        // First chunk needs extra time to establish the connection state
        if (chunkNum == 1) {
            vTaskDelay(pdMS_TO_TICKS(50));  // Extra delay for first chunk
        } else {
            vTaskDelay(pdMS_TO_TICKS(30));  // Standard delay for subsequent chunks
        }
    }
    
    // Removed final log to avoid potential memory issues - function should complete silently
}

void BleAdapter::streamFileData(const uint8_t* header, size_t headerSize, File& file, size_t fileSize) {
    if (!deviceConnected || !pTxCharacteristic) return;
    
    // Calculate total message size and chunks
    size_t totalMessageSize = headerSize + fileSize;
    uint8_t chunkId = esp_random() % 255; // Random chunk ID
    uint8_t totalChunks = (totalMessageSize + MAX_CHUNK_SIZE - 1) / MAX_CHUNK_SIZE;
    
    // Reduced logging to avoid memory allocation - use ESP_LOGD for detailed info
    ESP_LOGD(TAG, "Streaming file: totalSize=%zu, headerSize=%zu, fileSize=%zu, totalChunks=%d", 
             totalMessageSize, headerSize, fileSize, totalChunks);
    
    // Buffer for reading file parts
    static uint8_t readBuffer[MAX_CHUNK_SIZE];
    
    size_t totalSent = 0;
    uint8_t chunkNum = 1;
    
    // First chunk: header + first part of file
    size_t firstChunkDataSize = (totalMessageSize > MAX_CHUNK_SIZE) ? 
                                 (MAX_CHUNK_SIZE - headerSize) : fileSize;
    
    // Create first chunk buffer (header + first file part)
    static uint8_t firstChunkBuffer[MAX_CHUNK_SIZE];
    memcpy(firstChunkBuffer, header, headerSize);
    
    if (firstChunkDataSize > 0) {
        size_t bytesRead = file.read(firstChunkBuffer + headerSize, firstChunkDataSize);
        if (bytesRead != firstChunkDataSize) {
            ESP_LOGE(TAG, "Failed to read first chunk: %zu/%zu bytes", bytesRead, firstChunkDataSize);
            return;
        }
        totalSent += bytesRead;
    }
    
    // Send first chunk (sendSingleChunk waits for BLE confirmation)
    sendSingleChunk(chunkId, chunkNum, totalChunks, (const char*)firstChunkBuffer, headerSize + (totalSent > 0 ? firstChunkDataSize : 0));
    chunkNum++;
    
    // Stream remaining file data in chunks
    while (file.available() && totalSent < fileSize) {
        size_t bytesToRead = (fileSize - totalSent > MAX_CHUNK_SIZE) ? MAX_CHUNK_SIZE : (fileSize - totalSent);
        size_t bytesRead = file.read(readBuffer, bytesToRead);
        
        if (bytesRead == 0) {
            ESP_LOGW(TAG, "Read 0 bytes at offset %zu", totalSent);
            break;
        }
        
        // Check heap before sending
        size_t freeHeap = ESP.getFreeHeap();
        if (freeHeap < 10000) {
            ESP_LOGW(TAG, "Low heap: %zu bytes", freeHeap);
            vTaskDelay(pdMS_TO_TICKS(50));
        }
        
        // Send this chunk (waits for BLE confirmation)
        sendSingleChunk(chunkId, chunkNum, totalChunks, (const char*)readBuffer, bytesRead);
        totalSent += bytesRead;
        chunkNum++;
        
        // Yield to other tasks
        vTaskDelay(pdMS_TO_TICKS(5));
    }
    
    ESP_LOGD(TAG, "File streamed: %zu bytes in %d chunks", totalSent, chunkNum - 1);
}

void BleAdapter::sendSingleChunk(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, const char* chunkData, uint16_t dataLen) {
    if (!deviceConnected || !pTxCharacteristic) return;
    
    // Limit data length to MAX_CHUNK_SIZE
    if (dataLen > MAX_CHUNK_SIZE) {
        dataLen = MAX_CHUNK_SIZE;
    }
    
    uint16_t packetSize = PACKET_HEADER_SIZE + dataLen + 1; // +1 for checksum
    
    // CRITICAL: BLE notify has a hard limit of 509 bytes
    // Ensure packet size doesn't exceed this limit
    const uint16_t BLE_NOTIFY_MAX_SIZE = 509;
    if (packetSize > BLE_NOTIFY_MAX_SIZE) {
        // Reduce data length to fit within BLE limit
        dataLen = BLE_NOTIFY_MAX_SIZE - PACKET_HEADER_SIZE - 1;
        packetSize = PACKET_HEADER_SIZE + dataLen + 1;
        ESP_LOGW(TAG, "Packet size exceeds BLE limit, reducing to %d bytes", packetSize);
    }
    
    // Use static buffer instead of VLA (Variable Length Array)
    // VLA on stack is dangerous on ESP32 with limited stack size
    static const size_t MAX_PACKET_SIZE = PACKET_HEADER_SIZE + MAX_CHUNK_SIZE + 1;
    static uint8_t packetBuffer[MAX_PACKET_SIZE];
    
    // CRITICAL: Acquire mutex to protect static buffer from concurrent access
    // (sendSingleChunk can be called from Core 0 BLE task and Core 1 bruter task)
    if (xSemaphoreTake(sendChunkMutex, pdMS_TO_TICKS(100)) != pdTRUE) {
        ESP_LOGE(TAG, "Failed to acquire sendChunkMutex, dropping chunk %d/%d", chunkNum, totalChunks);
        return;
    }
    
    // Validate packet size
    if (packetSize > MAX_PACKET_SIZE) {
        ESP_LOGE(TAG, "Packet size %d exceeds maximum %zu", packetSize, MAX_PACKET_SIZE);
        xSemaphoreGive(sendChunkMutex);
        return;
    }
    
    uint8_t* packet = packetBuffer; // Use static buffer
    
    // Log first chunk to debug missing chunk issue
    if (chunkNum == 1) {
        ESP_LOGI(TAG, "Sending FIRST chunk: chunkId=%d, chunkNum=%d/%d, dataLen=%d, packetSize=%d", 
                 chunkId, chunkNum, totalChunks, dataLen, packetSize);
    }
    
    packet[0] = MAGIC_BYTE;        // Magic byte
    packet[1] = 0x01;             // Type: data
    packet[2] = chunkId;          // Chunk ID
    packet[3] = chunkNum;         // Chunk number
    packet[4] = totalChunks;       // Total chunks
    packet[5] = dataLen & 0xFF;           // Data length (low byte)
    packet[6] = (dataLen >> 8) & 0xFF;    // Data length (high byte)
    
    // Copy data using memcpy (faster and no stack allocation for loop counter)
    memcpy(packet + 7, chunkData, dataLen);
    
    // Calculate checksum
    packet[7 + dataLen] = calculateChecksum(packet, packetSize - 1);
    
    // Log first chunk data preview for debugging
    if (chunkNum == 1 && dataLen > 0) {
        ESP_LOGI(TAG, "First chunk first byte: 0x%02X, magic: 0x%02X", 
                 chunkData[0], packet[0]);
    }
    
    pTxCharacteristic->setValue(packet, packetSize);
    pTxCharacteristic->notify();
    
    if (chunkNum == 1) {
        ESP_LOGI(TAG, "First chunk notify() called, packetSize=%d", packetSize);
    }
    
    // Release mutex before delay
    xSemaphoreGive(sendChunkMutex);
    
    // CRITICAL: Increased delay to allow BLE stack to process and send the notification
    // BLE notifications are asynchronous and need time to be queued and transmitted
    // This is especially important for the first chunk which may need connection setup
    vTaskDelay(pdMS_TO_TICKS(10));
}

uint8_t BleAdapter::calculateChecksum(const uint8_t *data, size_t len) {
    uint8_t checksum = 0;
    for (size_t i = 0; i < len; i++) {
        checksum ^= data[i];
    }
    return checksum;
}

// Command handlers (same implementation as WebAdapter)


void BleAdapter::notifyError(const char *errorMsg) {
    notify("Error", errorMsg);
}

bool BleAdapter::moduleExists(uint8_t module) {
    return module >= 0 && module < CC1101_NUM_MODULES;
}


void BleAdapter::cleanupOldUploads() {
    uint32_t now = millis();
    auto it = fileUploads.begin();
    while (it != fileUploads.end()) {
        if (now - it->second.timestamp > 60000) { // 60 seconds timeout for uploads
            if (it->second.isActive && it->second.file) {
                it->second.file.close();
            }
            it = fileUploads.erase(it);
        } else {
            ++it;
        }
    }
}

bool BleAdapter::handleUploadChunk(uint8_t chunkId, uint8_t chunkNum, uint8_t totalChunks, uint8_t *payload, size_t payloadLength) {
    ESP_LOGD(TAG, "handleUploadChunk: chunkId=%d, chunkNum=%d/%d, payloadLength=%zu", chunkId, chunkNum, totalChunks, payloadLength);
    
    // Check if this is the first chunk (initialization)
    if (chunkNum == 1) {
        if (payloadLength < 3) { // Need at least: messageType(1) + pathLength(1) + pathType(1)
            ESP_LOGE(TAG, "Upload chunk too short: %zu bytes", payloadLength);
            notifyError("Upload command too short");
            return false;
        }
        
        uint8_t messageType = payload[0];
        if (messageType != 0x0D) {
            return false; // Not an upload command
        }
        
        uint8_t pathLength = payload[1];
        uint8_t pathType = payload[2];
        
        if (payloadLength < 3 + pathLength) {
            ESP_LOGE(TAG, "Upload path length mismatch: expected %d, got %zu", 3 + pathLength, payloadLength);
            notifyError("Upload path length mismatch");
            return false;
        }
        
        // Extract path
        const char* path = reinterpret_cast<const char*>(payload + 3);
        
        // Build full path — pathType 4 uses LittleFS root, 5 uses SD root, 0-3 use SD /DATA/...
        char fullPath[256];
        if (pathType == 4) {
            // LittleFS internal storage
            fullPath[0] = '/';
            fullPath[1] = '\0';
        } else if (pathType == 5) {
            // SD card root — no /DATA/ prefix
            fullPath[0] = '/';
            fullPath[1] = '\0';
        } else {
            strcpy(fullPath, "/DATA/");
            switch (pathType) {
                case 0: strcat(fullPath, "RECORDS"); break;
                case 1: strcat(fullPath, "SIGNALS"); break;
                case 2: strcat(fullPath, "PRESETS"); break;
                case 3: strcat(fullPath, "TEMP"); break;
                default: strcat(fullPath, "RECORDS"); break;
            }
        }
        
        if (pathLength > 0) {
            if (pathType != 4) strcat(fullPath, "/");
            if (path[0] == '/') {
                strncat(fullPath, path + 1, pathLength - 1);
            } else {
                strncat(fullPath, path, pathLength);
            }
        } else {
            if (pathType != 4) strcat(fullPath, "/");
        }
        
        ESP_LOGI(TAG, "Starting file upload: %s (pathType=%d)", fullPath, pathType);
        
        // Ensure parent directories exist (recursive mkdir)
        // SD/LittleFS mkdir() is NOT recursive — we must create each level
        fs::FS& fs = (pathType == 4) ? (fs::FS&)LittleFS : (fs::FS&)SD;
        {
            char dirBuf[256];
            strncpy(dirBuf, fullPath, sizeof(dirBuf) - 1);
            dirBuf[sizeof(dirBuf) - 1] = '\0';
            for (size_t i = 1; i < strlen(dirBuf); i++) {
                if (dirBuf[i] == '/') {
                    char saved = dirBuf[i];
                    dirBuf[i] = '\0';
                    if (!fs.exists(dirBuf)) {
                        fs.mkdir(dirBuf);
                        ESP_LOGD(TAG, "Created parent dir: %s", dirBuf);
                    }
                    dirBuf[i] = saved;
                }
            }
        }
        
        // Open file for writing on the correct filesystem
        File file = fs.open(fullPath, FILE_WRITE);
        if (!file) {
            ESP_LOGE(TAG, "Failed to open file for upload: %s", fullPath);
            notifyError("Failed to open file for upload");
            return false;
        }
        
        // Initialize upload state
        FileUploadState uploadState;
        uploadState.file = file;
        uploadState.totalChunks = totalChunks;
        uploadState.receivedChunks = 1;
        uploadState.timestamp = millis();
        uploadState.isActive = true;
        strncpy(uploadState.filePath, fullPath, sizeof(uploadState.filePath) - 1);
        uploadState.filePath[sizeof(uploadState.filePath) - 1] = '\0';
        
        fileUploads[chunkId] = uploadState;
        
        // First chunk contains command header - skip it, no data to write
        ESP_LOGI(TAG, "Upload initialized: %s, totalChunks=%d", fullPath, totalChunks);
        return true;
    } else {
        // Subsequent chunks - write data directly to file
        auto it = fileUploads.find(chunkId);
        if (it == fileUploads.end()) {
            ESP_LOGE(TAG, "Upload chunk received for unknown chunkId: %d", chunkId);
            return false;
        }
        
        FileUploadState& uploadState = it->second;
        if (!uploadState.isActive || !uploadState.file) {
            ESP_LOGE(TAG, "Upload state invalid for chunkId: %d", chunkId);
            return false;
        }
        
        // Write chunk data directly to file (NO memory buffering!)
        size_t bytesWritten = uploadState.file.write(payload, payloadLength);
        if (bytesWritten != payloadLength) {
            ESP_LOGE(TAG, "Failed to write chunk %d: wrote %zu/%zu bytes", chunkNum, bytesWritten, payloadLength);
            uploadState.file.close();
            uploadState.isActive = false;
            fileUploads.erase(it);
            notifyError("Failed to write chunk to file");
            return false;
        }
        
        uploadState.receivedChunks++;
        uploadState.timestamp = millis();
        
        ESP_LOGD(TAG, "Upload chunk %d/%d written: %zu bytes", chunkNum, uploadState.totalChunks, bytesWritten);
        
        // Check if all chunks received
        if (chunkNum >= totalChunks) {
            size_t fileSize = uploadState.file.size();
            uploadState.file.close();
            uploadState.isActive = false;
            
            ESP_LOGI(TAG, "Upload completed: %s, %d chunks, %zu bytes", 
                     uploadState.filePath, uploadState.receivedChunks, fileSize);
            
            // Send success response
            String response;
            response.reserve(200);
            response = "{\"action\":\"upload\",\"success\":true,\"path\":\"";
            response += uploadState.filePath;
            response += "\",\"chunks\":";
            response += String(uploadState.receivedChunks);
            response += "}";
            
            clients.enqueueMessage(NotificationType::FileSystem, response.c_str());
            
            fileUploads.erase(it);
        }
        
        return true;
    }
}

// Server callbacks implementation
void BleAdapter::ServerCallbacks::onConnect(NimBLEServer* pServer) {
    instance->deviceConnected = true;
    ESP_LOGI(TAG, "BLE Client connected");
}

void BleAdapter::ServerCallbacks::onDisconnect(NimBLEServer* pServer) {
    instance->deviceConnected = false;
    ESP_LOGI(TAG, "BLE Client disconnected");
    
    // Restart advertising — NimBLE handles this more efficiently than Bluedroid
    vTaskDelay(pdMS_TO_TICKS(500));
    NimBLEDevice::startAdvertising();
    ESP_LOGI(TAG, "NimBLE Advertising restarted");
}

// Characteristic callbacks implementation
void BleAdapter::CharacteristicCallbacks::onWrite(NimBLECharacteristic* pCharacteristic) {
    // NimBLE getValue() returns NimBLEAttValue with direct byte access
    NimBLEAttValue val = pCharacteristic->getValue();
    size_t len = val.length();
    
    if (len > 0) {
        ESP_LOGD(TAG, "BLE Data received, len=%u", static_cast<unsigned>(len));

        // Small hex preview for short payloads to aid debugging (<=16 bytes)
        if (len <= 16) {
            char hexPreview[3 * 16 + 1] = {0};
            for (size_t i = 0; i < len; ++i) {
                snprintf(hexPreview + i * 3, 4, "%02X ", val.data()[i]);
            }
            ESP_LOGI(TAG, "BLE payload preview (%u bytes): %s", static_cast<unsigned>(len), hexPreview);
        }

        // processBinaryData expects a mutable pointer; copy to local buffer
        // since NimBLEAttValue data is const
        adapter->processBinaryData(const_cast<uint8_t*>(val.data()), len);
    }
}
