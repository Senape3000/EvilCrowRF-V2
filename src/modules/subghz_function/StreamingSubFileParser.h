#ifndef StreamingSubFileParser_h
#define StreamingSubFileParser_h

#include <Arduino.h>
#include <SD.h>
#include <string>

/**
 * Lightweight streaming parser for .sub files (RAM-optimized)
 * 
 * Two-pass approach:
 * 1. parseHeader() - reads header + preset (for CC1101 config)
 * 2. streamRawData() - reads RAW data line-by-line and calls callback
 * 
 * Minimal RAM usage: ~200 bytes (NO std::vector for all samples!)
 */
class StreamingSubFileParser {
public:
    struct SubFileHeader {
        uint32_t frequency;  // in Hz
        std::string preset;
        uint8_t customPresetData[128];
        size_t customPresetDataSize;
        std::string protocol;
        
        SubFileHeader() : frequency(0), customPresetDataSize(0) {
            memset(customPresetData, 0, sizeof(customPresetData));
        }
    };
    
    StreamingSubFileParser() {}
    
    /**
     * Parse header and preset info (first pass)
     * @param filePath Full path to .sub file
     * @param header Output: parsed header info
     * @return true if successful
     */
    bool parseHeader(const char* filePath, SubFileHeader& header);
    
    /**
     * Stream RAW data with callback (second pass)
     * @param filePath Full path to .sub file
     * @param callback Function called for each pulse: (duration_us, pinState)
     * @return true if successful
     */
    template<typename Callback>
    bool streamRawData(const char* filePath, Callback callback) {
        File file = SD.open(filePath, FILE_READ);
        if (!file) {
            return false;
        }
        
        size_t samplesProcessed = 0;
        
        // Read file line-by-line, looking for RAW_Data
        while (file.available()) {
            String line = file.readStringUntil('\n');
            if (line.endsWith("\r")) {
                line.remove(line.length() - 1);
            }
            
            // Check if this is a RAW_Data line
            if (line.startsWith("RAW_Data:")) {
                // Parse durations from this line
                std::string lineStr = line.c_str();
                size_t pos = lineStr.find("RAW_Data:") + 9;
                
                // Parse integers from the line
                while (pos < lineStr.length()) {
                    // Skip whitespace
                    while (pos < lineStr.length() && isspace(lineStr[pos])) {
                        pos++;
                    }
                    
                    if (pos >= lineStr.length()) break;
                    
                    // Parse integer (with sign)
                    bool negative = false;
                    if (lineStr[pos] == '-') {
                        negative = true;
                        pos++;
                    }
                    
                    int32_t duration = 0;
                    while (pos < lineStr.length() && isdigit(lineStr[pos])) {
                        duration = duration * 10 + (lineStr[pos] - '0');
                        pos++;
                    }
                    
                    if (negative) {
                        duration = -duration;
                    }
                    
                    // Call callback with (duration, pinState)
                    if (duration != 0) {
                        bool pinState = (duration > 0);
                        callback(abs(duration), pinState);
                        samplesProcessed++;
                    }
                }
            }
        }
        
        file.close();
        
        return samplesProcessed > 0;
    }
    
private:
    void parseLine(const String& line, SubFileHeader& header);
    std::string parseValue(const String& line);
    void parseCustomPresetData(const String& dataStr, SubFileHeader& header);
};

#endif // StreamingSubFileParser_h

