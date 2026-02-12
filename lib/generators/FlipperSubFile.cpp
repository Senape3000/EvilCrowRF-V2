#include "FlipperSubFile.h"

const std::map<std::string, std::string> FlipperSubFile::presetMapping = {
    {"Ook270", "FuriHalSubGhzPresetOok270Async"},
    {"Ook650", "FuriHalSubGhzPresetOok650Async"},
    {"2FSKDev238", "FuriHalSubGhzPreset2FSKDev238Async"},
    {"2FSKDev476", "FuriHalSubGhzPreset2FSKDev476Async"},
    {"Custom", "FuriHalSubGhzPresetCustom"}
};

void FlipperSubFile::generateRaw(
    File& file,
    const std::string& presetName,
    const std::vector<byte>& customPresetData,
    std::stringstream& samples,
    float frequency
) {
    // Write the header, preset info, and protocol data
    writeHeader(file, frequency);
    writePresetInfo(file, presetName, customPresetData);
    writeRawProtocolData(file, samples);
}

void FlipperSubFile::generateRaw(
    File& file,
    const std::string& presetName,
    const std::vector<byte>& customPresetData,
    const std::vector<unsigned long>& samples,
    float frequency
) {
    // Write the header, preset info, and protocol data
    writeHeader(file, frequency);
    writePresetInfo(file, presetName, customPresetData);
    writeRawProtocolData(file, samples);
}

void FlipperSubFile::writeHeader(File& file, float frequency) {
    file.println("Filetype: Flipper SubGhz RAW File");
    file.println("Version: 1");
    file.print("Frequency: ");
    file.print(frequency * 1e6, 0);
    file.println();
}

void FlipperSubFile::writePresetInfo(File& file, const std::string& presetName, const std::vector<byte>& customPresetData) {
    file.print("Preset: ");
    file.println(getPresetName(presetName).c_str());

    if (presetName == "Custom") {
        file.println("Custom_preset_module: CC1101");
        file.print("Custom_preset_data: ");
        for (size_t i = 0; i < customPresetData.size(); ++i) {
            char hexStr[3];
            sprintf(hexStr, "%02X", customPresetData[i]);
            file.print(hexStr);
            if (i < customPresetData.size() - 1) {
                file.print(" ");
            }
        }
        file.println();
    }
}

void FlipperSubFile::writeRawProtocolData(File& file, std::stringstream& samples) {
    // Try to get string content, but if it fails due to memory, we'll use fallback
    std::string streamContent;
    try {
        streamContent = samples.str();
    } catch (const std::bad_alloc& e) {
        ESP_LOGW("FlipperSubFile", "Not enough memory to copy stringstream (bad_alloc), using direct write");
        // Fallback: write directly from stream in small chunks
        file.println("Protocol: RAW");
        file.print("RAW_Data: ");
        
        samples.clear();
        samples.seekg(0, std::ios::beg);
        
        char buffer[256];
        int wordCount = 0;
        int lineBreakCount = 0;
        
        while (samples.read(buffer, sizeof(buffer) - 1) || samples.gcount() > 0) {
            size_t bytesRead = samples.gcount();
            buffer[bytesRead] = '\0';
            
            file.print(buffer);
            wordCount += bytesRead;
            
            // Add line breaks every ~4000 chars
            if (wordCount > 4000 * (lineBreakCount + 1)) {
                file.println();
                file.print("RAW_Data: ");
                lineBreakCount++;
            }
            
            if (ESP.getFreeHeap() < 5000) {
                ESP_LOGW("FlipperSubFile", "Low heap, stopping");
                break;
            }
        }
        
        file.println();
        ESP_LOGI("FlipperSubFile", "Wrote data directly from stream");
        return;
    } catch (...) {
        ESP_LOGE("FlipperSubFile", "Unknown exception getting stream content");
        file.println();
        return;
    }
    
    // Original implementation for small streams
    size_t streamSize = streamContent.size();
    ESP_LOGI("FlipperSubFile", "writeRawProtocolData: stream size=%zu chars", streamSize);
    
    if (streamSize == 0) {
        ESP_LOGW("FlipperSubFile", "Stream is EMPTY!");
        file.println();
        return;
    }
    
    file.println("Protocol: RAW");
    file.print("RAW_Data: ");
    
    // Write in small chunks
    const size_t chunkSize = 256;
    size_t written = 0;
    int lineBreakCount = 0;
    
    for (size_t i = 0; i < streamSize; i += chunkSize) {
        size_t remaining = streamSize - i;
        size_t writeSize = (remaining > chunkSize) ? chunkSize : remaining;
        
        // Write chunk directly
        file.write((const uint8_t*)streamContent.c_str() + i, writeSize);
        written += writeSize;
        
        // Line breaks
        if (written > 4000 * (lineBreakCount + 1)) {
            file.println();
            file.print("RAW_Data: ");
            lineBreakCount++;
        }
        
        if (ESP.getFreeHeap() < 5000) {
            ESP_LOGW("FlipperSubFile", "Low heap, stopping at %zu chars", written);
            break;
        }
    }
    
    file.println();
    ESP_LOGI("FlipperSubFile", "Wrote %zu chars to file", written);
}

void FlipperSubFile::writeRawProtocolData(File& file, const std::vector<unsigned long>& samples) {
    file.println("Protocol: RAW");
    file.print("RAW_Data: ");
    
    if (samples.empty()) {
        ESP_LOGW("FlipperSubFile", "Samples vector is EMPTY!");
        file.println();
        return;
    }
    
    ESP_LOGI("FlipperSubFile", "Writing %zu samples directly to file", samples.size());
    
    int wordCount = 0;
    int lineBreakCount = 0;
    char buffer[32]; // Buffer for number formatting
    
    try {
        for (size_t i = 0; i < samples.size(); i++) {
            // Format: positive numbers with space, negative with " -"
            if (i > 0) {
                if (i % 2 == 1) {
                    file.print(" -");
                } else {
                    file.print(" ");
                }
            }
            
            // Write number directly
            int len = sprintf(buffer, "%lu", samples[i]);
            file.write((const uint8_t*)buffer, len);
            wordCount++;
            
            // Line breaks every 512 numbers
            if (wordCount > 0 && wordCount % 512 == 0) {
                file.println();
                file.print("RAW_Data: ");
                lineBreakCount++;
            }
            
            // Check heap periodically
            if (wordCount % 256 == 0 && ESP.getFreeHeap() < 5000) {
                ESP_LOGW("FlipperSubFile", "Low heap, stopping at sample %zu", i);
                break;
            }
        }
    } catch (const std::exception& e) {
        ESP_LOGE("FlipperSubFile", "Exception during write: %s", e.what());
    } catch (...) {
        ESP_LOGE("FlipperSubFile", "Unknown exception during write");
    }
    
    file.println();
    ESP_LOGI("FlipperSubFile", "Wrote %d samples to file", wordCount);
}

std::string FlipperSubFile::getPresetName(const std::string& preset) {
    auto it = presetMapping.find(preset);
    if (it != presetMapping.end()) {
        return it->second;
    } else {
        return "FuriHalSubGhzPresetCustom";
    }
}