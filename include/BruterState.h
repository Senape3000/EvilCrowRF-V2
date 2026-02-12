#ifndef BruterState_h
#define BruterState_h

#include <LittleFS.h>
#include <stdint.h>
#include "esp_log.h"

/**
 * Persistent bruter attack state for Pause/Resume functionality.
 *
 * When the user pauses an attack, we write the current progress to
 * /bruter_state.bin on LittleFS.  On resume the attack restarts from
 * (savedCode - RESUME_OVERLAP) so that a few codes are re-transmitted
 * and none are skipped.  Starting a *new* attack automatically deletes
 * any saved state.
 */

static const char* BRUTER_STATE_FILE = "/bruter_state.bin";
static const uint32_t BRUTER_STATE_MAGIC = 0x42523537; // "BR57"

// Overlap: re-transmit this many codes before the pause point
// to ensure nothing is skipped on resume.
static const uint32_t BRUTER_RESUME_OVERLAP = 5;

#pragma pack(push, 1)
struct BruterSavedState {
    uint32_t magic;              // Must be BRUTER_STATE_MAGIC
    uint8_t  menuId;             // Which attack (1-40)
    uint32_t currentCode;        // Last code transmitted before pause
    uint32_t totalCodes;         // Total keyspace
    uint16_t interFrameDelayMs;  // Delay setting at time of pause
    uint8_t  globalRepeats;      // Repetitions per code
    uint32_t timestamp;          // Device uptime (seconds) when paused
    uint8_t  attackType;         // 0=binary, 1=tristate, 2=debruijn
    uint8_t  reserved[3];        // Future use, zeroed
};
#pragma pack(pop)

/**
 * Helper class for reading/writing bruter state on LittleFS.
 */
class BruterStateManager {
public:
    /// Save the current attack state to flash.
    /// Returns true on success.
    static bool saveState(const BruterSavedState& state) {
        File f = LittleFS.open(BRUTER_STATE_FILE, FILE_WRITE);
        if (!f) {
            ESP_LOGE("BruterState", "Failed to open state file for writing");
            return false;
        }
        size_t written = f.write(reinterpret_cast<const uint8_t*>(&state), sizeof(state));
        f.close();
        if (written != sizeof(state)) {
            ESP_LOGE("BruterState", "Short write: %d/%d", (int)written, (int)sizeof(state));
            return false;
        }
        ESP_LOGI("BruterState", "State saved: menu=%d code=%lu/%lu",
                 state.menuId, (unsigned long)state.currentCode,
                 (unsigned long)state.totalCodes);
        return true;
    }

    /// Load a previously saved state.  Returns true if a valid state
    /// was found, and fills `out` with the data.
    static bool loadState(BruterSavedState& out) {
        if (!LittleFS.exists(BRUTER_STATE_FILE)) {
            return false;
        }
        File f = LittleFS.open(BRUTER_STATE_FILE, FILE_READ);
        if (!f) {
            ESP_LOGE("BruterState", "Failed to open state file for reading");
            return false;
        }
        size_t readBytes = f.read(reinterpret_cast<uint8_t*>(&out), sizeof(out));
        f.close();
        if (readBytes != sizeof(out) || out.magic != BRUTER_STATE_MAGIC) {
            ESP_LOGW("BruterState", "Invalid state file (read=%d, magic=0x%08X)",
                     (int)readBytes, out.magic);
            clearState();
            return false;
        }
        ESP_LOGI("BruterState", "State loaded: menu=%d code=%lu/%lu",
                 out.menuId, (unsigned long)out.currentCode,
                 (unsigned long)out.totalCodes);
        return true;
    }

    /// Delete the saved state (called on Stop or when a new attack starts).
    static void clearState() {
        if (LittleFS.exists(BRUTER_STATE_FILE)) {
            LittleFS.remove(BRUTER_STATE_FILE);
            ESP_LOGI("BruterState", "State file cleared");
        }
    }

    /// Check whether a resumable state exists.
    static bool hasState() {
        if (!LittleFS.exists(BRUTER_STATE_FILE)) return false;
        BruterSavedState tmp;
        return loadState(tmp);
    }

    /// Compute the resume start code (back up by RESUME_OVERLAP).
    static uint32_t getResumeStartCode(uint32_t savedCode) {
        if (savedCode <= BRUTER_RESUME_OVERLAP) return 0;
        return savedCode - BRUTER_RESUME_OVERLAP;
    }
};

#endif // BruterState_h
