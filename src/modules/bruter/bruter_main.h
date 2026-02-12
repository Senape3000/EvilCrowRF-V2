#pragma once

#include <Arduino.h>
#include <String>
#include "config.h"

// Forward declarations for protocols
namespace bruter {
    class c_rf_protocol;
}

class BruterModule {
public:
    bool setupCC1101();
    bool attackBinary(bruter::c_rf_protocol* proto, const char* name, int positions, float mhz);
    bool attackTristate(bruter::c_rf_protocol* proto, const char* name, int positions, float mhz);

    /// De Bruijn attack — transmits B(2,n) sequence through the given protocol.
    /// Only for binary protocols with n <= DEBRUIJN_MAX_BITS (16).
    /// Uses heap for sequence generation, frees it before returning.
    bool attackDeBruijn(bruter::c_rf_protocol* proto, const char* name,
                        int bits, float mhz, int repeats = 3);

    /// Dispatch to the correct menuN() by number (1-40).
    void executeMenu(uint8_t menuChoice);

    /// Start an attack asynchronously on a dedicated FreeRTOS task.
    /// Returns true if the task was created, false if one is already running.
    bool startAttackAsync(uint8_t menuChoice);

    /// Start attack from a previously saved state (resume).
    /// The attack restarts from (savedCode - overlap) to avoid skipping.
    bool resumeAttackAsync();

    void menu1();
    void menu2();
    void menu3();
    void menu4();
    void menu5();
    void menu6();
    void menu7();
    void menu8();
    void menu9();
    void menu10();
    void menu11();
    void menu12();
    void menu13();
    // New protocols (14-33)
    void menu14();  // CLEMSA
    void menu15();  // GATETX
    void menu16();  // PHOX
    void menu17();  // PHOENIX_V2
    void menu18();  // PRASTEL
    void menu19();  // DOITRAND
    void menu20();  // DOOYA 24b
    void menu21();  // NERO
    void menu22();  // MAGELLEN
    void menu23();  // FIREFLY 300MHz
    void menu24();  // LINEAR_MEGACODE 318MHz
    void menu25();  // HORMANN 868MHz
    void menu26();  // MARANTEC 868MHz
    void menu27();  // BERNER 868MHz
    void menu28();  // INTERTECHNO_V3 32b
    void menu29();  // EV1527 24b full
    void menu30();  // STARLINE
    void menu31();  // TEDSEN
    void menu32();  // AIRFORCE
    void menu33();  // UNILARM 433.42MHz
    void menu_elka();  // ELKA (extra slot)
    // De Bruijn attack menus (35-40)
    void menuDeBruijnGeneric433();  // Generic OOK 12b @ 433.92
    void menuDeBruijnGeneric315();  // Generic OOK 12b @ 315.00
    void menuDeBruijnHoltek();      // Holtek exact timing @ 433.92
    void menuDeBruijnLinear();      // Linear exact timing @ 300.00
    void menuDeBruijnEV1527();      // EV1527 exact timing @ 433.92
    void menuDeBruijnUniversal();   // Universal sweep (multi-freq/timing)
    void menuDeBruijnCustom();         // Custom De Bruijn with BLE-provided params

    /// Set custom De Bruijn parameters before launching menu 0xFD.
    /// Called by BruterCommands when receiving [0xFD][bits][teLo][teHi][ratio][freq:4LE].
    void setCustomDeBruijnParams(uint8_t bits, uint16_t te, uint8_t ratio, float freqMhz);

    /// Cancel the running attack (sets flag, task checks it periodically).
    void cancelAttack();

    /// Pause the running attack — sets cancel flag AND saves state to LittleFS.
    void pauseAttack();

    bool isAttackRunning() const;

    /// Task handle for the async attack task (nullptr when idle).
    static TaskHandle_t attackTaskHandle;

    /// Set inter-frame delay in ms (configurable from app)
    void setInterFrameDelay(uint16_t delayMs) { interFrameDelayMs = delayMs; }
    uint16_t getInterFrameDelay() const { return interFrameDelayMs; }

    /// Set global repeats per code (configurable via BLE sub-command 0xFC)
    void setGlobalRepeats(uint8_t reps) { globalRepeats = reps; }
    uint8_t getGlobalRepeats() const { return globalRepeats; }

    /// Get current attack menu ID (0 = idle)
    uint8_t getCurrentMenuId() const { return currentMenuId; }

    /// Whether the last stop was a pause (state saved)
    bool wasPaused() const { return pauseRequested; }

    /// Check if a resumable state exists on LittleFS and notify via BLE.
    void checkAndNotifySavedState();

private:
    int globalRepeats = BRUTER_DEFAULT_REPETITIONS;
    float current_mhz = 0.0f;
    unsigned long lastInteraction = 0;
    volatile bool attackRunning = false;
    volatile bool pauseRequested = false;   // True when pausing (vs stopping)
    uint32_t lastCodesSent = 0;             // Track codes sent for completion message
    uint32_t resumeFromCode = 0;            // Non-zero when resuming from saved state
    uint32_t pauseTotalCodes = 0;           // Total keyspace (for pause state save)
    uint16_t interFrameDelayMs = BRUTER_INTER_FRAME_GAP_MS;
    uint8_t currentMenuId = 0;
    uint8_t currentAttackType = 0;          // 0=binary, 1=tristate, 2=debruijn

    // Custom De Bruijn parameters (set via BLE 0xFD before task launch)
    uint8_t  customDbBits = 12;
    uint16_t customDbTe = 300;
    uint8_t  customDbRatio = 3;
    float    customDbFreq = 433.92f;

    const int RF_CS = BRUTER_RF_CS;
    const int RF_GDO0 = BRUTER_RF_GDO0;
    const int RF_TX = BRUTER_RF_TX;
    const int RF_SCK = BRUTER_RF_SCK;
    const int RF_MISO = BRUTER_RF_MISO;
    const int RF_MOSI = BRUTER_RF_MOSI;

    void setFrequencyCorrected(float mhz);
    void sendPulse(int duration);

    /// FreeRTOS task entry point for async attacks.
    static void attackTaskFunc(void* param);
};

// Global functions for integration with main firmware
bool bruter_init();
void bruter_handleCommand(const String& command);

// Get bruter module instance
BruterModule& getBruterModule();