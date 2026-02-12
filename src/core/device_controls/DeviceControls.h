#ifndef Device_Controls_h
#define Device_Controls_h

#include "config.h"
#include "modules/CC1101_driver/CC1101_Module.h"
#include "ConfigManager.h"

const int BLINK_ON_TIME = 200;
const int BLINK_OFF_TIME = 1000;

class DeviceControls {
  private:
    static unsigned long blinkTime;

  public:
    static void setup();
    static void onLoadPowerManagement();
    static void goDeepSleep();
    static void ledBlink(int count, int pause);
    static void poweronBlink();
    static void bruterActiveBlink();
    static void nrfJamActiveBlink();
    static void onLoadServiceMode();
};

#endif