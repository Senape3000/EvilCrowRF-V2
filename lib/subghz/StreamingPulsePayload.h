#ifndef STREAMING_PULSE_PAYLOAD_H
#define STREAMING_PULSE_PAYLOAD_H

#include <Arduino.h>
#include <SD.h>
#include <cstdint>

/**
 * Streaming pulse payload - reads RAW data directly from file (minimal RAM!)
 * 
 * Instead of loading entire signal into memory, this class:
 * 1. Opens file and finds RAW_Data position
 * 2. Reads pulses on-demand during transmission
 * 3. Supports repeat by seeking back to RAW_Data start
 * 
 * RAM usage: ~100 bytes (vs ~2KB for vector-based approach!)
 */
class StreamingPulsePayload {
public:
    StreamingPulsePayload() 
        : repeatCount(0), currentRepeat(0), rawDataStartPos(0), 
          currentLinePos(0), parsingLine(false) {}
    
    /**
     * Initialize streaming from file
     * @param filePath Full path to .sub file
     * @param repeatCount Number of times to repeat signal
     * @return true if successful
     */
    bool init(const char* filePath, uint32_t repeatCount);
    
    /**
     * Get next pulse
     * @param duration Output: pulse duration in microseconds
     * @param pinState Output: pin state (HIGH/LOW)
     * @return true if pulse available, false if done
     */
    bool next(uint32_t& duration, bool& pinState);
    
    /**
     * Close file and cleanup
     */
    void close();
    
    ~StreamingPulsePayload() {
        close();
    }
    
private:
    File file;
    uint32_t repeatCount;
    uint32_t currentRepeat;
    size_t rawDataStartPos;  // File position where RAW_Data starts
    
    // Line parsing state
    String currentLine;
    size_t currentLinePos;
    bool parsingLine;
    
    /**
     * Find and seek to RAW_Data section in file
     * @return true if found
     */
    bool findRawDataStart();
    
    /**
     * Read next RAW_Data line
     * @return true if line found
     */
    bool readNextRawDataLine();
    
    /**
     * Parse next integer from current line
     * @param value Output: parsed value
     * @return true if integer parsed
     */
    bool parseNextIntFromLine(int32_t& value);
};

#endif // STREAMING_PULSE_PAYLOAD_H

