#ifndef STRING_HELPERS_H
#define STRING_HELPERS_H

#include <string>
#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <ctime>
#include <sstream>
#include <iomanip>
#include <Arduino.h>

namespace helpers {
namespace string {

    String toLowerCase(const String &str);
    std::string toLowerCase(const std::string &str);
    std::string toStdString(const String &str);
    bool endsWith(const std::string& str, const std::string& suffix);
    String toArduinoString(const std::string &str);
    String generateRandomString(int length);
    std::string escapeJson(const std::string &input);
}
}

#endif // STRING_HELPERS_H