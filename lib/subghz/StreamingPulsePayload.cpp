#include "StreamingPulsePayload.h"

bool StreamingPulsePayload::init(const char* filePath, uint32_t repeatCnt) {
    repeatCount = repeatCnt;
    currentRepeat = 0;
    parsingLine = false;
    currentLinePos = 0;
    
    file = SD.open(filePath, FILE_READ);
    if (!file) {
        return false;
    }
    
    // Find RAW_Data section
    if (!findRawDataStart()) {
        file.close();
        return false;
    }
    
    return true;
}

bool StreamingPulsePayload::next(uint32_t& duration, bool& pinState) {
    // Check if we're done with all repeats
    if (currentRepeat >= repeatCount) {
        return false;
    }
    
    while (true) {
        // If we don't have a line to parse, read next RAW_Data line
        if (!parsingLine) {
            if (!readNextRawDataLine()) {
                // No more RAW_Data lines - check if we need to repeat
                currentRepeat++;
                if (currentRepeat >= repeatCount) {
                    return false;
                }
                
                // Seek back to RAW_Data start for next repeat
                file.seek(rawDataStartPos);
                parsingLine = false;
                currentLinePos = 0;
                
                // Yield to other tasks between repeats
                taskYIELD();
                
                // Try reading again
                if (!readNextRawDataLine()) {
                    return false;
                }
            }
        }
        
        // Parse next integer from current line
        int32_t value;
        if (parseNextIntFromLine(value)) {
            if (value != 0) {
                duration = abs(value);
                pinState = (value > 0);
                return true;
            }
            // Skip zero values
        } else {
            // No more integers in current line
            parsingLine = false;
            currentLinePos = 0;
            // Loop to read next line
        }
    }
    
    return false;
}

void StreamingPulsePayload::close() {
    if (file) {
        file.close();
    }
}

bool StreamingPulsePayload::findRawDataStart() {
    // Read file line-by-line until we find first RAW_Data line
    while (file.available()) {
        size_t lineStart = file.position();
        String line = file.readStringUntil('\n');
        
        if (line.startsWith("RAW_Data:")) {
            // Found it! Save position and return
            rawDataStartPos = lineStart;
            file.seek(lineStart);  // Seek back to start of this line
            return true;
        }
    }
    
    return false;
}

bool StreamingPulsePayload::readNextRawDataLine() {
    while (file.available()) {
        currentLine = file.readStringUntil('\n');
        
        // Remove \r if present
        if (currentLine.endsWith("\r")) {
            currentLine.remove(currentLine.length() - 1);
        }
        
        // Check if this is a RAW_Data line
        if (currentLine.startsWith("RAW_Data:")) {
            // Skip "RAW_Data: " prefix
            currentLinePos = 9;
            while (currentLinePos < currentLine.length() && 
                   isspace(currentLine[currentLinePos])) {
                currentLinePos++;
            }
            
            parsingLine = true;
            return true;
        }
        
        // If we hit a non-RAW_Data line, we're done with RAW data
        if (!currentLine.isEmpty() && !currentLine.startsWith("RAW_Data:")) {
            return false;
        }
    }
    
    return false;
}

bool StreamingPulsePayload::parseNextIntFromLine(int32_t& value) {
    if (!parsingLine || currentLinePos >= currentLine.length()) {
        return false;
    }
    
    // Skip whitespace
    while (currentLinePos < currentLine.length() && 
           isspace(currentLine[currentLinePos])) {
        currentLinePos++;
    }
    
    if (currentLinePos >= currentLine.length()) {
        return false;
    }
    
    // Check for sign
    bool negative = false;
    if (currentLine[currentLinePos] == '-') {
        negative = true;
        currentLinePos++;
    }
    
    // Parse digits
    int32_t result = 0;
    bool hasDigits = false;
    
    while (currentLinePos < currentLine.length() && 
           isdigit(currentLine[currentLinePos])) {
        result = result * 10 + (currentLine[currentLinePos] - '0');
        currentLinePos++;
        hasDigits = true;
    }
    
    if (!hasDigits) {
        return false;
    }
    
    value = negative ? -result : result;
    return true;
}

