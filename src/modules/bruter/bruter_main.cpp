#include "bruter_main.h"
#include "../../include/config.h"
#include "../../lib/CC1101_RadioLib/CC1101_Radio.h"
#include "../../src/modules/CC1101_driver/CC1101_Module.h"
#include "../../src/core/device_controls/DeviceControls.h"
#include "../../src/core/ble/ClientsManager.h"
#include "../../include/BinaryMessages.h"
#include "../../include/BruterState.h"
#include <SPI.h>

// Include protocol headers
#include "protocols/protocol.h"
#include "protocols/Came.h"
#include "protocols/Princeton.h"
#include "protocols/NiceFlo.h"
#include "protocols/Chamberlain.h"
#include "protocols/Linear.h"
#include "protocols/Holtek.h"
#include "protocols/LiftMaster.h"
#include "protocols/Ansonic.h"
#include "protocols/EV1527.h"
#include "protocols/Honeywell.h"
#include "protocols/FAAC.h"
#include "protocols/BFT.h"
#include "protocols/SMC5326.h"
// New protocols (14-33)
#include "protocols/Clemsa.h"
#include "protocols/GateTX.h"
#include "protocols/Phox.h"
#include "protocols/PhoenixV2.h"
#include "protocols/Prastel.h"
#include "protocols/Doitrand.h"
#include "protocols/Dooya.h"
#include "protocols/Nero.h"
#include "protocols/Magellen.h"
#include "protocols/Firefly.h"
#include "protocols/LinearMegaCode.h"
#include "protocols/Hormann.h"
#include "protocols/Marantec.h"
#include "protocols/Berner.h"
#include "protocols/IntertechnoV3.h"
#include "protocols/StarLine.h"
#include "protocols/Tedsen.h"
#include "protocols/Airforce.h"
#include "protocols/Unilarm.h"
#include "protocols/ELKA.h"
#include "protocols/DynamicProtocol.h"
#include "debruijn.h"

// Global instance
static BruterModule bruterModule;

// Volatile cancel flag — can be set from another task/ISR to stop a running attack
volatile bool bruterCancelFlag = false;

// Static task resources for async attack execution (BSS, no heap usage)
static constexpr size_t BRUTER_TASK_STACK_WORDS = 4096; // 4096 * 4 = 16384 bytes
static StackType_t  bruterTaskStack[BRUTER_TASK_STACK_WORDS];
static StaticTask_t bruterTaskTCB;
TaskHandle_t BruterModule::attackTaskHandle = nullptr;

BruterModule& getBruterModule() {
    return bruterModule;
}

bool bruter_init() {
    return bruterModule.setupCC1101();
}

void bruter_handleCommand(const String& command) {
    if (command == "BRUTER") {
        // Placeholder for interactive menu output
    }
}

void BruterModule::updatePinsForModule() {
    if (selectedModule == MODULE_1) {
        RF_CS   = CC1101_SS0;
        RF_GDO0 = MOD0_GDO0;
        RF_TX   = MOD0_GDO0;
    } else {
        RF_CS   = CC1101_SS1;
        RF_GDO0 = MOD1_GDO0;
        RF_TX   = MOD1_GDO0;
    }
}

void BruterModule::setModule(uint8_t mod) {
    if (mod > MODULE_2) mod = MODULE_2;
    selectedModule = mod;
    updatePinsForModule();
    ESP_LOGI("Bruter", "Module set to %d (CS=%d, TX=%d)", selectedModule, RF_CS, RF_TX);
}

bool BruterModule::setupCC1101() {
    // Acquire shared SPI semaphore — the bruter shares the HSPI bus
    // and the global currentModule variable with CC1101Worker.
    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    xSemaphoreTake(spiMutex, portMAX_DELAY);

    // Ensure pin assignments match the selected module
    updatePinsForModule();
    int gdo2Pin = (selectedModule == MODULE_1) ? MOD0_GDO2 : MOD1_GDO2;

    cc1101.addSpiPin(RF_SCK, RF_MISO, RF_MOSI, RF_CS, selectedModule);
    // Use addGDO() (not addGDO0!) to preserve gdo_set[]=2.
    // addGDO0() sets gdo_set to 1 which causes setModul() to configure
    // GDO0 as INPUT, breaking transmission for all other module users
    // (CC1101Worker jammer, transmitter, etc.).
    cc1101.addGDO(RF_GDO0, gdo2Pin, selectedModule);
    cc1101.setModul(selectedModule);
    if (!cc1101.getCC1101()) {
        xSemaphoreGive(spiMutex);
        return false;
    }
    cc1101.Init();
    cc1101.setPktFormat(3);
    cc1101.setModulation(2);
    cc1101.setPA(10);
    cc1101.SetTx();
    pinMode(RF_TX, OUTPUT);

    // Reset cached frequency so the first setFrequencyCorrected() call
    // actually writes the FREQ registers and re-triggers PLL calibration
    current_mhz = 0.0f;

    xSemaphoreGive(spiMutex);
    return true;
}

void BruterModule::setFrequencyCorrected(float target_mhz) {
    float corrected_mhz = target_mhz - BRUTER_CC1101_FREQ_OFFSET;
    if (corrected_mhz == current_mhz) {
        return;
    }
    // Acquire shared SPI semaphore — setMHZ() writes to the CC1101 over SPI
    SemaphoreHandle_t spiMutex = ModuleCc1101::getSpiSemaphore();
    xSemaphoreTake(spiMutex, portMAX_DELAY);
    cc1101.setModul(selectedModule);  // Ensure currentModule targets the selected module
    // CC1101 datasheet: FREQ registers should be written in IDLE state.
    // Auto-calibration (MCSM0=0x18) only occurs on IDLE→TX/RX transitions.
    // Without going IDLE first, the PLL won't lock to the new frequency.
    cc1101.setSidle();
    cc1101.setMHZ(corrected_mhz);    // Writes FREQ regs + calls Calibrate()
    cc1101.SetTx();                   // IDLE→TX triggers auto-calibration + PLL lock
    delay(1);                         // Allow PLL to settle
    xSemaphoreGive(spiMutex);
    current_mhz = corrected_mhz;
}

void BruterModule::sendPulse(int duration) {
    if (duration == 0) {
        return;
    }
    digitalWrite(RF_TX, (duration > 0) ? HIGH : LOW);
    delayMicroseconds(abs(duration));
}

// -----------------------------------------------------------------
// Async task support
// -----------------------------------------------------------------

void BruterModule::attackTaskFunc(void* param) {
    uint8_t choice = (uint8_t)(uintptr_t)param;
    ESP_LOGI("Bruter", "Async attack task started: menu %d (stack=%d bytes)",
             choice, BRUTER_TASK_STACK_WORDS * sizeof(StackType_t));

    BruterModule& bruter = getBruterModule();
    bruter.currentMenuId = choice;
    bruter.pauseRequested = false;

    // Clear any old saved state when starting a NEW attack (not a resume).
    // Resume sets resumeFromCode > 0 before task creation.
    if (bruter.resumeFromCode == 0) {
        BruterStateManager::clearState();
    }

    // *** CRITICAL: Re-initialize CC1101 for TX before EVERY attack ***
    // Between boot and attack start, other modules (CC1101Worker detect/record/jam)
    // may have reconfigured the CC1101 into RX or IDLE mode.
    // setupCC1101() restores: PKT_FORMAT=3 (async serial), ASK/OOK modulation,
    // PA power, SetTx() strobe, and pinMode(GDO0, OUTPUT).
    if (!bruter.setupCC1101()) {
        ESP_LOGE("Bruter", "Failed to re-initialize CC1101 for TX — aborting attack");
        bruter.currentMenuId = 0;
        bruter.attackRunning = false;
        attackTaskHandle = nullptr;
        vTaskDelete(NULL);
        return;  // Never reached, but makes intent clear
    }

    bruter.executeMenu(choice);

    // After the attack loop finishes, check whether it was paused
    if (bruter.pauseRequested && bruter.lastCodesSent > 0) {
        // Save state to LittleFS
        extern uint32_t deviceTime;
        BruterSavedState state = {};
        state.magic            = BRUTER_STATE_MAGIC;
        state.menuId           = choice;
        state.currentCode      = bruter.lastCodesSent;
        state.totalCodes       = 0; // Will be filled by attack function
        state.interFrameDelayMs = bruter.interFrameDelayMs;
        state.globalRepeats    = bruter.globalRepeats;
        state.timestamp        = deviceTime;
        state.attackType       = bruter.currentAttackType;

        // totalCodes was stored in lastCodesSent context — read from progress
        // We stored it in a separate variable
        state.totalCodes = bruter.pauseTotalCodes;

        BruterStateManager::saveState(state);

        // Notify app that the attack was paused
        BinaryBruterPaused pauseMsg = {};
        pauseMsg.menuId      = choice;
        pauseMsg.currentCode = state.currentCode;
        pauseMsg.totalCodes  = state.totalCodes;
        pauseMsg.percentage  = (state.totalCodes > 0)
            ? (uint8_t)((uint64_t)state.currentCode * 100 / state.totalCodes) : 0;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::BruterComplete,
            reinterpret_cast<const uint8_t*>(&pauseMsg),
            sizeof(BinaryBruterPaused));
        ESP_LOGI("Bruter", "Attack paused: menu %d at code %lu/%lu",
                 choice, (unsigned long)state.currentCode, (unsigned long)state.totalCodes);
    } else {
        // Normal completion or cancel — send completion signal
        BinaryBruterComplete completeMsg;
        completeMsg.menuId = choice;
        completeMsg.status = bruterCancelFlag ? 1 : 0; // 0=completed, 1=cancelled
        completeMsg.reserved = 0;
        completeMsg.totalSent = bruter.lastCodesSent;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::BruterComplete,
            reinterpret_cast<const uint8_t*>(&completeMsg),
            sizeof(BinaryBruterComplete));
        ESP_LOGI("Bruter", "Completion signal sent: menu %d, status=%d", choice, completeMsg.status);

        // Clear saved state on stop/complete (not pause)
        if (!bruter.pauseRequested) {
            BruterStateManager::clearState();
        }
    }

    UBaseType_t hwm = uxTaskGetStackHighWaterMark(NULL);
    ESP_LOGI("Bruter", "Attack finished: menu %d, stack HWM=%lu bytes free",
             choice, (unsigned long)(hwm * sizeof(StackType_t)));

    bruter.currentMenuId = 0;
    bruter.resumeFromCode = 0;
    bruter.pauseRequested = false;
    attackTaskHandle = nullptr;
    vTaskDelete(NULL);
}

bool BruterModule::startAttackAsync(uint8_t menuChoice) {
    if (attackTaskHandle != nullptr || attackRunning) {
        ESP_LOGW("Bruter", "Cannot start menu %d — attack already running", menuChoice);
        return false;
    }
    resumeFromCode = 0; // Fresh attack
    // Use static allocation, pinned to Core 1 (app core, RF time-sensitive)
    attackTaskHandle = xTaskCreateStatic(
        attackTaskFunc,
        "bruter_atk",
        BRUTER_TASK_STACK_WORDS,
        (void*)(uintptr_t)menuChoice,
        2,  // Priority 2 (above normal, below CC1101Worker at 5)
        bruterTaskStack,
        &bruterTaskTCB
    );
    return (attackTaskHandle != nullptr);
}

bool BruterModule::resumeAttackAsync() {
    if (attackTaskHandle != nullptr || attackRunning) {
        ESP_LOGW("Bruter", "Cannot resume — attack already running");
        return false;
    }
    BruterSavedState saved;
    if (!BruterStateManager::loadState(saved)) {
        ESP_LOGW("Bruter", "No saved state to resume from");
        return false;
    }
    // Restore settings from saved state
    interFrameDelayMs = saved.interFrameDelayMs;
    globalRepeats = saved.globalRepeats;
    currentAttackType = saved.attackType;
    resumeFromCode = BruterStateManager::getResumeStartCode(saved.currentCode);
    pauseTotalCodes = saved.totalCodes;

    ESP_LOGI("Bruter", "Resuming menu %d from code %lu (overlap from %lu)",
             saved.menuId, (unsigned long)saved.currentCode,
             (unsigned long)resumeFromCode);

    // Send resumed notification
    BinaryBruterResumed resumeMsg = {};
    resumeMsg.menuId     = saved.menuId;
    resumeMsg.resumeCode = resumeFromCode;
    resumeMsg.totalCodes = saved.totalCodes;
    ClientsManager::getInstance().notifyAllBinary(
        NotificationType::BruterComplete,
        reinterpret_cast<const uint8_t*>(&resumeMsg),
        sizeof(BinaryBruterResumed));

    // Launch the task with the saved menu choice
    attackTaskHandle = xTaskCreateStatic(
        attackTaskFunc,
        "bruter_atk",
        BRUTER_TASK_STACK_WORDS,
        (void*)(uintptr_t)saved.menuId,
        2,
        bruterTaskStack,
        &bruterTaskTCB
    );
    return (attackTaskHandle != nullptr);
}

void BruterModule::pauseAttack() {
    pauseRequested = true;
    bruterCancelFlag = true; // Stop the loop
    ESP_LOGI("Bruter", "Pause requested — state will be saved");
}

void BruterModule::checkAndNotifySavedState() {
    BruterSavedState saved;
    if (BruterStateManager::loadState(saved)) {
        BinaryBruterStateAvail msg = {};
        msg.menuId      = saved.menuId;
        msg.currentCode = saved.currentCode;
        msg.totalCodes  = saved.totalCodes;
        msg.percentage  = (saved.totalCodes > 0)
            ? (uint8_t)((uint64_t)saved.currentCode * 100 / saved.totalCodes) : 0;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::BruterComplete,
            reinterpret_cast<const uint8_t*>(&msg),
            sizeof(BinaryBruterStateAvail));
        ESP_LOGI("Bruter", "Notified app of saved state: menu=%d code=%lu/%lu",
                 saved.menuId, (unsigned long)saved.currentCode,
                 (unsigned long)saved.totalCodes);
    }
}

void BruterModule::executeMenu(uint8_t menuChoice) {
    switch (menuChoice) {
        case 1:  menu1();  break;
        case 2:  menu2();  break;
        case 3:  menu3();  break;
        case 4:  menu4();  break;
        case 5:  menu5();  break;
        case 6:  menu6();  break;
        case 7:  menu7();  break;
        case 8:  menu8();  break;
        case 9:  menu9();  break;
        case 10: menu10(); break;
        case 11: menu11(); break;
        case 12: menu12(); break;
        case 13: menu13(); break;
        case 14: menu14(); break;
        case 15: menu15(); break;
        case 16: menu16(); break;
        case 17: menu17(); break;
        case 18: menu18(); break;
        case 19: menu19(); break;
        case 20: menu20(); break;
        case 21: menu21(); break;
        case 22: menu22(); break;
        case 23: menu23(); break;
        case 24: menu24(); break;
        case 25: menu25(); break;
        case 26: menu26(); break;
        case 27: menu27(); break;
        case 28: menu28(); break;
        case 29: menu29(); break;
        case 30: menu30(); break;
        case 31: menu31(); break;
        case 32: menu32(); break;
        case 33: menu33(); break;
        case 34: menu_elka(); break;  // ELKA (exposed)
        // De Bruijn attack menus
        case 35: menuDeBruijnGeneric433(); break;
        case 36: menuDeBruijnGeneric315(); break;
        case 37: menuDeBruijnHoltek(); break;
        case 38: menuDeBruijnLinear(); break;
        case 39: menuDeBruijnEV1527(); break;
        case 40: menuDeBruijnUniversal(); break;
        case 0xFD: menuDeBruijnCustom(); break; // Custom params via BLE
        default:
            ESP_LOGW("Bruter", "Unknown menu choice: %d", menuChoice);
            break;
    }
}

bool BruterModule::attackBinary(bruter::c_rf_protocol* proto, const char* name, int bits, float mhz) {
    bruterCancelFlag = false;
    attackRunning = true;
    lastCodesSent = 0;
    currentAttackType = 0; // binary
    setFrequencyCorrected(mhz);
    // Use 64-bit to avoid UB when bits==32 (1UL << 32 is undefined on 32-bit platforms)
    // For bits==32 the full keyspace is 2^32 = 4,294,967,296 which does not fit
    // a uint32_t, but the loop variable wraps safely with the overflow guard below.
    uint32_t total = (bits >= 32) ? 0xFFFFFFFFU : (1UL << bits);
    bool is32bit = (bits >= 32); // need special loop termination
    pauseTotalCodes = total;

    // Support resume: start from saved position instead of 0
    uint32_t startCode = resumeFromCode;
    if (startCode >= total) startCode = 0;

    unsigned long startTime = millis();

    ESP_LOGI("Bruter", "Starting binary attack: %s, bits=%d, freq=%.2f, total=%lu, start=%lu, delay=%dms",
             name, bits, mhz, total, (unsigned long)startCode, interFrameDelayMs);

    // Send initial progress
    {
        BinaryBruterProgress progress;
        progress.currentCode = startCode;
        progress.totalCodes = total;
        progress.menuId = currentMenuId;
        progress.percentage = (total > 0) ? (uint8_t)((uint64_t)startCode * 100 / total) : 0;
        progress.codesPerSec = 0;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::BruterProgress,
            reinterpret_cast<const uint8_t*>(&progress),
            sizeof(BinaryBruterProgress));
    }

    for (uint32_t i = startCode; ; i++) {
        // Overflow-safe termination: for <32 bits, stop at total.
        // For 32 bits, the loop runs until i wraps past 0xFFFFFFFF.
        if (!is32bit && i >= total) break;

        if (bruterCancelFlag) {
            ESP_LOGI("Bruter", "Attack %s at code %lu/%lu",
                     pauseRequested ? "paused" : "cancelled", i, total);
            lastCodesSent = i; // Record where we stopped
            break;
        }

        // Progress report every BRUTER_PROGRESS_INTERVAL codes via BLE
        if ((i % BRUTER_PROGRESS_INTERVAL) == 0 && i > 0) {
            unsigned long elapsed = millis() - startTime;
            uint16_t cps = (elapsed > 0) ? (uint16_t)((uint64_t)i * 1000ULL / elapsed) : 0;

            BinaryBruterProgress progress;
            progress.currentCode = i;
            progress.totalCodes = total;
            progress.menuId = currentMenuId;
            progress.percentage = (uint8_t)((uint64_t)i * 100UL / total);
            progress.codesPerSec = cps;
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::BruterProgress,
                reinterpret_cast<const uint8_t*>(&progress),
                sizeof(BinaryBruterProgress));

            ESP_LOGD("Bruter", "Progress: %lu/%lu (%.1f%%) %d c/s - %s",
                     (unsigned long)i, (unsigned long)total,
                     (float)i / (float)total * 100.0f, cps, name);
        }

        for (int r = 0; r < globalRepeats; r++) {
            for (int p : proto->pilot_period) {
                sendPulse(p);
            }

            for (int b = bits - 1; b >= 0; b--) {
                char bitChar = ((i >> b) & 1) ? '1' : '0';
                if (proto->transposition_table.count(bitChar)) {
                    for (int t : proto->transposition_table[bitChar]) {
                        sendPulse(t);
                    }
                }
            }

            for (int s : proto->stop_bit) {
                sendPulse(s);
            }
            digitalWrite(RF_TX, LOW);
            vTaskDelay(pdMS_TO_TICKS(interFrameDelayMs));
        }
        yield();

        // For 32-bit keyspace, stop after processing 0xFFFFFFFF (i will overflow to 0)
        if (is32bit && i == 0xFFFFFFFFU) break;
    }
    // If we reached the end without cancel, record total
    if (!bruterCancelFlag) {
        lastCodesSent = total;
    }
    attackRunning = false;
    digitalWrite(RF_TX, LOW);
    digitalWrite(LED, LOW);
    ESP_LOGI("Bruter", "Binary attack finished: %s", name);
    return true;
}

bool BruterModule::attackTristate(bruter::c_rf_protocol* proto, const char* name, int positions, float mhz) {
    bruterCancelFlag = false;
    attackRunning = true;
    lastCodesSent = 0;
    currentAttackType = 1; // tristate
    setFrequencyCorrected(mhz);
    uint32_t total = 1;
    for (int p = 0; p < positions; p++) {
        total *= 3;
    }
    pauseTotalCodes = total;

    // Support resume: start from saved position
    uint32_t startCode = resumeFromCode;
    if (startCode >= total) startCode = 0;

    unsigned long startTime = millis();

    ESP_LOGI("Bruter", "Starting tristate attack: %s, positions=%d, freq=%.2f, total=%lu, start=%lu, delay=%dms",
             name, positions, mhz, total, (unsigned long)startCode, interFrameDelayMs);

    for (uint32_t i = startCode; i < total; i++) {
        if (bruterCancelFlag) {
            ESP_LOGI("Bruter", "Attack %s at code %lu/%lu",
                     pauseRequested ? "paused" : "cancelled", i, total);
            lastCodesSent = i;
            break;
        }

        // Progress report every BRUTER_PROGRESS_INTERVAL codes via BLE
        if ((i % BRUTER_PROGRESS_INTERVAL) == 0 && i > 0) {
            unsigned long elapsed = millis() - startTime;
            uint16_t cps = (elapsed > 0) ? (uint16_t)((uint64_t)i * 1000ULL / elapsed) : 0;

            BinaryBruterProgress progress;
            progress.currentCode = i;
            progress.totalCodes = total;
            progress.menuId = currentMenuId;
            progress.percentage = (uint8_t)((uint64_t)i * 100UL / total);
            progress.codesPerSec = cps;
            ClientsManager::getInstance().notifyAllBinary(
                NotificationType::BruterProgress,
                reinterpret_cast<const uint8_t*>(&progress),
                sizeof(BinaryBruterProgress));

            ESP_LOGD("Bruter", "Progress: %lu/%lu (%.1f%%) %d c/s - %s",
                     (unsigned long)i, (unsigned long)total,
                     (float)i / (float)total * 100.0f, cps, name);
        }

        uint32_t temp = i;
        for (int r = 0; r < globalRepeats; r++) {
            for (int p : proto->pilot_period) {
                sendPulse(p);
            }

            for (int p = 0; p < positions; p++) {
                int val = temp % 3;
                char code = (val == 0) ? '0' : (val == 1 ? '1' : 'F');
                if (proto->transposition_table.count(code)) {
                    for (int t : proto->transposition_table[code]) {
                        sendPulse(t);
                    }
                }
                temp /= 3;
            }
            temp = i;

            for (int s : proto->stop_bit) {
                sendPulse(s);
            }
            digitalWrite(RF_TX, LOW);
            vTaskDelay(pdMS_TO_TICKS(interFrameDelayMs));
        }
        yield();
    }
    if (!bruterCancelFlag) {
        lastCodesSent = total;
    }
    attackRunning = false;
    digitalWrite(RF_TX, LOW);
    digitalWrite(LED, LOW);
    ESP_LOGI("Bruter", "Tristate attack finished: %s", name);
    return true;
}

void BruterModule::menu1() {
    bruter::protocol_came p;
    attackBinary(&p, "CAME 12b", 12, 433.92);
}

void BruterModule::menu2() {
    bruter::protocol_princeton p;
    attackTristate(&p, "PRINCETON 12b", 12, 433.92);
}

void BruterModule::menu3() {
    bruter::protocol_niceflo p;
    attackBinary(&p, "NICEFLO 12b", 12, 433.92);
}

void BruterModule::menu4() {
    bruter::protocol_chamberlain p;
    attackBinary(&p, "CHAMBERLAIN 12b", 12, 315.0);
}

void BruterModule::menu5() {
    bruter::protocol_linear p;
    attackBinary(&p, "LINEAR 10b", 10, 300.0);
}

void BruterModule::menu6() {
    bruter::protocol_holtek p;
    attackBinary(&p, "HOLTEK 12b", 12, 433.92);
}

void BruterModule::menu7() {
    bruter::protocol_liftmaster p;
    attackBinary(&p, "LIFTMASTER 12b", 12, 315.0);
}

void BruterModule::menu8() {
    bruter::protocol_ansonic p;
    attackBinary(&p, "ANSONIC 12b", 12, 433.92);
}

void BruterModule::menu9() {
    bruter::protocol_ev1527 p;
    attackBinary(&p, "EV1527 12b", 12, 433.92);
}

void BruterModule::menu10() {
    bruter::protocol_honeywell p;
    attackBinary(&p, "HONEYWELL 12b", 12, 433.92);
}

void BruterModule::menu11() {
    bruter::protocol_faac p;
    attackBinary(&p, "FAAC 12b", 12, 433.92);
}

void BruterModule::menu12() {
    bruter::protocol_bft p;
    attackBinary(&p, "BFT 12b", 12, 433.92);
}

void BruterModule::menu13() {
    bruter::protocol_smc5326 p;
    attackTristate(&p, "SMC5326 12b", 12, 433.42);
}

// --- Menu 14-33: Newly integrated protocols ---

// European remotes (additional)
void BruterModule::menu14() {
    bruter::protocol_clemsa p;
    attackBinary(&p, "CLEMSA 12b", 12, 433.92);
}

void BruterModule::menu15() {
    bruter::protocol_gate_tx p;
    attackBinary(&p, "GATETX 12b", 12, 433.92);
}

void BruterModule::menu16() {
    bruter::protocol_phox p;
    attackBinary(&p, "PHOX 12b", 12, 433.92);
}

void BruterModule::menu17() {
    bruter::protocol_phoenix_v2 p;
    attackBinary(&p, "PHOENIX_V2 12b", 12, 433.92);
}

void BruterModule::menu18() {
    bruter::protocol_prastel p;
    attackBinary(&p, "PRASTEL 12b", 12, 433.92);
}

void BruterModule::menu19() {
    bruter::protocol_doitrand p;
    attackBinary(&p, "DOITRAND 12b", 12, 433.92);
}

// Home automation
void BruterModule::menu20() {
    bruter::protocol_dooya p;
    attackBinary(&p, "DOOYA 24b", 24, 433.92);
}

void BruterModule::menu21() {
    bruter::protocol_nero p;
    attackBinary(&p, "NERO 12b", 12, 433.92);
}

void BruterModule::menu22() {
    bruter::protocol_magellen p;
    attackBinary(&p, "MAGELLEN 12b", 12, 433.92);
}

// USA old / legacy
void BruterModule::menu23() {
    bruter::protocol_firefly p;
    attackBinary(&p, "FIREFLY 10b", 10, 300.0);
}

void BruterModule::menu24() {
    bruter::protocol_linear_megacode p;
    attackBinary(&p, "LINEAR_MEGACODE 24b", 24, 318.0);
}

// 868 MHz protocols
void BruterModule::menu25() {
    bruter::protocol_hormann p;
    attackBinary(&p, "HORMANN 12b", 12, 868.35);
}

void BruterModule::menu26() {
    bruter::protocol_marantec p;
    attackBinary(&p, "MARANTEC 12b", 12, 868.35);
}

void BruterModule::menu27() {
    bruter::protocol_berner p;
    attackBinary(&p, "BERNER 12b", 12, 868.35);
}

// Intertechno (32-bit)
void BruterModule::menu28() {
    bruter::protocol_intertechno_v3 p;
    attackBinary(&p, "INTERTECHNO_V3 32b", 32, 433.92);
}

// EV1527 24-bit variant (alarm sensors with full 24-bit keyspace)
void BruterModule::menu29() {
    bruter::protocol_ev1527 p;
    attackBinary(&p, "EV1527 24b", 24, 433.92);
}

// Others/Misc
void BruterModule::menu30() {
    bruter::protocol_starline p;
    attackBinary(&p, "STARLINE 12b", 12, 433.92);
}

void BruterModule::menu31() {
    bruter::protocol_tedsen p;
    attackBinary(&p, "TEDSEN 12b", 12, 433.92);
}

void BruterModule::menu32() {
    bruter::protocol_airforce p;
    attackBinary(&p, "AIRFORCE 12b", 12, 433.92);
}

void BruterModule::menu33() {
    bruter::protocol_unilarm p;
    attackBinary(&p, "UNILARM 12b", 12, 433.42);
}

// -----------------------------------------------------------------
// De Bruijn attack — transmits B(2,n) continuous bitstream
// -----------------------------------------------------------------

bool BruterModule::attackDeBruijn(
    bruter::c_rf_protocol* proto, const char* name,
    int bits, float mhz, int repeats)
{
    if (bits > DEBRUIJN_MAX_BITS || bits < 1) {
        ESP_LOGE("Bruter", "[DeBruijn] n=%d out of range [1..%d]", bits, DEBRUIJN_MAX_BITS);
        return false;
    }

    // Check heap before allocating the sequence
    if (!bruter::canGenerateDeBruijn(bits)) {
        ESP_LOGE("Bruter", "[DeBruijn] Insufficient heap for n=%d", bits);
        return false;
    }

    bruterCancelFlag = false;
    attackRunning = true;
    lastCodesSent = 0;
    currentAttackType = 2; // debruijn

    ESP_LOGI("Bruter", "[DeBruijn] Generating B(2,%d) for %s...", bits, name);

    // Generate the De Bruijn sequence (heap-allocated, caller must free)
    uint32_t seqLength = 0;
    uint8_t* seq = bruter::generateDeBruijn(bits, seqLength);
    if (seq == nullptr || seqLength == 0) {
        ESP_LOGE("Bruter", "[DeBruijn] Generation failed for n=%d", bits);
        attackRunning = false;
        return false;
    }

    ESP_LOGI("Bruter", "[DeBruijn] TX @ %.2f MHz | %lu bits | %d reps | %s",
             mhz, (unsigned long)seqLength, repeats, name);

    // Set frequency
    setFrequencyCorrected(mhz);

    uint32_t totalBitsAllReps = seqLength * (uint32_t)repeats;
    pauseTotalCodes = totalBitsAllReps;
    unsigned long startTime = millis();

    // Send initial 0% progress
    {
        BinaryBruterProgress progress;
        progress.currentCode = 0;
        progress.totalCodes = totalBitsAllReps;
        progress.menuId = currentMenuId;
        progress.percentage = 0;
        progress.codesPerSec = 0;
        ClientsManager::getInstance().notifyAllBinary(
            NotificationType::BruterProgress,
            reinterpret_cast<const uint8_t*>(&progress),
            sizeof(BinaryBruterProgress));
    }

    uint32_t globalBitsSent = 0;

    // Transmit with repeats
    for (int r = 0; r < repeats && !bruterCancelFlag; r++) {

        // Send pilot once at start of each repeat
        for (int p : proto->pilot_period) {
            sendPulse(p);
        }

        // Stream bits continuously — the core of De Bruijn
        for (uint32_t i = 0; i < seqLength && !bruterCancelFlag; i++) {
            char bitChar = seq[i] ? '1' : '0';

            // Look up transposition table and send pulses
            auto it = proto->transposition_table.find(bitChar);
            if (it != proto->transposition_table.end()) {
                for (int t : it->second) {
                    sendPulse(t);
                }
            }

            globalBitsSent++;

            // LED is managed by DeviceControls::bruterActiveBlink() in main loop

            // BLE progress every DEBRUIJN_PROGRESS_INTERVAL bits
            if (i > 0 && (i % DEBRUIJN_PROGRESS_INTERVAL) == 0) {
                unsigned long elapsed = millis() - startTime;
                uint32_t totalSentSoFar = (uint32_t)r * seqLength + i;
                uint8_t pct = (uint8_t)((uint64_t)totalSentSoFar * 100UL / totalBitsAllReps);
                uint16_t bps = (elapsed > 0)
                    ? (uint16_t)((uint32_t)totalSentSoFar * 1000UL / elapsed) : 0;

                BinaryBruterProgress progress;
                progress.currentCode = totalSentSoFar;
                progress.totalCodes  = totalBitsAllReps;
                progress.menuId      = currentMenuId;
                progress.percentage  = pct;
                progress.codesPerSec = bps;  // bits/sec in De Bruijn mode
                ClientsManager::getInstance().notifyAllBinary(
                    NotificationType::BruterProgress,
                    reinterpret_cast<const uint8_t*>(&progress),
                    sizeof(BinaryBruterProgress));
            }

            // Yield every 64 bits — gives loop() time for LED blink
            if ((i & 63) == 0 && i > 0) {
                yield();
            }
        }

        // Send stop bit at end of each repeat
        for (int s : proto->stop_bit) {
            sendPulse(s);
        }
        digitalWrite(RF_TX, LOW);

        // Short pause between repeats (no need for interFrameDelayMs here)
        if (r < repeats - 1 && !bruterCancelFlag) {
            vTaskDelay(pdMS_TO_TICKS(10));
        }
    }

    // Free the heap-allocated sequence immediately
    free(seq);
    seq = nullptr;

    // LED off, attack done
    digitalWrite(RF_TX, LOW);
    digitalWrite(LED, LOW);
    lastCodesSent = bruterCancelFlag ? 0 : globalBitsSent;
    attackRunning = false;

    ESP_LOGI("Bruter", "[DeBruijn] Done: %lu bits sent (%s) - %s",
             (unsigned long)globalBitsSent,
             bruterCancelFlag ? "cancelled" : "complete", name);
    return true;
}

// -----------------------------------------------------------------
// De Bruijn menu entries (35-40)
// -----------------------------------------------------------------

void BruterModule::menuDeBruijnGeneric433() {
    bruter::protocol_dynamic p(300, 3);  // Te=300us, ratio=1:3 (EV1527-style)
    attackDeBruijn(&p, "DB Generic 433", 12, 433.92, 5);
}

void BruterModule::menuDeBruijnGeneric315() {
    bruter::protocol_dynamic p(300, 3);
    attackDeBruijn(&p, "DB Generic 315", 12, 315.0, 5);
}

void BruterModule::menuDeBruijnHoltek() {
    bruter::protocol_holtek p;
    attackDeBruijn(&p, "DB Holtek 433", 12, 433.92, 3);
}

void BruterModule::menuDeBruijnLinear() {
    bruter::protocol_linear p;
    attackDeBruijn(&p, "DB Linear 300", 10, 300.0, 5);
}

void BruterModule::menuDeBruijnEV1527() {
    bruter::protocol_ev1527 p;
    attackDeBruijn(&p, "DB EV1527 433", 12, 433.92, 3);
}

void BruterModule::menuDeBruijnUniversal() {
    // Universal Auto-Attack: sweep multiple freq/timing/ratio/bits combos
    // 8 freqs × 3 timings × 2 ratios × 2 bit-lengths = 96 configurations
    static const float freqs[] = {433.92f, 315.0f, 868.35f, 300.0f,
                                   310.0f, 318.0f, 390.0f, 433.42f};
    static const int tes[] = {300, 200, 450};
    static const int ratios[] = {3, 2};
    static const int bitLengths[] = {12, 10};

    int configNum = 0;
    const int totalConfigs = 8 * 3 * 2 * 2;  // 96

    ESP_LOGI("Bruter", "[Universal] Starting %d-config sweep", totalConfigs);

    for (float f : freqs) {
        for (int b : bitLengths) {
            for (int te : tes) {
                for (int ratio : ratios) {
                    if (bruterCancelFlag) {
                        ESP_LOGI("Bruter", "[Universal] Cancelled at config %d/%d",
                                 configNum, totalConfigs);
                        return;
                    }

                    configNum++;
                    ESP_LOGI("Bruter", "[Universal] Config %d/%d: Freq=%.2f Bits=%d Te=%d Ratio=1:%d",
                             configNum, totalConfigs, f, b, te, ratio);

                    bruter::protocol_dynamic p(te, ratio);
                    attackDeBruijn(&p, "Universal", b, f, 3);
                }
            }
        }
    }

    ESP_LOGI("Bruter", "[Universal] Sweep complete: %d configs", totalConfigs);
}

void BruterModule::setCustomDeBruijnParams(uint8_t bits, uint16_t te, uint8_t ratio, float freqMhz) {
    customDbBits  = bits;
    customDbTe    = te;
    customDbRatio = ratio;
    customDbFreq  = freqMhz;
    ESP_LOGI("Bruter", "Custom De Bruijn params: bits=%d te=%d ratio=%d freq=%.2f",
             bits, te, ratio, freqMhz);
}

void BruterModule::menuDeBruijnCustom() {
    // Use the parameters set by BLE command 0xFD
    ESP_LOGI("Bruter", "[Custom DeBruijn] bits=%d te=%d ratio=1:%d freq=%.2f MHz",
             customDbBits, customDbTe, customDbRatio, customDbFreq);

    bruter::protocol_dynamic p(customDbTe, customDbRatio);
    attackDeBruijn(&p, "Custom DeBruijn", customDbBits, customDbFreq, globalRepeats);
}

void BruterModule::cancelAttack() {
    pauseRequested = false; // Stop, not pause — will clear saved state
    bruterCancelFlag = true;
    ESP_LOGI("Bruter", "Cancel (stop) requested");
}

bool BruterModule::isAttackRunning() const {
    return attackRunning;
}

void BruterModule::menu_elka() {
    bruter::protocol_elka p;
    attackBinary(&p, "ELKA 12b", 12, 433.92);
}