#ifndef Request_h
#define Request_h

#include <string>

struct RequestRecord {
    float frequency;      // 4 bytes for frequency
    uint8_t preset[50];   // Fixed size preset (max 50 bytes)
    uint8_t module;       // 1 byte for module number
    uint8_t modulation;   // 1 byte for modulation
    float deviation;      // 4 bytes for deviation
    float rxBandwidth;    // 4 bytes for bandwidth
    float dataRate;       // 4 bytes for data rate
};

struct TransmitFromFileRequest {
    uint8_t filePath[50];
};

struct RequestScan {
    uint8_t module;    // 1 byte for module
    int8_t minRssi;   // 1 byte for minimum RSSI value
};

uint32_t calculateCRC32(const uint8_t *data, size_t length);

#endif  // Request_h
