#ifndef StringBuffer_h
#define StringBuffer_h

#include <cstring>
#include <cstdio>
#include <cstdarg>

/**
 * Optimized buffer for working with strings on microcontrollers
 * Uses static memory instead of dynamic allocations
 */
template<size_t MaxSize = 512>
class StringBuffer {
private:
    char buffer[MaxSize];
    size_t length;
    
public:
    StringBuffer() : length(0) {
        buffer[0] = '\0';
    }
    
    // Clear buffer
    void clear() {
        length = 0;
        buffer[0] = '\0';
        // Zero the whole buffer for safety (avoid leftovers of old data)
        memset(buffer, 0, MaxSize);
    }
    
    // Append string
    bool append(const char* str) {
        size_t strLen = strlen(str);
        if (length + strLen >= MaxSize) {
            return false; // Overflow
        }
        strcpy(buffer + length, str);
        length += strLen;
        return true;
    }
    
    // Append string with specified length
    bool append(const char* str, size_t len) {
        if (length + len >= MaxSize) {
            return false; // Overflow
        }
        strncpy(buffer + length, str, len);
        length += len;
        buffer[length] = '\0';
        return true;
    }
    
    // Append character
    bool append(char c) {
        if (length + 1 >= MaxSize) {
            return false; // Overflow
        }
        buffer[length] = c;
        buffer[length + 1] = '\0';
        length++;
        return true;
    }
    
    // Formatted print
    bool printf(const char* format, ...) {
        va_list args;
        va_start(args, format);
        int result = vsnprintf(buffer + length, MaxSize - length, format, args);
        va_end(args);
        
        if (result < 0 || length + result >= MaxSize) {
            return false; // Overflow
        }
        length += result;
        return true;
    }
    
    // Accessors
    const char* c_str() const { return buffer; }
    size_t size() const { return length; }
    size_t capacity() const { return MaxSize; }
    bool empty() const { return length == 0; }
    
    // Operators for compatibility
    operator const char*() const { return buffer; }
};

/**
 * Specialized buffers for different tasks
 * OPTIMIZED: Sizes reduced to save memory
 */
using JsonBuffer = StringBuffer<2048>;      // For JSON responses (reduced from 16KB to 2KB - sufficient for most responses)
using PathBuffer = StringBuffer<128>;       // For file paths
using LogBuffer = StringBuffer<256>;        // For logs
using CommandBuffer = StringBuffer<64>;     // For commands
using ChunkBuffer = StringBuffer<800>;      // For streaming chunking (800B for CHUNK_SEND_SIZE)

#endif // StringBuffer_h

