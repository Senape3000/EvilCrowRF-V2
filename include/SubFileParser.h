#include <Arduino.h>
#include <FS.h>
#include <algorithm> // For std::find
#include <array> // For std::array
#include <string> // For std::string
#include <optional>
#include <vector>
#include "SubGhzProtocol.h"
#include "protocols/Princeton.h"
#include "PulsePayload.h"

const uint8_t subghz_device_cc1101_preset_ook_270khz_async_regs[] = {0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x30, 0x11,
                                                                     0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
                                                                     0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

const uint8_t subghz_device_cc1101_preset_ook_650khz_async_regs[] = {0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x30, 0x11,
                                                                     0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
                                                                     0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

const uint8_t subghz_device_cc1101_preset_2fsk_dev2_38khz_async_regs[] = {0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x10, 0x11,
                                                                          0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
                                                                          0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

const uint8_t subghz_device_cc1101_preset_2fsk_dev47_6khz_async_regs[] = {0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x10, 0x11,
                                                                          0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
                                                                          0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

const uint8_t subghz_device_cc1101_preset_msk_99_97kb_async_regs[] = {0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x70, 0x11,
                                                                      0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
                                                                      0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

const uint8_t subghz_device_cc1101_preset_gfsk_9_99kb_async_regs[] = {0x02, 0x0D, 0x03, 0x07, 0x08, 0x32, 0x0B, 0x06, 0x14, 0x00, 0x13, 0x00, 0x12, 0x10, 0x11,
                                                                      0x32, 0x10, 0x17, 0x18, 0x18, 0x19, 0x18, 0x1D, 0x91, 0x1C, 0x00, 0x1B, 0x07, 0x20, 0xFB,
                                                                      0x22, 0x11, 0x21, 0xB6, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

struct SubFileHeader
{
  String filetype;
  uint32_t version;
  uint32_t frequency;
};

struct SubFilePreset
{
  String preset;
  String customPresetModule;
  String customPresetData;
};

struct SubFileData
{
  String protocol;
  std::vector<int> rawData;
  uint32_t bitLength;
  String key;
  uint32_t te;
};

const std::array<std::string, 6> cc1101Presets = {
    "FuriHalSubGhzPresetOok270Async", 
    "FuriHalSubGhzPresetOok650Async", 
    "FuriHalSubGhzPreset2FSKDev238Async", 
    "FuriHalSubGhzPreset2FSKDev476Async",
    "FuriHalSubGhzPresetMSK99_97KbAsync",
    "FuriHalSubGhzPresetGFSK9_99KbAsync"
};

class SubFileParser
{
public:
  SubFileHeader header;
  SubFilePreset preset;
  SubFileData data;
  uint8_t moduleParams[128];

  SubFileParser(File file) : file(file)
  {
    clearMemory();
  }

  void displayInfo()
  {
    Serial.println("Filetype: " + header.filetype);
    Serial.println("Version: " + String(header.version));
    Serial.println("Frequency: " + String(header.frequency));
    Serial.println("Preset: " + preset.preset);
    if (!preset.customPresetModule.isEmpty()) {
      Serial.println("Custom Preset Module: " + preset.customPresetModule);
    }
    if (!preset.customPresetData.isEmpty()) {
      Serial.println("Custom Preset Data: " + preset.customPresetData);
    }
    Serial.println("Protocol: " + data.protocol);

    printModuleParams();
  }

  void clearMemory()
  {
    // Clear dynamically allocated memory
    data.rawData.clear();
    memset(moduleParams, 0, sizeof(moduleParams));
  }

  bool isModuleCc1101()
  {
    return (preset.preset == "FuriHalSubGhzPresetCustom" && preset.customPresetModule == "CC1101") || inCc1101Presets();
  }

  bool parseFile() {
    readFile();

    if (!file) {
        return false;
    }

    if (data.protocol.isEmpty()) {
      return false;
    }
    Serial.println(data.protocol.c_str());
    protocol.reset(SubGhzProtocol::create(data.protocol.c_str()));

    if (!protocol) {
      Serial.println("no protocol found");
      SubGhzProtocolRegistry::instance().printRegisteredProtocols();
      return false;
    }
    file.seek(0);
    bool result = protocol->parse(file);

    return result;
  }

  bool getPayload(PulsePayload &payload) const {
      if (!protocol) {
          return false;
      }
      const auto& pulseData = protocol->getPulseData();
      // Serial.println(protocol->serialize().c_str());
      payload = PulsePayload(pulseData, protocol->getRepeatCount());

      return true;
  }

private:
  File file;
  std::unique_ptr<SubGhzProtocol> protocol;

  void readFile()
  {
    if (!file) {
      return;
    }

    while (file.available()) {
      String line = file.readStringUntil('\n');
      if (line.endsWith("\r")) {
        line.remove(line.length() - 1);
      }
      parseLine(line);
    }

    handlePreset();
  }

  void parseLine(const String &line)
  {
    if (line.startsWith("Filetype:")) {
      header.filetype = parseValue(line);
    } else if (line.startsWith("Version:")) {
      header.version = parseValue(line).toInt();
    } else if (line.startsWith("Frequency:")) {
      header.frequency = parseValue(line).toInt();
    } else if (line.startsWith("Preset:")) {
      preset.preset = parseValue(line);
    } else if (line.startsWith("Custom_preset_module:")) {
      preset.customPresetModule = parseValue(line);
    } else if (line.startsWith("Custom_preset_data:")) {
      preset.customPresetData = parseValue(line);
    } else if (line.startsWith("Protocol:")) {
      data.protocol = parseValue(line);
    } else {
      return;
    }
  }

  String parseValue(const String &line)
  {
    int pos = line.indexOf(':');
    if (pos == -1) {
      return "";
    }
    String val = line.substring(pos + 1);
    val.trim();
    return val;
  }

  void handlePreset()
  {
    if (preset.preset == "FuriHalSubGhzPresetCustom") {
      parseCustomPresetData(preset.customPresetData);
    } else {
      const uint8_t *byteArray = getByteArrayForPreset(preset.preset);
      if (byteArray != nullptr) {
        for (int i = 0; i < 44; i++) {
          moduleParams[i] = byteArray[i];
        }
      }
    }
  }

  void parseRawDataLine(const String &rawValues)
  {
    int start = 0;
    while (start < rawValues.length()) {
      int spaceIndex = rawValues.indexOf(' ', start);
      if (spaceIndex == -1) {
        spaceIndex = rawValues.length();
      }

      String numberStr = rawValues.substring(start, spaceIndex);
      int value = numberStr.toInt();
      data.rawData.push_back(value);

      start = spaceIndex + 1;
    }
  }

  const uint8_t *getByteArrayForPreset(const String &preset)
  {
    if (preset == "FuriHalSubGhzPresetOok270Async") {
      return subghz_device_cc1101_preset_ook_270khz_async_regs;
    } else if (preset == "FuriHalSubGhzPresetOok650Async") {
      return subghz_device_cc1101_preset_ook_650khz_async_regs;
    } else if (preset == "FuriHalSubGhzPreset2FSKDev238Async") {
      return subghz_device_cc1101_preset_2fsk_dev2_38khz_async_regs;
    } else if (preset == "FuriHalSubGhzPreset2FSKDev476Async") {
      return subghz_device_cc1101_preset_2fsk_dev47_6khz_async_regs;
    } else if (preset == "FuriHalSubGhzPresetMSK99_97KbAsync") {
      return subghz_device_cc1101_preset_msk_99_97kb_async_regs;
    } else if (preset == "FuriHalSubGhzPresetGFSK9_99KbAsync") {
      return subghz_device_cc1101_preset_gfsk_9_99kb_async_regs;
    }

    return nullptr;
  }

  bool inCc1101Presets()
  {
    return std::find(cc1101Presets.begin(), cc1101Presets.end(), preset.preset.c_str()) != cc1101Presets.end();
  }

  void parseCustomPresetData(const String &customData)
  {
    int length = countBytes(customData);

    int startIndex = 0;
    int endIndex = customData.indexOf(' ', startIndex);
    int index = 0;

    while (endIndex > 0) {
      String byteStr = customData.substring(startIndex, endIndex);
      moduleParams[index++] = strtol(byteStr.c_str(), NULL, 16);
      startIndex = endIndex + 1;
      endIndex = customData.indexOf(' ', startIndex);
    }

    // Get the last byte
    String byteStr = customData.substring(startIndex);
    moduleParams[index++] = strtol(byteStr.c_str(), NULL, 16);
  }

  int countBytes(const String &data)
  {
    int count = 0;
    int startIndex = 0;
    int endIndex = data.indexOf(' ', startIndex);

    while (endIndex > 0) {
      count++;
      startIndex = endIndex + 1;
      endIndex = data.indexOf(' ', startIndex);
    }

    // Count the last byte
    count++;
    return count;
  }

  void printModuleParams()
  {
    size_t size = sizeof(moduleParams);
    Serial.println("Module Params:");
    for (size_t i = 0; i < size; ++i) {
      if (i % 16 == 0) {  // Print 16 bytes per line
        Serial.println();
      }
      if (moduleParams[i] < 0x10) {
        Serial.print("0");  // Add leading zero for single digit hex values
      }
      Serial.print(moduleParams[i], HEX);
      Serial.print(" ");
    }
    Serial.println();
  }
};