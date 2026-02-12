#ifndef FLIPPER_SUB_FILE_H
#define FLIPPER_SUB_FILE_H

#include <Arduino.h>
#include <SD.h>
#include <sstream>
#include <map>
#include <vector>

class FlipperSubFile {
public:
    static void generateRaw(
        File& file,
        const std::string& presetName,
        const std::vector<byte>& customPresetData,
        std::stringstream& samples,
        float frequency
    );
    
    static void generateRaw(
        File& file,
        const std::string& presetName,
        const std::vector<byte>& customPresetData,
        const std::vector<unsigned long>& samples,
        float frequency
    );

private:
    static const std::map<std::string, std::string> presetMapping;

    static void writeHeader(File& file, float frequency);
    static void writePresetInfo(File& file, const std::string& presetName, const std::vector<byte>& customPresetData);
    static void writeRawProtocolData(File& file, std::stringstream& samples);
    static void writeRawProtocolData(File& file, const std::vector<unsigned long>& samples);
    static std::string getPresetName(const std::string& preset);
};

#endif // FLIPPER_SUB_FILE_H