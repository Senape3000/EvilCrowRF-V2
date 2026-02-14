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
  int _bruterModule = 1;   // Default bruter module (0=Module 1, 1=Module 2)
  HwButtonAction _button1Action = HwButtonAction.none;
  HwButtonAction _button2Action = HwButtonAction.none;
  String? _button1ReplayPath;
  int _button1ReplayPathType = 1;
  String? _button2ReplayPath;
  int _button2ReplayPathType = 1;
  // NRF24 settings
  int _nrfPaLevel = 3;       // 0=MIN, 1=LOW, 2=HIGH, 3=MAX
  int _nrfDataRate = 0;      // 0=1MBPS, 1=2MBPS, 2=250KBPS
  int _nrfChannel = 76;      // Default channel (0-125)
  int _nrfAutoRetransmit = 5; // Retransmit count (0-15)

  bool get debugMode => _debugMode;
  int get bruterDelayMs => _bruterDelayMs;
  int get bruterModule => _bruterModule;
  HwButtonAction get button1Action => _button1Action;
  HwButtonAction get button2Action => _button2Action;
  String? get button1ReplayPath => _button1ReplayPath;
  int get button1ReplayPathType => _button1ReplayPathType;
  String? get button2ReplayPath => _button2ReplayPath;
  int get button2ReplayPathType => _button2ReplayPathType;
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
    _bruterModule = (prefs.getInt('bruterModule') ?? 1).clamp(0, 1);
    _button1Action = HwButtonAction.values[
      (prefs.getInt('hwButton1Action') ?? 0).clamp(0, HwButtonAction.values.length - 1)
    ];
    _button2Action = HwButtonAction.values[
      (prefs.getInt('hwButton2Action') ?? 0).clamp(0, HwButtonAction.values.length - 1)
    ];
    _button1ReplayPath = prefs.getString('hwButton1ReplayPath');
    _button1ReplayPathType = (prefs.getInt('hwButton1ReplayPathType') ?? 1).clamp(0, 5);
    _button2ReplayPath = prefs.getString('hwButton2ReplayPath');
    _button2ReplayPathType = (prefs.getInt('hwButton2ReplayPathType') ?? 1).clamp(0, 5);
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

  Future<void> setBruterModule(int value) async {
    _bruterModule = value.clamp(0, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bruterModule', _bruterModule);
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

  Future<void> setButton1ReplayFile(String? path, int pathType) async {
    _button1ReplayPath = path;
    _button1ReplayPathType = pathType.clamp(0, 5);
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove('hwButton1ReplayPath');
    } else {
      await prefs.setString('hwButton1ReplayPath', path);
    }
    await prefs.setInt('hwButton1ReplayPathType', _button1ReplayPathType);
    notifyListeners();
  }

  Future<void> setButton2ReplayFile(String? path, int pathType) async {
    _button2ReplayPath = path;
    _button2ReplayPathType = pathType.clamp(0, 5);
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove('hwButton2ReplayPath');
    } else {
      await prefs.setString('hwButton2ReplayPath', path);
    }
    await prefs.setInt('hwButton2ReplayPathType', _button2ReplayPathType);
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

  /// Sync HW button config received from the device (0xC8 message).
  /// Updates local settings to reflect what the firmware actually has.
  Future<void> syncButtonsFromDevice({
    required int btn1Action,
    required int btn2Action,
    int btn1PathType = 0,
    int btn2PathType = 0,
  }) async {
    final b1 = HwButtonAction.values[
        btn1Action.clamp(0, HwButtonAction.values.length - 1)];
    final b2 = HwButtonAction.values[
        btn2Action.clamp(0, HwButtonAction.values.length - 1)];
    bool changed = false;
    if (_button1Action != b1) {
      _button1Action = b1;
      changed = true;
    }
    if (_button2Action != b2) {
      _button2Action = b2;
      changed = true;
    }
    if (_button1ReplayPathType != btn1PathType) {
      _button1ReplayPathType = btn1PathType;
      changed = true;
    }
    if (_button2ReplayPathType != btn2PathType) {
      _button2ReplayPathType = btn2PathType;
      changed = true;
    }
    if (changed) {
      // Persist new values
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hwButton1Action', _button1Action.index);
      await prefs.setInt('hwButton2Action', _button2Action.index);
      await prefs.setInt('hwButton1ReplayPathType', _button1ReplayPathType);
      await prefs.setInt('hwButton2ReplayPathType', _button2ReplayPathType);
      notifyListeners();
    }
  }
}