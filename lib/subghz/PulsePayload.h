#ifndef PULSE_PAYLOAD_H
#define PULSE_PAYLOAD_H

#include <vector>
#include <utility>
#include <cstdint>
#include <Arduino.h>

class PulsePayload {
public:
    PulsePayload() : repeatCount(0), currentIndex(0), currentRepeat(0) {}
    PulsePayload(const std::vector<std::pair<uint32_t, bool>>& pulses, uint32_t repeatCount)
        : pulses(pulses), repeatCount(repeatCount), currentIndex(0), currentRepeat(0) {}

    bool next(uint32_t& duration, bool& pinState) {
        if (currentRepeat >= repeatCount || pulses.empty()) {
            return false;
        }

        duration = pulses[currentIndex].first;
        pinState = pulses[currentIndex].second;

        currentIndex++;
        if (currentIndex >= pulses.size()) {
            currentIndex = 0;
            currentRepeat++;
            taskYIELD();
            if (currentRepeat >= repeatCount) {
                return false;
            }
        }

        return true;
    }

private:
    std::vector<std::pair<uint32_t, bool>> pulses;
    uint32_t repeatCount;
    size_t currentIndex;
    uint32_t currentRepeat;
};


#endif // PULSE_PAYLOAD_H
