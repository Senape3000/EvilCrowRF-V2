import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available actions for hardware buttons.
/// Order matches firmware enum HwButtonAction (0-6).
enum HwButtonAction {
  none,           // 0 — Do nothing
  toggleJammer,   // 1 — Toggle NRF 2.4 GHz jammer
  toggleRecording,// 2 — Toggle SubGhz signal recording
  replayLast,     // 3 — Replay last recorded signal
  toggleLed,      // 4 — Toggle LED on/off
  deepSleep,      // 5 — Enter deep sleep
  reboot,         // 6 — Reboot device
}

extension HwButtonActionLabel on HwButtonAction {
  String get label {
    switch (this) {
      case HwButtonAction.none: return 'None';
      case HwButtonAction.toggleJammer: return 'Toggle Jammer';
      case HwButtonAction.toggleRecording: return 'Toggle Recording';
      case HwButtonAction.replayLast: return 'Replay Last Signal';
      case HwButtonAction.toggleLed: return 'Toggle LED';
      case HwButtonAction.deepSleep: return 'Deep Sleep';
      case HwButtonAction.reboot: return 'Reboot';
    }
  }

  IconData get icon {
    switch (this) {
      case HwButtonAction.none: return Icons.block;
      case HwButtonAction.toggleJammer: return Icons.wifi_tethering_off;
      case HwButtonAction.toggleRecording: return Icons.fiber_manual_record;
      case HwButtonAction.replayLast: return Icons.replay;
      case HwButtonAction.toggleLed: return Icons.lightbulb_outline;
      case HwButtonAction.deepSleep: return Icons.bedtime;
      case HwButtonAction.reboot: return Icons.restart_alt;
    }
  }
}

class SettingsProvider with ChangeNotifier {
  bool _debugMode = false;
  int _bruterDelayMs = 10; // Default inter-frame delay in ms
  HwButtonAction _button1Action = HwButtonAction.none;
  HwButtonAction _button2Action = HwButtonAction.none;
  // NRF24 settings
  int _nrfPaLevel = 3;       // 0=MIN, 1=LOW, 2=HIGH, 3=MAX
  int _nrfDataRate = 0;      // 0=1MBPS, 1=2MBPS, 2=250KBPS
  int _nrfChannel = 76;      // Default channel (0-125)
  int _nrfAutoRetransmit = 5; // Retransmit count (0-15)

  bool get debugMode => _debugMode;
  int get bruterDelayMs => _bruterDelayMs;
  HwButtonAction get button1Action => _button1Action;
  HwButtonAction get button2Action => _button2Action;
  int get nrfPaLevel => _nrfPaLevel;
  int get nrfDataRate => _nrfDataRate;
  int get nrfChannel => _nrfChannel;
  int get nrfAutoRetransmit => _nrfAutoRetransmit;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _debugMode = prefs.getBool('debugMode') ?? false;
    _bruterDelayMs = prefs.getInt('bruterDelayMs') ?? 10;
    _button1Action = HwButtonAction.values[
      (prefs.getInt('hwButton1Action') ?? 0).clamp(0, HwButtonAction.values.length - 1)
    ];
    _button2Action = HwButtonAction.values[
      (prefs.getInt('hwButton2Action') ?? 0).clamp(0, HwButtonAction.values.length - 1)
    ];
    // NRF24 settings
    _nrfPaLevel = (prefs.getInt('nrfPaLevel') ?? 3).clamp(0, 3);
    _nrfDataRate = (prefs.getInt('nrfDataRate') ?? 0).clamp(0, 2);
    _nrfChannel = (prefs.getInt('nrfChannel') ?? 76).clamp(0, 125);
    _nrfAutoRetransmit = (prefs.getInt('nrfAutoRetransmit') ?? 5).clamp(0, 15);
    notifyListeners();
  }

  Future<void> setDebugMode(bool value) async {
    _debugMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debugMode', value);
    notifyListeners();
  }

  Future<void> setBruterDelayMs(int value) async {
    _bruterDelayMs = value.clamp(1, 1000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bruterDelayMs', _bruterDelayMs);
    notifyListeners();
  }

  Future<void> setButton1Action(HwButtonAction action) async {
    _button1Action = action;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hwButton1Action', action.index);
    notifyListeners();
  }

  Future<void> setButton2Action(HwButtonAction action) async {
    _button2Action = action;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hwButton2Action', action.index);
    notifyListeners();
  }

  Future<void> setNrfPaLevel(int value) async {
    _nrfPaLevel = value.clamp(0, 3);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nrfPaLevel', _nrfPaLevel);
    notifyListeners();
  }

  Future<void> setNrfDataRate(int value) async {
    _nrfDataRate = value.clamp(0, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nrfDataRate', _nrfDataRate);
    notifyListeners();
  }

  Future<void> setNrfChannel(int value) async {
    _nrfChannel = value.clamp(0, 125);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nrfChannel', _nrfChannel);
    notifyListeners();
  }

  Future<void> setNrfAutoRetransmit(int value) async {
    _nrfAutoRetransmit = value.clamp(0, 15);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nrfAutoRetransmit', _nrfAutoRetransmit);
    notifyListeners();
  }
}