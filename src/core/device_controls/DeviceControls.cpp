#include "DeviceControls.h"

unsigned long DeviceControls::blinkTime = 0;

void DeviceControls::setup()
{
    pinMode(LED, OUTPUT);
    pinMode(BUTTON1, INPUT);
    pinMode(BUTTON2, INPUT);
}

void DeviceControls::onLoadPowerManagement()
{
    if (digitalRead(BUTTON2) != LOW && digitalRead(BUTTON1) == LOW) {
        if (ConfigManager::isSleepMode()) {
            goDeepSleep();
        }
    }

    if (digitalRead(BUTTON2) == LOW && digitalRead(BUTTON1) == HIGH) {
        if (!ConfigManager::isSleepMode()) {
            ConfigManager::setSleepMode(1);
            goDeepSleep();
        } else {
            ConfigManager::setSleepMode(0);
        }
    }
}

void DeviceControls::onLoadServiceMode()
{
    if (digitalRead(BUTTON1) == LOW && digitalRead(BUTTON2) == LOW) {
        if (!ConfigManager::isServiceMode()) {
            ConfigManager::setServiceMode(1);
        } else {
            ConfigManager::setServiceMode(0);
        }
    }
}

void DeviceControls::goDeepSleep()
{
    for (int i = 0; i < CC1101_NUM_MODULES; i++) {
        moduleCC1101State[i].goSleep();
    }
    ledBlink(5, 150);
    esp_deep_sleep_start();
}

void DeviceControls::ledBlink(int count, int pause)
{
    for (int i = 0; i < count; i++) {
        digitalWrite(LED, HIGH);
        delay(pause);
        digitalWrite(LED, LOW);
        delay(pause);
    }
}

void DeviceControls::poweronBlink()
{
    if (millis() - blinkTime > BLINK_OFF_TIME) {
        digitalWrite(LED, LOW);
    }
    if (millis() - blinkTime > BLINK_OFF_TIME + BLINK_ON_TIME) {
        digitalWrite(LED, HIGH);
        blinkTime = millis();
    }
}

void DeviceControls::bruterActiveBlink()
{
    static unsigned long bruterBlinkTime = 0;
    static bool bruterLedState = false;

    if (millis() - bruterBlinkTime > 100) {  // Fast blink every 100ms
        bruterLedState = !bruterLedState;
        digitalWrite(LED, bruterLedState ? HIGH : LOW);
        bruterBlinkTime = millis();
    }
}

void DeviceControls::nrfJamActiveBlink()
{
    // Double-flash pattern to distinguish from bruter blink:
    // ON 50ms - OFF 50ms - ON 50ms - OFF 200ms (total period ~350ms)
    static unsigned long jamBlinkTime = 0;
    static uint8_t jamBlinkPhase = 0;
    unsigned long elapsed = millis() - jamBlinkTime;

    switch (jamBlinkPhase) {
        case 0: // First flash ON
            if (elapsed > 200) {
                digitalWrite(LED, HIGH);
                jamBlinkTime = millis();
                jamBlinkPhase = 1;
            }
            break;
        case 1: // First flash OFF
            if (elapsed > 50) {
                digitalWrite(LED, LOW);
                jamBlinkTime = millis();
                jamBlinkPhase = 2;
            }
            break;
        case 2: // Second flash ON
            if (elapsed > 50) {
                digitalWrite(LED, HIGH);
                jamBlinkTime = millis();
                jamBlinkPhase = 3;
            }
            break;
        case 3: // Gap before restart
            if (elapsed > 50) {
                digitalWrite(LED, LOW);
                jamBlinkTime = millis();
                jamBlinkPhase = 0;
            }
            break;
    }
}