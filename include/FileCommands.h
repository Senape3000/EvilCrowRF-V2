#ifndef FileCommands_h
#define FileCommands_h

#include "StringBuffer.h"
#include "core/ble/CommandHandler.h"
#include "core/ble/ClientsManager.h"
#include "StringHelpers.h"
#include "BinaryMessages.h"
#include "core/ble/BleAdapter.h"
#include "SD.h"
#include <LittleFS.h>
#include "Arduino.h"
#include <cstring>  // For strrchr
#include <vector>   // For std::vector
#include "ff.h"     // FATFS low-level API for fast directory reading

// Forward declarations
extern ClientsManager& clients;

/**
 * File commands using static buffers
 * instead of dynamic strings to save memory on microcontrollers
 */
class FileCommands {
public:
    static void registerCommands(CommandHandler& handler) {
        handler.registerCommand(0x05, handleGetFilesList);
        handler.registerCommand(0x09, handleLoadFileData);
        handler.registerCommand(0x0B, handleRemoveFile);
        handler.registerCommand(0x0C, handleRenameFile);
        handler.registerCommand(0x0A, handleCreateDirectory);
        // 0x0D (upload) is handled specially in BleAdapter::handleUploadChunk, not via CommandHandler
        handler.registerCommand(0x0E, handleCopyFile);
        handler.registerCommand(0x0F, handleMoveFile);
        handler.registerCommand(0x10, handleSaveToSignalsWithName);
        handler.registerCommand(0x14, handleGetDirectoryTree); // Changed from 0x12 to avoid conflict with startJam
    }
    
private:
    // Static buffers to avoid dynamic allocations
    static JsonBuffer jsonBuffer;
    static PathBuffer pathBuffer;
    static LogBuffer logBuffer;
    
    // Helper functions for path operations

    /**
     * Returns the appropriate filesystem for the given pathType.
     * pathType 0-3 and 5 use SD card, pathType 4 uses LittleFS (internal flash).
     */
    static fs::FS& getFS(uint8_t pathType) {
        if (pathType == 4) return LittleFS;
        return SD;
    }

    /**
     * Buffered file copy between two open File handles.
     * Uses a 512-byte stack buffer for efficient block transfer
     * instead of byte-by-byte read/write.
     * @return true on success, false on write error
     */
    static bool bufferedFileCopy(File& src, File& dst) {
        uint8_t buf[512];
        while (src.available()) {
            size_t toRead = std::min((size_t)src.available(), sizeof(buf));
            size_t bytesRead = src.read(buf, toRead);
            if (bytesRead == 0) break;
            size_t written = dst.write(buf, bytesRead);
            if (written != bytesRead) return false;
        }
        return true;
    }

    /**
     * Builds base path from pathType
     * @param pathType 0=RECORDS, 1=SIGNALS, 2=PRESETS, 3=TEMP, 4=INTERNAL (LittleFS root), 5=SD root
     * @param buffer buffer to receive result
     */
    static void buildBasePath(uint8_t pathType, PathBuffer& buffer) {
        buffer.clear();
        if (pathType == 4 || pathType == 5) {
            // Root-based storage (LittleFS for 4, SD root for 5)
            return;
        }
        buffer.append("/DATA/");
        switch (pathType) {
            case 0: buffer.append("RECORDS"); break;
            case 1: buffer.append("SIGNALS"); break;
            case 2: buffer.append("PRESETS"); break;
            case 3: buffer.append("TEMP"); break;
            default: buffer.append("RECORDS"); break;
        }
    }
    
    /**
     * Builds full path from pathType and relative path
     * @param pathType 0=RECORDS, 1=SIGNALS, 2=PRESETS, 3=TEMP, 4=INTERNAL, 5=SD root
     * @param relativePath relative path (may be empty or "/")
     * @param pathLen length of relative path
     * @param buffer buffer to receive result
     */
    static void buildFullPath(uint8_t pathType, const char* relativePath, size_t pathLen, PathBuffer& buffer) {
        buildBasePath(pathType, buffer);

        // For root-based storages (pathType 4/5), base path is empty so start with "/"
        if ((pathType == 4 || pathType == 5) && buffer.size() == 0) {
            buffer.append("/");
        }
        
        // Add path if not root
        if (pathLen > 0) {
                // Check whether the path is root
            if (pathLen != 1 || relativePath[0] != '/') {
                buffer.append("/");
                
                // Remove leading slash if present
                if (relativePath[0] == '/') {
                    buffer.append(relativePath + 1, pathLen - 1);
                } else {
                    buffer.append(relativePath, pathLen);
                }
            } else {
                // Root path "/" - add trailing slash for directory
                buffer.append("/");
            }
        } else {
            // Empty path - add trailing slash for root directory
            buffer.append("/");
        }
    }
    
    /**
     * Extracts filename from full path
     * @param fullPath full path
     * @param filename buffer to receive filename
     */
    static void extractFilename(const char* fullPath, PathBuffer& filename) {
        filename.clear();
        const char* lastSlash = strrchr(fullPath, '/');
        if (lastSlash) {
            filename.append(lastSlash + 1);
        } else {
            filename.append(fullPath);
        }
    }
    
    // Binary tree builder
    static void buildDirectoryTreeBinaryRecursive(const char* path, uint8_t* buffer, size_t& offset, uint16_t& count, size_t maxBufferSize = 1024) {
        // Use FATFS low-level API for O(n) directory traversal
        char fatfsPath[256];
        snprintf(fatfsPath, sizeof(fatfsPath), "/sd%s", path);
        
        FF_DIR fatDir;
        FILINFO fno;
        FRESULT res = f_opendir(&fatDir, fatfsPath);
        if (res != FR_OK) {
            // Try without /sd prefix
            res = f_opendir(&fatDir, path);
            if (res != FR_OK) {
                return;
            }
        }
        
        uint16_t entriesProcessed = 0;
        while (true) {
            res = f_readdir(&fatDir, &fno);
            if (res != FR_OK || fno.fname[0] == 0) {
                // No more entries
                break;
            }
            
            // Skip . and ..
            if (fno.fname[0] == '.' && (fno.fname[1] == '\0' || (fno.fname[1] == '.' && fno.fname[2] == '\0'))) {
                continue;
            }
            
            // Check if it's a directory
            bool isDir = (fno.fname[0] != 0 && (fno.fattrib & AM_DIR) != 0);
            
            if (isDir) {
                // Build full path
                char dirPath[256];
                if (strcmp(path, "/") == 0) {
                    snprintf(dirPath, sizeof(dirPath), "/%s", fno.fname);
                } else {
                    snprintf(dirPath, sizeof(dirPath), "%s/%s", path, fno.fname);
                }
                
                uint8_t pathLen = (uint8_t)strlen(dirPath);
                
                // Check buffer space
                if (offset + 1 + pathLen >= maxBufferSize) {
                    // Buffer full, cannot add more
                    break;
                }
                
                buffer[offset++] = pathLen;
                memcpy(buffer + offset, dirPath, pathLen);
                offset += pathLen;
                count++;
                
                // Recurse into subdirectory
                buildDirectoryTreeBinaryRecursive(dirPath, buffer, offset, count, maxBufferSize);
            }
            
            entriesProcessed++;
            // Yield every 10 entries to prevent watchdog timeout
            if (entriesProcessed % 10 == 0) {
                vTaskDelay(pdMS_TO_TICKS(5));
            }
        }
        
        f_closedir(&fatDir);
    }
    
public:
    // Get files list - STREAMING BINARY PROTOCOL (no JSON!)
    // Sends multiple messages for large directories to minimize memory usage.
    // 
    // Response format (each message):
    // [0xA1][pathLen:1][path:pathLen][flags:1][totalFiles:2][fileCount:1][files...]
    //
    // flags byte:
    //   bit 0 (0x01): hasMore - 1=more messages coming, 0=last message
    //   bit 7 (0x80): error - if set, bits 1-6 contain error code, fileCount=0
    //
    // totalFiles: total number of files in directory (for progress calculation)
    // fileCount: number of files in THIS message (1 byte, max 255)
    //
    // For each file:
    //   [nameLen:1][name:nameLen][fileFlags:1]
    //   If file (fileFlags & 0x01 == 0):
    //     [size:4][date:4]  (little-endian)
    //
    // Error codes (when flags & 0x80):
    //   1 = insufficient memory
    //   2 = failed to create directory
    //   3 = failed to open directory
    //   4 = path is not a directory
    //   5 = unknown error
    static bool handleGetFilesList(const uint8_t* data, size_t len) {
        // CRITICAL: Prevent concurrent execution
        static bool isProcessing = false;
        if (isProcessing) {
            ESP_LOGW("FileCommands", "handleGetFilesList already in progress");
            return false;
        }
        
        isProcessing = true;
        bool success = false;
        
        if (len < 2) {
            isProcessing = false;
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        
        if (len < 2 + pathLength) {
            isProcessing = false;
            return false;
        }
        
        // Build full path
        const char* path = (pathLength > 0) ? reinterpret_cast<const char*>(data + 2) : nullptr;
        buildFullPath(pathType, path, pathLength, pathBuffer);
        
        // Check memory
        if (ESP.getFreeHeap() < 3000) {
            sendBinaryFileListError(1);
            isProcessing = false;
            return true;
        }
        
        try {
            // Prepare directory path without trailing slash
            static PathBuffer dirPathWithoutSlash;
            dirPathWithoutSlash.clear();
            const char* pathStr = pathBuffer.c_str();
            size_t pathStrLen = strlen(pathStr);
            if (pathStrLen > 0 && pathStr[pathStrLen - 1] == '/') {
                dirPathWithoutSlash.append(pathStr, pathStrLen - 1);
            } else {
                dirPathWithoutSlash.append(pathStr, pathStrLen);
            }
            
            // Create directory if it doesn't exist (only dedicated SD folders 0..3)
            if (pathType <= 3 && !SD.exists(dirPathWithoutSlash.c_str())) {
                const char* dirPathStr = dirPathWithoutSlash.c_str();
                size_t dirPathLen = strlen(dirPathStr);
                static PathBuffer currentPath;
                
                for (size_t i = 1; i < dirPathLen; i++) {
                    if (dirPathStr[i] == '/') {
                        currentPath.clear();
                        currentPath.append(dirPathStr, i);
                        if (!SD.exists(currentPath.c_str())) {
                            SD.mkdir(currentPath.c_str());
                        }
                    }
                }
                
                if (!SD.mkdir(dirPathWithoutSlash.c_str())) {
                    sendBinaryFileListError(2);
                    isProcessing = false;
                    return true;
                }
            }

            // --- LittleFS listing (pathType 4) uses Arduino File API ---
            if (pathType == 4) {
                uint32_t streamStartTime = millis();
                const char* listPath = (dirPathWithoutSlash.size() > 0) 
                                       ? dirPathWithoutSlash.c_str() : "/";
                File root = LittleFS.open(listPath);
                if (!root || !root.isDirectory()) {
                    if (root) root.close();
                    // Try root "/" if requested path fails
                    root = LittleFS.open("/");
                    if (!root) {
                        sendBinaryFileListError(3);
                        isProcessing = false;
                        return true;
                    }
                }

                // Collect all entries (LittleFS typically has <10 files)
                const size_t BUFFER_SIZE = 500;
                static uint8_t binaryBuffer[BUFFER_SIZE];
                size_t pathLen = strlen(pathBuffer.c_str());
                uint16_t totalFilesSent = 0;

                size_t bufferOffset = 0;
                binaryBuffer[bufferOffset++] = MSG_FILE_LIST;
                binaryBuffer[bufferOffset++] = (uint8_t)pathLen;
                memcpy(binaryBuffer + bufferOffset, pathBuffer.c_str(), pathLen);
                bufferOffset += pathLen;

                size_t flagsOffset = bufferOffset++;
                size_t totalFilesOffset = bufferOffset;
                bufferOffset += 2;
                size_t fileCountOffset = bufferOffset++;

                File child = root.openNextFile();
                while (child) {
                    const char* name = child.name();
                    // Strip leading '/' if present
                    if (name[0] == '/') name++;
                    uint8_t nameLen = strlen(name);
                    if (nameLen > 255) nameLen = 255;
                    bool isDir = child.isDirectory();
                    uint32_t fileSize = isDir ? 0 : child.size();

                    size_t entrySize = 1 + nameLen + 1 + (isDir ? 0 : 8);
                    if (bufferOffset + entrySize >= BUFFER_SIZE - 4) break; // safety margin

                    binaryBuffer[bufferOffset++] = nameLen;
                    memcpy(binaryBuffer + bufferOffset, name, nameLen);
                    bufferOffset += nameLen;
                    binaryBuffer[bufferOffset++] = isDir ? 0x01 : 0x00;

                    if (!isDir) {
                        binaryBuffer[bufferOffset++] = fileSize & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileSize >> 8) & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileSize >> 16) & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileSize >> 24) & 0xFF;
                        // No timestamp available on LittleFS, send 0
                        binaryBuffer[bufferOffset++] = 0;
                        binaryBuffer[bufferOffset++] = 0;
                        binaryBuffer[bufferOffset++] = 0;
                        binaryBuffer[bufferOffset++] = 0;
                    }

                    totalFilesSent++;
                    child = root.openNextFile();
                }
                root.close();

                binaryBuffer[flagsOffset] = 0x00; // No more messages
                binaryBuffer[fileCountOffset] = (uint8_t)totalFilesSent;
                binaryBuffer[totalFilesOffset] = totalFilesSent & 0xFF;
                binaryBuffer[totalFilesOffset + 1] = (totalFilesSent >> 8) & 0xFF;

                clients.notifyAllBinary(NotificationType::FileSystem, binaryBuffer, bufferOffset);

                uint32_t totalTime = millis() - streamStartTime;
                ESP_LOGD("FileCommands", "LittleFS list: %d files, %lu ms", totalFilesSent, totalTime);
                isProcessing = false;
                return true;
            }
            
            // Use FATFS directly for O(n) directory reading instead of O(n²)
            // Arduino's openNextFile() rescans from beginning each time
            uint32_t streamStartTime = millis();
            
            // Build FATFS path (needs /sd prefix for ESP32)
            char fatfsPath[270];
            if (dirPathWithoutSlash.size() > 0) {
                snprintf(fatfsPath, sizeof(fatfsPath), "/sd%s", dirPathWithoutSlash.c_str());
            } else {
                snprintf(fatfsPath, sizeof(fatfsPath), "/sd%s", pathBuffer.c_str());
            }
            
            FF_DIR fatDir;
            FILINFO fno;
            FRESULT res = f_opendir(&fatDir, fatfsPath);
            if (res != FR_OK) {
                // Try without /sd prefix
                res = f_opendir(&fatDir, dirPathWithoutSlash.c_str());
                if (res != FR_OK) {
                    sendBinaryFileListError(3);
                    isProcessing = false;
                    return true;
                }
            }
            
            // STREAMING: Use buffer that fits in single BLE chunk (MAX_CHUNK_SIZE = 500)
            // BLE notify limit is 509 bytes, so 500 bytes data + 7 header + 1 checksum = 508 bytes total
            const size_t BUFFER_SIZE = 500;
            const size_t MAX_FILES_PER_MESSAGE = 50;  // More files per message since reading is faster now
            static uint8_t binaryBuffer[BUFFER_SIZE];
            
            size_t pathLen = strlen(pathBuffer.c_str());
            
            uint16_t totalFilesSent = 0;
            bool hasMoreFiles = true;
            bool lowMemory = false;
            uint8_t messagesSent = 0;
            
            // Pending file info (when buffer is full, save file for next iteration)
            static char pendingFilename[256];
            static bool hasPendingFile = false;
            static bool pendingIsDir = false;
            static uint32_t pendingFileSize = 0;
            static uint32_t pendingFileDate = 0;
            
            hasPendingFile = false;
            
            while (hasMoreFiles && !lowMemory) {
                uint32_t msgStartTime = millis();
                
                // Build message header
                size_t bufferOffset = 0;
                binaryBuffer[bufferOffset++] = MSG_FILE_LIST;  // 0xA1
                binaryBuffer[bufferOffset++] = (uint8_t)pathLen;
                memcpy(binaryBuffer + bufferOffset, pathBuffer.c_str(), pathLen);
                bufferOffset += pathLen;
                
                size_t flagsOffset = bufferOffset++;
                size_t totalFilesOffset = bufferOffset;
                bufferOffset += 2;
                size_t fileCountOffset = bufferOffset++;
                
                uint8_t filesInThisMessage = 0;
                
                // First, add pending file from previous iteration
                if (hasPendingFile) {
                    uint8_t nameLen = strlen(pendingFilename);
                    size_t entrySize = 1 + nameLen + 1 + (pendingIsDir ? 0 : 8);
                    
                    binaryBuffer[bufferOffset++] = nameLen;
                    memcpy(binaryBuffer + bufferOffset, pendingFilename, nameLen);
                    bufferOffset += nameLen;
                    binaryBuffer[bufferOffset++] = pendingIsDir ? 0x01 : 0x00;
                    
                    if (!pendingIsDir) {
                        binaryBuffer[bufferOffset++] = pendingFileSize & 0xFF;
                        binaryBuffer[bufferOffset++] = (pendingFileSize >> 8) & 0xFF;
                        binaryBuffer[bufferOffset++] = (pendingFileSize >> 16) & 0xFF;
                        binaryBuffer[bufferOffset++] = (pendingFileSize >> 24) & 0xFF;
                        binaryBuffer[bufferOffset++] = pendingFileDate & 0xFF;
                        binaryBuffer[bufferOffset++] = (pendingFileDate >> 8) & 0xFF;
                        binaryBuffer[bufferOffset++] = (pendingFileDate >> 16) & 0xFF;
                        binaryBuffer[bufferOffset++] = (pendingFileDate >> 24) & 0xFF;
                    }
                    
                    filesInThisMessage++;
                    totalFilesSent++;
                    hasPendingFile = false;
                }
                
                // Read directory entries using FATFS - O(n) complexity!
                while (filesInThisMessage < MAX_FILES_PER_MESSAGE) {
                    res = f_readdir(&fatDir, &fno);
                    if (res != FR_OK || fno.fname[0] == 0) {
                        // No more files
                        break;
                    }
                    
                    // Skip . and ..
                    if (fno.fname[0] == '.') continue;
                    
                    // Check memory
                    if (ESP.getFreeHeap() < 2000) {
                        lowMemory = true;
                        break;
                    }
                    
                    const char* filename = fno.fname;
                    uint8_t nameLen = strlen(filename);
                    if (nameLen > 255) nameLen = 255;
                    
                    bool isDir = (fno.fattrib & AM_DIR) != 0;
                    uint32_t fileSize = isDir ? 0 : fno.fsize;
                    
                    // Convert FAT date/time to Unix timestamp
                    // FAT date: bits 15-9=year-1980, 8-5=month, 4-0=day
                    // FAT time: bits 15-11=hour, 10-5=minute, 4-0=second/2
                    uint16_t fatDate = fno.fdate;
                    uint16_t fatTime = fno.ftime;
                    
                    // Manual conversion to Unix timestamp (seconds since 1970)
                    int year = ((fatDate >> 9) & 0x7F) + 1980;
                    int month = ((fatDate >> 5) & 0x0F);
                    int day = fatDate & 0x1F;
                    int hour = (fatTime >> 11) & 0x1F;
                    int minute = (fatTime >> 5) & 0x3F;
                    int second = (fatTime & 0x1F) * 2;
                    
                    // Days from 1970 to year
                    uint32_t days = 0;
                    for (int y = 1970; y < year; y++) {
                        days += (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 366 : 365;
                    }
                    // Days in current year
                    static const int monthDays[] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};
                    if (month >= 1 && month <= 12) {
                        days += monthDays[month - 1];
                        // Leap year adjustment
                        if (month > 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))) {
                            days++;
                        }
                    }
                    days += (day > 0 ? day - 1 : 0);
                    
                    uint32_t fileDate = days * 86400 + hour * 3600 + minute * 60 + second;
                    
                    // Calculate entry size
                    size_t entrySize = 1 + nameLen + 1 + (isDir ? 0 : 8);
                    
                    // Check if entry fits in remaining buffer space
                    if (bufferOffset + entrySize >= BUFFER_SIZE - 16) {
                        // Buffer full - save this file for next iteration
                        strncpy(pendingFilename, filename, sizeof(pendingFilename) - 1);
                        pendingFilename[sizeof(pendingFilename) - 1] = 0;
                        pendingIsDir = isDir;
                        pendingFileSize = fileSize;
                        pendingFileDate = fileDate;
                        hasPendingFile = true;
                        break;
                    }
                    
                    // Add file entry to buffer
                    binaryBuffer[bufferOffset++] = nameLen;
                    memcpy(binaryBuffer + bufferOffset, filename, nameLen);
                    bufferOffset += nameLen;
                    binaryBuffer[bufferOffset++] = isDir ? 0x01 : 0x00;
                    
                    if (!isDir) {
                        binaryBuffer[bufferOffset++] = fileSize & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileSize >> 8) & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileSize >> 16) & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileSize >> 24) & 0xFF;
                        binaryBuffer[bufferOffset++] = fileDate & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileDate >> 8) & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileDate >> 16) & 0xFF;
                        binaryBuffer[bufferOffset++] = (fileDate >> 24) & 0xFF;
                    }
                    
                    filesInThisMessage++;
                    totalFilesSent++;
                    
                    // Yield every 20 files to prevent watchdog (faster now, so less frequent)
                    if (filesInThisMessage % 20 == 0) {
                        vTaskDelay(pdMS_TO_TICKS(1));
                    }
                }
                uint32_t readTime = millis() - msgStartTime;
                
                // Check if we read all files (no pending and last f_readdir returned empty)
                if (!hasPendingFile && (res != FR_OK || fno.fname[0] == 0)) {
                    hasMoreFiles = false;
                }
                
                // Update flags and fileCount
                binaryBuffer[flagsOffset] = hasMoreFiles ? 0x01 : 0x00;
                binaryBuffer[fileCountOffset] = filesInThisMessage;
                
                // Set totalFiles: 0xFFFF if more coming, actual count if this is last message
                if (hasMoreFiles) {
                    binaryBuffer[totalFilesOffset] = 0xFF;
                    binaryBuffer[totalFilesOffset + 1] = 0xFF;
                } else {
                    binaryBuffer[totalFilesOffset] = totalFilesSent & 0xFF;
                    binaryBuffer[totalFilesOffset + 1] = (totalFilesSent >> 8) & 0xFF;
                }
                
                // Send this message
                if (filesInThisMessage > 0 || !hasMoreFiles) {
                    clients.notifyAllBinary(NotificationType::FileSystem, binaryBuffer, bufferOffset);
                    messagesSent++;
                    
                    // Log only in debug mode to save resources in production
                    ESP_LOGD("FileCommands", "Msg %d: %d files, read=%lums", 
                             messagesSent, filesInThisMessage, readTime);
                    
                    // Small delay to allow mobile app to process chunks and update UI
                    // Reduced from 150ms to 50ms - chunk processing is fast, and we have
                    // improved chunk buffer cleanup on mobile side. BLE notifications are queued,
                    // so this prevents overwhelming the receiver while still being responsive
                    // In production, reduce delay slightly for better performance
                    vTaskDelay(pdMS_TO_TICKS(30));
                }
                
                // Safety: prevent infinite loop
                if (filesInThisMessage == 0 && !hasPendingFile) {
                    hasMoreFiles = false;
                }
            }
            
            f_closedir(&fatDir);
            
            uint32_t totalTime = millis() - streamStartTime;
            // Log only in debug mode to save resources in production
            ESP_LOGD("FileCommands", "File list complete: %d files, %d msgs, %lu ms total", 
                     totalFilesSent, messagesSent, totalTime);
            success = true;
            
        } catch (...) {
            sendBinaryFileListError(5);
        }
        
        isProcessing = false;
        return success;
    }
    
    // Send binary error response for file list
    // flags byte has bit 7 set (0x80) plus error code in bits 0-6
    static void sendBinaryFileListError(uint8_t errorCode) {
        size_t pathLen = strlen(pathBuffer.c_str());
        static uint8_t errorBuffer[264];
        size_t offset = 0;
        
        errorBuffer[offset++] = MSG_FILE_LIST;  // 0xA1
        errorBuffer[offset++] = (uint8_t)pathLen;
        memcpy(errorBuffer + offset, pathBuffer.c_str(), pathLen);
        offset += pathLen;
        errorBuffer[offset++] = 0x80 | (errorCode & 0x7F);  // Error flag + error code
        errorBuffer[offset++] = 0;  // totalFiles low = 0
        errorBuffer[offset++] = 0;  // totalFiles high = 0
        errorBuffer[offset++] = 0;  // fileCount = 0
        
        clients.notifyAllBinary(NotificationType::FileSystem, errorBuffer, offset);
    }

    // Send binary result for file action (delete, rename, etc.)
    static void sendBinaryFileActionResult(uint8_t action, bool success, uint8_t errorCode, const char* path = nullptr) {
        static uint8_t resultBuffer[260];
        size_t offset = 0;
        uint8_t pathLen = path ? (uint8_t)strlen(path) : 0;
        
        resultBuffer[offset++] = MSG_FILE_ACTION_RESULT;
        resultBuffer[offset++] = action;
        resultBuffer[offset++] = success ? 0 : 1;
        resultBuffer[offset++] = errorCode;
        resultBuffer[offset++] = pathLen;
        if (pathLen > 0) {
            memcpy(resultBuffer + offset, path, pathLen);
            offset += pathLen;
        }
        
        clients.notifyAllBinary(NotificationType::FileSystem, resultBuffer, offset);
    }
    
    // Load file data
    static bool handleLoadFileData(const uint8_t* data, size_t len) {
        if (len < 2) {
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        
        if (len < 2 + pathLength) {
            return false;
        }
        
        // Use helper function to build path
        const char* path = (pathLength > 0) ? reinterpret_cast<const char*>(data + 2) : nullptr;
        buildFullPath(pathType, path, pathLength, pathBuffer);
        
        ESP_LOGI("FileCommands", "Final path: '%s'", pathBuffer.c_str());
        
        // Check file existence
        fs::FS& fs = getFS(pathType);
        if (!fs.exists(pathBuffer.c_str())) {
            sendBinaryFileActionResult(7, false, 3, pathBuffer.c_str()); // 7=load, error 3=not found
            return true;
        }
        
        // STREAM file directly to BLE (NO buffering entire file!)
        File file = fs.open(pathBuffer.c_str(), FILE_READ);
        if (!file) {
            sendBinaryFileActionResult(7, false, 13, pathBuffer.c_str()); // error 13=failed to open
            return true;
        }
        
        size_t fileSize = file.size();
        ESP_LOGI("FileCommands", "Streaming file: %zu bytes", fileSize);
        
        // Build header: [0xA0][pathLen:1][path][fileSize:4]
        size_t fullPathLen = strlen(pathBuffer.c_str());
        const size_t MAX_HEADER_SIZE = 256;
        uint8_t header[MAX_HEADER_SIZE];
        
        if (1 + 1 + fullPathLen + 4 > MAX_HEADER_SIZE) {
            file.close();
            sendBinaryFileActionResult(7, false, 14, "Path too long"); // error 14=path too long
            return true;
        }
        
        size_t offset = 0;
        header[offset++] = 0xA0;  // MSG_FILE_CONTENT
        header[offset++] = (uint8_t)fullPathLen;
        memcpy(header + offset, pathBuffer.c_str(), fullPathLen);
        offset += fullPathLen;
        
        // File size (4 bytes, little-endian)
        header[offset++] = (fileSize >> 0) & 0xFF;
        header[offset++] = (fileSize >> 8) & 0xFF;
        header[offset++] = (fileSize >> 16) & 0xFF;
        header[offset++] = (fileSize >> 24) & 0xFF;
        
        size_t headerSize = offset;
        
        // TRUE STREAMING: Use BLE adapter's streaming method
        BleAdapter* bleAdapter = BleAdapter::getInstance();
        if (bleAdapter != nullptr) {
            bleAdapter->streamFileData(header, headerSize, file, fileSize);
            file.close();
        } else {
            file.close();
            sendBinaryFileActionResult(7, false, 15, "BLE adapter not found"); // error 15=no adapter
        }
        
        return true;
    }
    
    static bool handleRemoveFile(const uint8_t* data, size_t len) {
        if (len < 2) {
            sendBinaryFileActionResult(1, false, 1); // 1=delete, error 1=insufficient data
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        if (len < 2 + pathLength) {
            sendBinaryFileActionResult(1, false, 2); // error 2=path length mismatch
            return false;
        }
        
        // Build full path using helper function
        const char* path = reinterpret_cast<const char*>(data + 2);
        buildFullPath(pathType, path, pathLength, pathBuffer);
        
        // Check if path exists
        fs::FS& fs = getFS(pathType);
        if (!fs.exists(pathBuffer.c_str())) {
            sendBinaryFileActionResult(1, false, 3, pathBuffer.c_str()); // error 3=not found
            return false;
        }
        
        // Check if it's a directory or file and remove accordingly
        File file = fs.open(pathBuffer.c_str());
        bool isDirectory = file.isDirectory();
        file.close();
        
        bool ok = false;
        if (isDirectory) {
            ok = fs.rmdir(pathBuffer.c_str());
        } else {
            ok = fs.remove(pathBuffer.c_str());
        }
        
        sendBinaryFileActionResult(1, ok, ok ? 0 : 4, pathBuffer.c_str()); // error 4=delete failed
        return ok;
    }
    
    static bool handleRenameFile(const uint8_t* data, size_t len) {
        if (len < 3) {
            sendBinaryFileActionResult(2, false, 1); // 2=rename, error 1=insufficient data
            return false;
        }
        
        uint8_t pathType = data[0];
        uint8_t fromLength = data[1];
        if (len < 2 + fromLength + 1) {
            sendBinaryFileActionResult(2, false, 5); // error 5=to length missing
            return false;
        }
        
        const char* fromPtr = reinterpret_cast<const char*>(data + 2);
        uint8_t toLength = data[2 + fromLength];
        if (len < 3 + fromLength + toLength) {
            sendBinaryFileActionResult(2, false, 2); // error 2=path length mismatch
            return false;
        }
        const char* toPtr = reinterpret_cast<const char*>(data + 3 + fromLength);
        
        // Build full paths using helper functions
        buildFullPath(pathType, fromPtr, fromLength, pathBuffer);
        
        // Use a temporary PathBuffer for "to" path (we need both paths)
        static PathBuffer toPathBuffer;
        buildFullPath(pathType, toPtr, toLength, toPathBuffer);
        
        fs::FS& fs = getFS(pathType);
        bool ok = fs.exists(pathBuffer.c_str()) && fs.rename(pathBuffer.c_str(), toPathBuffer.c_str());
        
        sendBinaryFileActionResult(2, ok, ok ? 0 : 6, toPathBuffer.c_str()); // 2=rename, error 6=rename failed
        return ok;
    }
    
    static bool handleCreateDirectory(const uint8_t* data, size_t len) {
        if (len < 2) {
            sendBinaryFileActionResult(3, false, 1); // 3=mkdir, error 1=insufficient data
            return false;
        }
        
        uint8_t pathLength = data[0];
        uint8_t pathType = data[1];
        if (len < 2 + pathLength) {
            sendBinaryFileActionResult(3, false, 2); // error 2=path length mismatch
            return false;
        }
        
        // Build paths using helper functions
        const char* dirPtr = reinterpret_cast<const char*>(data + 2);
        buildFullPath(pathType, dirPtr, pathLength, pathBuffer);
        
        // Get base directory for checking/creating
        static PathBuffer baseDirBuffer;
        buildBasePath(pathType, baseDirBuffer);
        
        fs::FS& fs = getFS(pathType);
        // Create base directory if needed
        if (baseDirBuffer.size() > 0) {
            if (!fs.exists(baseDirBuffer.c_str())) {
                fs.mkdir(baseDirBuffer.c_str());
            }
        }
        
        // Recursive mkdir — create each path segment from root to leaf
        // SD/LittleFS mkdir() is NOT recursive, so we walk each '/' level
        const char* fullStr = pathBuffer.c_str();
        size_t fullLen = strlen(fullStr);
        bool ok = true;
        {
            char segment[256];
            strncpy(segment, fullStr, sizeof(segment) - 1);
            segment[sizeof(segment) - 1] = '\0';
            for (size_t i = 1; i < fullLen; i++) {
                if (segment[i] == '/') {
                    segment[i] = '\0';
                    if (!fs.exists(segment)) {
                        if (!fs.mkdir(segment)) {
                            ESP_LOGW("FileCommands", "mkdir failed for segment: %s", segment);
                        }
                    }
                    segment[i] = '/';
                }
            }
        }
        // Create the final directory itself
        if (!fs.exists(fullStr)) {
            ok = fs.mkdir(fullStr);
        }
        
        sendBinaryFileActionResult(3, ok, ok ? 0 : 7, pathBuffer.c_str()); // 3=mkdir, error 7=mkdir failed
        return ok;
    }
    
    static bool handleSaveToSignalsWithName(const uint8_t* data, size_t len) {
        if (len < 3) {
            sendBinaryFileActionResult(4, false, 1); // 4=copy, error 1=insufficient data
            return false;
        }
        
        // Parse source path length, target name length, and path type
        uint8_t sourcePathLength = data[0];
        uint8_t targetNameLength = data[1];
        uint8_t pathType = data[2];
        
        if (len < 3 + sourcePathLength + targetNameLength) {
            sendBinaryFileActionResult(4, false, 8); // error 8=path lengths mismatch
            return false;
        }
        
        // Extract source path
        if (sourcePathLength == 0 || sourcePathLength >= pathBuffer.capacity()) {
            sendBinaryFileActionResult(4, false, 9); // error 9=invalid source length
            return false;
        }
        
        const char* sourcePath = reinterpret_cast<const char*>(&data[3]);
        pathBuffer.clear();
        pathBuffer.append(sourcePath, sourcePathLength);
        
        // Extract target name to temporary buffer
        const char* targetName = reinterpret_cast<const char*>(&data[3 + sourcePathLength]);
        static PathBuffer targetNameBuffer;
        targetNameBuffer.clear();
        targetNameBuffer.append(targetName, targetNameLength);
        
        // Check if date is provided (4 bytes after target name)
        uint32_t fileDate = 0;
        bool hasDate = false;
        size_t expectedLen = 3 + sourcePathLength + targetNameLength;
        if (len >= expectedLen + 4) {
            // Read date (Unix timestamp in seconds, little-endian)
            fileDate = data[expectedLen] | 
                      (data[expectedLen + 1] << 8) | 
                      (data[expectedLen + 2] << 16) | 
                      (data[expectedLen + 3] << 24);
            hasDate = true;
            ESP_LOGI("FileCommands", "Date bytes: %02X %02X %02X %02X -> timestamp=%lu", 
                     data[expectedLen], data[expectedLen + 1], data[expectedLen + 2], data[expectedLen + 3],
                     (unsigned long)fileDate);
        } else {
            ESP_LOGI("FileCommands", "No date provided: len=%zu, expected=%zu", len, expectedLen + 4);
        }
        
        ESP_LOGI("FileCommands", "SaveToSignalsWithName: sourcePath=%s, targetName=%s, pathType=%d%s", 
                 pathBuffer.c_str(), targetNameBuffer.c_str(), pathType,
                 hasDate ? ", date provided" : "");
        
        // Build destination path using helper function
        static PathBuffer destPathBuffer;
        buildBasePath(pathType, destPathBuffer);
        destPathBuffer.append("/");
        destPathBuffer.append(targetNameBuffer.c_str());
        
        // Source is always on SD (absolute path from RECORDS/SIGNALS)
        // Destination uses the pathType filesystem
        fs::FS& destFS = getFS(pathType);

        // Check if source file exists (source is always SD)
        if (!SD.exists(pathBuffer.c_str())) {
            sendBinaryFileActionResult(4, false, 3, pathBuffer.c_str()); // error 3=not found
            return false;
        }
        
        // Create destination directory if it doesn't exist
        static PathBuffer baseDirBuffer;
        buildBasePath(pathType, baseDirBuffer);
        if (baseDirBuffer.size() > 0 && !destFS.exists(baseDirBuffer.c_str())) {
            destFS.mkdir(baseDirBuffer.c_str());
        }
        
        // Copy file from source to destination
        File sourceFile = SD.open(pathBuffer.c_str(), FILE_READ);
        if (!sourceFile) {
            sendBinaryFileActionResult(4, false, 10, pathBuffer.c_str()); // error 10=failed to open source
            return false;
        }
        
        File destFile = destFS.open(destPathBuffer.c_str(), FILE_WRITE);
        if (!destFile) {
            sourceFile.close();
            sendBinaryFileActionResult(4, false, 11, destPathBuffer.c_str()); // error 11=failed to create dest
            return false;
        }
        
        // Buffer-based file copy (512 bytes at a time)
        if (!bufferedFileCopy(sourceFile, destFile)) {
            ESP_LOGE("FileCommands", "Buffered copy failed");
        }
        
        sourceFile.close();
        destFile.close();
        
        // Set file date if provided (must be done immediately after close, before releasing mutex)
        if (hasDate && fileDate > 0) {
            ESP_LOGI("FileCommands", "Setting file date: timestamp=%lu", (unsigned long)fileDate);
            
            // Manual conversion from Unix timestamp to FAT date/time (avoid gmtime stack issues)
            uint32_t days = fileDate / 86400;
            uint32_t seconds = fileDate % 86400;
            
            // Calculate year (simplified, good for 1980-2100)
            uint32_t year = 1970;
            uint32_t dayOfYear = days;
            while (dayOfYear >= 365) {
                bool isLeap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
                uint32_t daysInYear = isLeap ? 366 : 365;
                if (dayOfYear >= daysInYear) {
                    dayOfYear -= daysInYear;
                    year++;
                } else {
                    break;
                }
            }
            
            // Calculate month and day
            uint32_t month = 1;
            uint32_t day = dayOfYear + 1;
            const uint8_t daysInMonth[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
            bool isLeap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
            
            for (uint32_t m = 0; m < 12; m++) {
                uint32_t daysInM = daysInMonth[m];
                if (m == 1 && isLeap) daysInM = 29;
                if (day > daysInM) {
                    day -= daysInM;
                    month++;
                } else {
                    break;
                }
            }
            
            // Calculate hour, minute, second
            uint32_t hour = seconds / 3600;
            uint32_t minute = (seconds % 3600) / 60;
            uint32_t second = seconds % 60;
            
            ESP_LOGI("FileCommands", "Converted date: %04lu-%02lu-%02lu %02lu:%02lu:%02lu", 
                     (unsigned long)year, (unsigned long)month, (unsigned long)day,
                     (unsigned long)hour, (unsigned long)minute, (unsigned long)second);
            
            if (year >= 1980 && year < 2108) {
                FILINFO fno;
                fno.fname[0] = '\0';
                
                // FAT date: bits 15-9=year-1980, 8-5=month, 4-0=day
                fno.fdate = ((year - 1980) << 9) | (month << 5) | day;
                // FAT time: bits 15-11=hour, 10-5=minute, 4-0=second/2
                fno.ftime = (hour << 11) | (minute << 5) | (second / 2);
                
                ESP_LOGI("FileCommands", "FAT date=0x%04X, time=0x%04X", fno.fdate, fno.ftime);
                
                // Use FATFS directly with the destination path (no /sd prefix needed for f_utime)
                // f_utime works with the path as used by SD library
                ESP_LOGI("FileCommands", "Setting time on file: %s", destPathBuffer.c_str());
                
                // Try to set time using f_utime directly (doesn't require file to be open)
                FRESULT res = f_utime(destPathBuffer.c_str(), &fno);
                if (res == FR_OK) {
                    ESP_LOGI("FileCommands", "File time set successfully");
                } else {
                    ESP_LOGW("FileCommands", "f_utime failed: %d, trying with file open", res);
                    
                    // Fallback: open file and try again
                    FIL file;
                    res = f_open(&file, destPathBuffer.c_str(), FA_WRITE | FA_OPEN_EXISTING);
                    if (res == FR_OK) {
                        // Try f_utime again with file open
                        res = f_utime(destPathBuffer.c_str(), &fno);
                        f_close(&file);
                        
                        if (res == FR_OK) {
                            ESP_LOGI("FileCommands", "File time set successfully (with file open)");
                        } else {
                            ESP_LOGW("FileCommands", "f_utime failed even with file open: %d", res);
                        }
                    } else {
                        ESP_LOGW("FileCommands", "Failed to open file for time setting: %d", res);
                    }
                }
            } else {
                ESP_LOGW("FileCommands", "Year %lu out of range (1980-2107)", (unsigned long)year);
            }
        }
        
        ESP_LOGI("FileCommands", "File copied successfully: %s -> %s%s", 
                 pathBuffer.c_str(), destPathBuffer.c_str(),
                 hasDate ? " (date preserved)" : "");
        
        // Send success response
        sendBinaryFileActionResult(4, true, 0, destPathBuffer.c_str());
        
        return true;
    }
    
    // Copy file
    static bool handleCopyFile(const uint8_t* data, size_t len) {
        if (len < 3) {
            sendBinaryFileActionResult(4, false, 1); // 4=copy, error 1=insufficient data
            return false;
        }
        
        uint8_t pathType = data[0];
        uint8_t sourceLength = data[1];
        if (len < 2 + sourceLength + 1) {
            sendBinaryFileActionResult(4, false, 12); // error 12=dest length missing
            return false;
        }
        
        const char* sourcePtr = reinterpret_cast<const char*>(data + 2);
        uint8_t destLength = data[2 + sourceLength];
        if (len < 3 + sourceLength + destLength) {
            sendBinaryFileActionResult(4, false, 2); // error 2=path length mismatch
            return false;
        }
        const char* destPtr = reinterpret_cast<const char*>(data + 3 + sourceLength);
        
        // Build full paths
        buildFullPath(pathType, sourcePtr, sourceLength, pathBuffer);
        
        static PathBuffer destPathBuffer;
        buildFullPath(pathType, destPtr, destLength, destPathBuffer);
        
        // Use correct filesystem for the pathType
        fs::FS& fs = getFS(pathType);

        // Check if source exists
        if (!fs.exists(pathBuffer.c_str())) {
            sendBinaryFileActionResult(4, false, 3, pathBuffer.c_str()); // error 3=not found
            return false;
        }
        
        // Copy file using buffered transfer
        File sourceFile = fs.open(pathBuffer.c_str(), FILE_READ);
        if (!sourceFile) {
            sendBinaryFileActionResult(4, false, 10, pathBuffer.c_str());
            return false;
        }
        
        File destFile = fs.open(destPathBuffer.c_str(), FILE_WRITE);
        if (!destFile) {
            sourceFile.close();
            sendBinaryFileActionResult(4, false, 11, destPathBuffer.c_str());
            return false;
        }
        
        if (!bufferedFileCopy(sourceFile, destFile)) {
            ESP_LOGE("FileCommands", "Buffered copy failed");
        }
        
        sourceFile.close();
        destFile.close();
        
        sendBinaryFileActionResult(4, true, 0, destPathBuffer.c_str());
        return true;
    }
    
    // Move file - supports different pathType for source and destination
    // Format: [sourcePathType:1][destPathType:1][sourcePathLength:1][sourcePath:variable][destPathLength:1][destPath:variable]
    static bool handleMoveFile(const uint8_t* data, size_t len) {
        if (len < 4) {
            sendBinaryFileActionResult(5, false, 1); // 5=move, error 1=insufficient data
            return false;
        }
        
        uint8_t sourcePathType = data[0];
        uint8_t destPathType = data[1];
        uint8_t sourceLength = data[2];
        if (len < 3 + sourceLength + 1) {
            sendBinaryFileActionResult(5, false, 12); // error 12=dest length missing
            return false;
        }
        
        const char* sourcePtr = reinterpret_cast<const char*>(data + 3);
        uint8_t destLength = data[3 + sourceLength];
        if (len < 4 + sourceLength + destLength) {
            sendBinaryFileActionResult(5, false, 2); // error 2=path length mismatch
            return false;
        }
        const char* destPtr = reinterpret_cast<const char*>(data + 4 + sourceLength);
        
        // Build full paths using respective pathTypes
        buildFullPath(sourcePathType, sourcePtr, sourceLength, pathBuffer);
        
        static PathBuffer destPathBuffer;
        buildFullPath(destPathType, destPtr, destLength, destPathBuffer);
        
        // Use correct filesystem for each pathType
        fs::FS& srcFS = getFS(sourcePathType);
        fs::FS& dstFS = getFS(destPathType);

        // Check if source exists
        if (!srcFS.exists(pathBuffer.c_str())) {
            sendBinaryFileActionResult(5, false, 3, pathBuffer.c_str()); // error 3=not found
            return false;
        }
        
        // If moving within the same storage type, use rename (fast)
        bool ok = false;
        if (sourcePathType == destPathType) {
            ok = srcFS.rename(pathBuffer.c_str(), destPathBuffer.c_str());
        } else {
            // Cross-storage move: copy then delete
            File sourceFile = srcFS.open(pathBuffer.c_str(), FILE_READ);
            if (!sourceFile) {
                sendBinaryFileActionResult(5, false, 10, pathBuffer.c_str());
                return false;
            }
            
            File destFile = dstFS.open(destPathBuffer.c_str(), FILE_WRITE);
            if (!destFile) {
                sourceFile.close();
                sendBinaryFileActionResult(5, false, 11, destPathBuffer.c_str());
                return false;
            }
            
            // Buffer-based file copy
            if (!bufferedFileCopy(sourceFile, destFile)) {
                ESP_LOGE("FileCommands", "Cross-storage copy failed");
            }
            
            sourceFile.close();
            destFile.close();
            
            // Delete source file from source filesystem
            ok = srcFS.remove(pathBuffer.c_str());
        }
        
        sendBinaryFileActionResult(5, ok, ok ? 0 : 6, destPathBuffer.c_str()); // 5=move, error 6=move failed
        return ok;
    }
    
    // Collect directory paths (recursive, stores paths for streaming)
    static void collectDirectoryPaths(const char* basePath, std::vector<String>& paths) {
        char fatfsPath[256];
        snprintf(fatfsPath, sizeof(fatfsPath), "/sd%s", basePath);
        
        FF_DIR fatDir;
        FILINFO fno;
        FRESULT res = f_opendir(&fatDir, fatfsPath);
        if (res != FR_OK) {
            res = f_opendir(&fatDir, basePath);
            if (res != FR_OK) {
                return;
            }
        }
        
        uint16_t entriesProcessed = 0;
        while (true) {
            res = f_readdir(&fatDir, &fno);
            if (res != FR_OK || fno.fname[0] == 0) {
                break;
            }
            
            // Skip . and ..
            if (fno.fname[0] == '.' && (fno.fname[1] == '\0' || (fno.fname[1] == '.' && fno.fname[2] == '\0'))) {
                continue;
            }
            
            // Check if it's a directory
            bool isDir = (fno.fname[0] != 0 && (fno.fattrib & AM_DIR) != 0);
            
            if (isDir) {
                // Build full path
                char dirPath[256];
                if (strcmp(basePath, "/") == 0) {
                    snprintf(dirPath, sizeof(dirPath), "/%s", fno.fname);
                } else {
                    snprintf(dirPath, sizeof(dirPath), "%s/%s", basePath, fno.fname);
                }
                
                // Add to paths list
                paths.push_back(String(dirPath));
                
                // Recurse into subdirectory
                collectDirectoryPaths(dirPath, paths);
            }
            
            entriesProcessed++;
            // Yield every 10 entries to prevent watchdog timeout
            if (entriesProcessed % 10 == 0) {
                vTaskDelay(pdMS_TO_TICKS(5));
            }
        }
        
        f_closedir(&fatDir);
    }
    
    // Get directory tree (only directories, recursive) - STREAMING VERSION
    // Format: [0xA2][pathType:1][flags:1][totalDirs:2][dirCount:2][paths...]
    // flags: bit 0 (0x01) = hasMore, bit 7 (0x80) = error
    // For each path: [pathLen:1][path:pathLen]
    static bool handleGetDirectoryTree(const uint8_t* data, size_t len) {
        if (len < 1) {
            sendBinaryDirectoryTreeError(1); // error 1=insufficient data
            return false;
        }
        
        uint8_t pathType = data[0];
        buildBasePath(pathType, pathBuffer);
        
        ESP_LOGI("FileCommands", "Getting directory tree for pathType=%d, basePath='%s'", pathType, pathBuffer.c_str());
        
        // Check memory
        if (ESP.getFreeHeap() < 3000) {
            sendBinaryDirectoryTreeError(1); // error 1=insufficient memory
            return true;
        }
        
        try {
            // Collect all directory paths first
            std::vector<String> paths;
            collectDirectoryPaths(pathBuffer.c_str(), paths);
            
            uint16_t totalDirs = paths.size();
            ESP_LOGI("FileCommands", "Collected %d directories, starting stream", totalDirs);
            
            // STREAMING: Use 2KB buffer, send multiple messages if needed
            const size_t BUFFER_SIZE = 2048;
            static uint8_t binaryBuffer[BUFFER_SIZE];
            
            uint16_t dirsSent = 0;
            size_t pathIndex = 0;
            bool hasMorePaths = true;
            
            while (hasMorePaths) {
                size_t bufferOffset = 0;
                
                // Build message header
                binaryBuffer[bufferOffset++] = MSG_DIRECTORY_TREE;  // 0xA2
                binaryBuffer[bufferOffset++] = pathType;
                
                size_t flagsOffset = bufferOffset++;
                size_t totalDirsOffset = bufferOffset;
                bufferOffset += 2; // totalDirs (2 bytes)
                size_t dirCountOffset = bufferOffset;
                bufferOffset += 2; // dirCount (2 bytes)
                
                uint16_t dirsInThisMessage = 0;
                
                // Add paths to buffer until full or all paths processed
                while (pathIndex < paths.size() && bufferOffset < BUFFER_SIZE - 260) { // Leave 260 bytes margin for path
                    const String& path = paths[pathIndex];
                    size_t pathLen = path.length();
                    
                    if (pathLen > 255) pathLen = 255; // Limit path length
                    
                    // Check if path fits
                    if (bufferOffset + 1 + pathLen >= BUFFER_SIZE - 16) {
                        // Buffer full, send this message and continue with next
                        break;
                    }
                    
                    binaryBuffer[bufferOffset++] = (uint8_t)pathLen;
                    memcpy(binaryBuffer + bufferOffset, path.c_str(), pathLen);
                    bufferOffset += pathLen;
                    
                    dirsInThisMessage++;
                    dirsSent++;
                    pathIndex++;
                }
                
                // Check if more paths remaining
                hasMorePaths = (pathIndex < paths.size());
                
                // Update flags and counts
                binaryBuffer[flagsOffset] = hasMorePaths ? 0x01 : 0x00;
                
                // totalDirs: 0xFFFF if more coming, actual count if last message
                if (hasMorePaths) {
                    binaryBuffer[totalDirsOffset] = 0xFF;
                    binaryBuffer[totalDirsOffset + 1] = 0xFF;
                } else {
                    binaryBuffer[totalDirsOffset] = totalDirs & 0xFF;
                    binaryBuffer[totalDirsOffset + 1] = (totalDirs >> 8) & 0xFF;
                }
                
                // dirCount (little-endian)
                binaryBuffer[dirCountOffset] = dirsInThisMessage & 0xFF;
                binaryBuffer[dirCountOffset + 1] = (dirsInThisMessage >> 8) & 0xFF;
                
                // Send this message
                if (dirsInThisMessage > 0 || !hasMorePaths) {
                    clients.notifyAllBinary(NotificationType::FileSystem, binaryBuffer, bufferOffset);
                    ESP_LOGI("FileCommands", "Directory tree chunk: %d dirs (total sent: %d/%d)", 
                             dirsInThisMessage, dirsSent, totalDirs);
                    
                    // Small delay to allow mobile app to process
                    if (hasMorePaths) {
                        vTaskDelay(pdMS_TO_TICKS(100));
                    }
                }
            }
            
            ESP_LOGI("FileCommands", "Directory tree stream complete: %d directories sent", totalDirs);
            return true;
            
        } catch (...) {
            sendBinaryDirectoryTreeError(5); // error 5=unknown error
            return true;
        }
    }
    
    // Send binary error response for directory tree
    static void sendBinaryDirectoryTreeError(uint8_t errorCode) {
        static uint8_t errorBuffer[16];
        size_t offset = 0;
        
        errorBuffer[offset++] = MSG_DIRECTORY_TREE;
        errorBuffer[offset++] = 0; // pathType (unknown)
        errorBuffer[offset++] = 0x80 | (errorCode & 0x7F);  // Error flag + error code
        errorBuffer[offset++] = 0;  // totalDirs low = 0
        errorBuffer[offset++] = 0;  // totalDirs high = 0
        errorBuffer[offset++] = 0;  // dirCount low = 0
        errorBuffer[offset++] = 0;  // dirCount high = 0
        
        clients.notifyAllBinary(NotificationType::FileSystem, errorBuffer, offset);
    }
    
    // File upload with chunking
    // Note: Command 0x0D is no longer registered in CommandHandler
    // Actual processing happens in BleAdapter::handleUploadChunk
    // This method is kept for compatibility but should not be called
    static bool handleUploadFile(const uint8_t* data, size_t len) {
        // Command 0x0D is handled in BleAdapter::handleUploadChunk
        // This method should not be called
        return false;
    }
};
// Static buffers
JsonBuffer FileCommands::jsonBuffer;
PathBuffer FileCommands::pathBuffer;
LogBuffer FileCommands::logBuffer;

#endif // FileCommands_h
