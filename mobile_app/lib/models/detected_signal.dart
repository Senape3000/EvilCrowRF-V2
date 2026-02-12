class DetectedSignal {
  final String frequency;
  final String modulation;
  final int rssi;
  final String data;
  final DateTime timestamp;
  final int module;
  final bool isBackgroundScanner;

  DetectedSignal({
    required this.frequency,
    required this.modulation,
    required this.rssi,
    required this.data,
    required this.timestamp,
    required this.module,
    this.isBackgroundScanner = false,
  });

  factory DetectedSignal.fromJson(Map<String, dynamic> json) {
    // In binary protocol, isBackgroundScanner comes as string 'false'
    // Parse it safely - can be bool or String
    bool isBackgroundScanner = false;
    if (json['isBackgroundScanner'] != null) {
      final value = json['isBackgroundScanner'];
      if (value is bool) {
        isBackgroundScanner = value;
      } else if (value is String) {
        isBackgroundScanner = value.toLowerCase() == 'true';
      }
    }
    
    return DetectedSignal(
      frequency: json['frequency']?.toString() ?? '0',
      modulation: json['modulation']?.toString() ?? 'Unknown',
      rssi: json['rssi'] ?? 0,
      data: json['data']?.toString() ?? '',
      timestamp: DateTime.now(),
      module: json['module'] ?? 0,
      isBackgroundScanner: isBackgroundScanner,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'modulation': modulation,
      'rssi': rssi,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'module': module,
      'isBackgroundScanner': isBackgroundScanner,
    };
  }

  @override
  String toString() {
    return 'DetectedSignal(frequency: $frequency, modulation: $modulation, rssi: $rssi, data: $data, module: $module, isBackgroundScanner: $isBackgroundScanner)';
  }

  // Formatted getters for UI display
  String get frequencyFormatted => '${double.tryParse(frequency)?.toStringAsFixed(2) ?? frequency} MHz';
  String get rssiFormatted => '$rssi dBm';
  String get timeFormatted => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
}
