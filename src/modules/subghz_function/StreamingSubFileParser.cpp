#include "StreamingSubFileParser.h"
#include "esp_log.h"
#include <sstream>

static const char* TAG = "StreamingParser";

bool StreamingSubFileParser::parseHeader(const char* filePath, SubFileHeader& header) {
    File file = SD.open(filePath, FILE_READ);
    if (!file) {
        ESP_LOGE(TAG, "Failed to open file: %s", filePath);
        return false;
    }
    
    // Read file line-by-line until we find Protocol
    bool foundProtocol = false;
    while (file.available() && !foundProtocol) {
        String line = file.readStringUntil('\n');
        if (line.endsWith("\r")) {
            line.remove(line.length() - 1);
        }
        
        parseLine(line, header);
        
        if (line.startsWith("Protocol:")) {
            foundProtocol = true;
        }
    }
    
    file.close();
    
    ESP_LOGI(TAG, "Header parsed: freq=%u Hz, preset=%s, protocol=%s", 
             header.frequency, header.preset.c_str(), header.protocol.c_str());
    
    return foundProtocol && header.frequency > 0;
}

// Template implementation must be in header - moved to header file

void StreamingSubFileParser::parseLine(const String& line, SubFileHeader& header) {
    if (line.startsWith("Frequency:")) {
        String freqStr = String(parseValue(line).c_str());
        header.frequency = freqStr.toInt();
    } else if (line.startsWith("Preset:")) {
        header.preset = parseValue(line).c_str();
    } else if (line.startsWith("Custom_preset_data:")) {
        String dataStr = String(parseValue(line).c_str());
        parseCustomPresetData(dataStr, header);
    } else if (line.startsWith("Protocol:")) {
        header.protocol = parseValue(line).c_str();
    }
}

std::string StreamingSubFileParser::parseValue(const String& line) {
    int index = line.indexOf(':');
    if (index == -1) {
        return "";
    }
    String value = line.substring(index + 1);
    value.trim();
    return value.c_str();
}

void StreamingSubFileParser::parseCustomPresetData(const String& dataStr, SubFileHeader& header) {
    std::istringstream iss(dataStr.c_str());
    std::string hexValue;
    header.customPresetDataSize = 0;
    
    while (iss >> hexValue && header.customPresetDataSize < 128) {
        try {
            unsigned long value = strtoul(hexValue.c_str(), nullptr, 16);
            header.customPresetData[header.customPresetDataSize++] = static_cast<uint8_t>(value);
        } catch (...) {
            ESP_LOGW(TAG, "Failed to parse custom preset byte: %s", hexValue.c_str());
        }
    }
    
    ESP_LOGD(TAG, "Parsed %zu custom preset bytes", header.customPresetDataSize);
}

