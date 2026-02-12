#include "StringHelpers.h"

namespace helpers {
namespace string {

std::string toLowerCase(const std::string &str)
{
    std::string lowerStr = str;
    std::transform(lowerStr.begin(), lowerStr.end(), lowerStr.begin(), ::tolower);
    return lowerStr;
}

String toLowerCase(const String &str)
{
    String lowerStr = str;
    lowerStr.toLowerCase();
    return lowerStr;
}

std::string toStdString(const String &str)
{
    return std::string(str.c_str());
}

bool endsWith(const std::string& str, const std::string& suffix)
{
    if (suffix.size() > str.size()) return false;
    return std::equal(suffix.rbegin(), suffix.rend(), str.rbegin());
}

String toArduinoString(const std::string &str)
{
    return String(str.c_str());
}

std::string escapeJson(const std::string &input) {
    std::ostringstream escaped;
    for (size_t i = 0; i < input.length(); ++i) {
        unsigned char c = static_cast<unsigned char>(input[i]);
        switch (c) {
            case '"':  escaped << "\\\""; break;
            case '\\': escaped << "\\\\"; break;
            case '\b': escaped << "\\b"; break;
            case '\f': escaped << "\\f"; break;
            case '\n': escaped << "\\n"; break;
            case '\r': escaped << "\\r"; break;
            case '\t': escaped << "\\t"; break;
            default:
                if (c <= 0x1f) {
                    // Control characters
                    escaped << "\\u" << std::hex << std::setw(4) << std::setfill('0') << (int)c;
                } else if (c >= 0x80) {
                    // Non-ASCII characters - encode as UTF-8 sequence
                    if ((c & 0xE0) == 0xC0) {
                        // 2-byte UTF-8 sequence
                        if (i + 1 < input.length()) {
                            unsigned char c2 = static_cast<unsigned char>(input[i + 1]);
                            if ((c2 & 0xC0) == 0x80) {
                                uint32_t codepoint = ((c & 0x1F) << 6) | (c2 & 0x3F);
                                escaped << "\\u" << std::hex << std::setw(4) << std::setfill('0') << codepoint;
                                ++i; // Skip next byte
                                continue;
                            }
                        }
                    } else if ((c & 0xF0) == 0xE0) {
                        // 3-byte UTF-8 sequence
                        if (i + 2 < input.length()) {
                            unsigned char c2 = static_cast<unsigned char>(input[i + 1]);
                            unsigned char c3 = static_cast<unsigned char>(input[i + 2]);
                            if ((c2 & 0xC0) == 0x80 && (c3 & 0xC0) == 0x80) {
                                uint32_t codepoint = ((c & 0x0F) << 12) | ((c2 & 0x3F) << 6) | (c3 & 0x3F);
                                escaped << "\\u" << std::hex << std::setw(4) << std::setfill('0') << codepoint;
                                i += 2; // Skip next two bytes
                                continue;
                            }
                        }
                    }
                    // If we can't decode UTF-8 properly, just escape as raw byte
                    escaped << "\\u" << std::hex << std::setw(4) << std::setfill('0') << (int)c;
                } else {
                    // Regular ASCII characters
                    escaped << c;
                }
        }
    }
    return escaped.str();
}

String generateRandomString(int length)
{
    std::srand(static_cast<unsigned int>(std::time(nullptr)));

    const std::string characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    std::stringstream ss;
    for (int i = 0; i < length; ++i) {
        int randomIndex = std::rand() % characters.size();
        char randomChar = characters[randomIndex];
        ss << randomChar;
    }

    return String(ss.str().c_str());
}
}  // namespace string
}  // namespace helpers