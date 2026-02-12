/// Data model for working with signals
/// Contains all required parameters for recording, transmitting and analyzing signals
class SignalData {
  /// Frequency in MHz
  final double? frequency;
  
  /// Raw signal data (string representation)
  final String? raw;
  
  /// Binary signal data
  final String? binary;
  
  /// Smoothed signal data
  final String? smoothed;
  
  /// Data rate in kBaud
  final double? dataRate;
  
  /// Frequency deviation in kHz
  final double? deviation;
  
  /// Modulation type (name)
  final String? modulation;
  
  /// Pulse duration in microseconds
  final double? pulseDuration;
  
  /// Number of samples
  final int? samplesCount;
  
  /// Receiver bandwidth in kHz
  final double? rxBandwidth;
  
  /// Preset for configuration
  final String? preset;
  
  /// Transmission protocol
  final String? protocol;
  
  /// Raw data as number array
  final List<List<int>>? rawData;
  
  /// File name (if applicable)
  final String? filename;
  
  /// Creation/recording date
  final DateTime? dateCreated;
  
  /// File size in bytes
  final int? fileSize;
  
  /// Signal metadata
  final Map<String, dynamic>? metadata;
  
  SignalData({
    this.frequency,
    this.raw,
    this.binary,
    this.smoothed,
    this.dataRate,
    this.deviation,
    this.modulation,
    this.pulseDuration,
    this.samplesCount,
    this.rxBandwidth,
    this.preset,
    this.protocol,
    this.rawData,
    this.filename,
    this.dateCreated,
    this.fileSize,
    this.metadata,
  });
  
  /// Create copy with modifications
  SignalData copyWith({
    double? frequency,
    String? raw,
    String? binary,
    String? smoothed,
    double? dataRate,
    double? deviation,
    String? modulation,
    double? pulseDuration,
    int? samplesCount,
    double? rxBandwidth,
    String? preset,
    String? protocol,
    List<List<int>>? rawData,
    String? filename,
    DateTime? dateCreated,
    int? fileSize,
    Map<String, dynamic>? metadata,
  }) {
    return SignalData(
      frequency: frequency ?? this.frequency,
      raw: raw ?? this.raw,
      binary: binary ?? this.binary,
      smoothed: smoothed ?? this.smoothed,
      dataRate: dataRate ?? this.dataRate,
      deviation: deviation ?? this.deviation,
      modulation: modulation ?? this.modulation,
      pulseDuration: pulseDuration ?? this.pulseDuration,
      samplesCount: samplesCount ?? this.samplesCount,
      rxBandwidth: rxBandwidth ?? this.rxBandwidth,
      preset: preset ?? this.preset,
      protocol: protocol ?? this.protocol,
      rawData: rawData ?? this.rawData,
      filename: filename ?? this.filename,
      dateCreated: dateCreated ?? this.dateCreated,
      fileSize: fileSize ?? this.fileSize,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Validate signal data
  bool get isValid {
    // Minimum requirements for valid signal
    if (frequency == null || frequency! <= 0) return false;
    if (raw == null && rawData == null) return false;
    
    // Frequency range check
    if (frequency! < 300 || frequency! > 928) return false;
    
    return true;
  }
  
  /// Get file type based on extension
  String? get fileType {
    if (filename == null) return null;
    
    final extension = filename!.split('.').last.toLowerCase();
    switch (extension) {
      case 'sub':
        return 'FlipperZero SubGhz';
      case 'json':
        return 'TUT JSON';
      case 'raw':
        return 'RAW Data';
      default:
        return 'Unknown';
    }
  }
  
  /// Get displayable file size
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    
    const units = ['B', 'KB', 'MB', 'GB'];
    int unitIndex = 0;
    double size = fileSize!.toDouble();
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }
  
  /// Get formatted date
  String get formattedDate {
    if (dateCreated == null) return 'Unknown';
    
    return '${dateCreated!.day.toString().padLeft(2, '0')}/'
           '${dateCreated!.month.toString().padLeft(2, '0')}/'
           '${dateCreated!.year} '
           '${dateCreated!.hour.toString().padLeft(2, '0')}:'
           '${dateCreated!.minute.toString().padLeft(2, '0')}';
  }
  
  /// Get brief signal info
  String get summary {
    final parts = <String>[];
    
    if (frequency != null) {
      parts.add('${frequency!.toStringAsFixed(2)} MHz');
    }
    
    if (modulation != null) {
      parts.add(modulation!);
    }
    
    if (dataRate != null) {
      parts.add('${dataRate!.toStringAsFixed(1)} kBaud');
    }
    
    if (deviation != null) {
      parts.add('±${deviation!.toStringAsFixed(1)} kHz');
    }
    
    return parts.join(', ');
  }
  
  /// Convert to Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'raw': raw,
      'binary': binary,
      'smoothed': smoothed,
      'dataRate': dataRate,
      'deviation': deviation,
      'modulation': modulation,
      'pulseDuration': pulseDuration,
      'samplesCount': samplesCount,
      'rxBandwidth': rxBandwidth,
      'preset': preset,
      'protocol': protocol,
      'rawData': rawData,
      'filename': filename,
      'dateCreated': dateCreated?.toIso8601String(),
      'fileSize': fileSize,
      'metadata': metadata,
    };
  }
  
  /// Create from Map (for JSON deserialization)
  factory SignalData.fromJson(Map<String, dynamic> json) {
    return SignalData(
      frequency: json['frequency']?.toDouble(),
      raw: json['raw'] as String?,
      binary: json['binary'] as String?,
      smoothed: json['smoothed'] as String?,
      dataRate: json['dataRate']?.toDouble(),
      deviation: json['deviation']?.toDouble(),
      modulation: json['modulation'] as String?,
      pulseDuration: json['pulseDuration']?.toDouble(),
      samplesCount: json['samplesCount'] as int?,
      rxBandwidth: json['rxBandwidth']?.toDouble(),
      preset: json['preset'] as String?,
      protocol: json['protocol'] as String?,
      rawData: json['rawData'] != null 
          ? List<List<int>>.from(
              json['rawData'].map((row) => List<int>.from(row))
            )
          : null,
      filename: json['filename'] as String?,
      dateCreated: json['dateCreated'] != null 
          ? DateTime.parse(json['dateCreated'])
          : null,
      fileSize: json['fileSize'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  @override
  String toString() {
    return 'SignalData('
        'frequency: $frequency MHz, '
        'modulation: $modulation, '
        'dataRate: $dataRate kBaud, '
        'deviation: $deviation kHz, '
        'filename: $filename)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SignalData &&
        other.frequency == frequency &&
        other.raw == raw &&
        other.binary == binary &&
        other.smoothed == smoothed &&
        other.dataRate == dataRate &&
        other.deviation == deviation &&
        other.modulation == modulation &&
        other.preset == preset &&
        other.protocol == protocol &&
        other.filename == filename;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      frequency,
      raw,
      binary,
      smoothed,
      dataRate,
      deviation,
      modulation,
      preset,
      protocol,
      filename,
    );
  }
}

/// Signal file types
enum SignalFileType {
  flipperSub('.sub', 'FlipperZero SubGhz'),
  tutJson('.json', 'TUT JSON'),
  raw('.raw', 'RAW Data'),
  unknown('', 'Unknown');
  
  const SignalFileType(this.extension, this.description);
  
  final String extension;
  final String description;
  
  /// Determine file type by extension
  static SignalFileType fromExtension(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    for (final type in SignalFileType.values) {
      if (type.extension == '.$extension') {
        return type;
      }
    }
    
    return SignalFileType.unknown;
  }
}

/// Configuration for signal recording
class RecordConfig {
  final double frequency;
  final String? preset;
  final int module;
  final String? modulation;
  final double? bandwidth;
  final double? deviation;
  final double? dataRate;
  final double? rxBandwidth;
  final bool advancedMode;
  
  RecordConfig({
    required this.frequency,
    this.preset,
    required this.module,
    this.modulation,
    this.bandwidth,
    this.deviation,
    this.dataRate,
    this.rxBandwidth,
    this.advancedMode = false,
  });
  
  /// Create copy with modifications
  RecordConfig copyWith({
    double? frequency,
    String? preset,
    int? module,
    String? modulation,
    double? bandwidth,
    double? deviation,
    double? dataRate,
    double? rxBandwidth,
    bool? advancedMode,
  }) {
    return RecordConfig(
      frequency: frequency ?? this.frequency,
      preset: preset ?? this.preset,
      module: module ?? this.module,
      modulation: modulation ?? this.modulation,
      bandwidth: bandwidth ?? this.bandwidth,
      deviation: deviation ?? this.deviation,
      dataRate: dataRate ?? this.dataRate,
      rxBandwidth: rxBandwidth ?? this.rxBandwidth,
      advancedMode: advancedMode ?? this.advancedMode,
    );
  }
  
  /// Create from SignalData
  factory RecordConfig.fromSignalData(SignalData signal, int module) {
    return RecordConfig(
      frequency: signal.frequency ?? 433.92,
      preset: signal.preset,
      module: module,
      modulation: signal.modulation,
      bandwidth: signal.rxBandwidth,
      deviation: signal.deviation,
      dataRate: signal.dataRate,
      advancedMode: signal.modulation != null,
    );
  }
  
  /// Convert to Map for device transfer
  Map<String, dynamic> toDeviceParams() {
    final params = <String, dynamic>{
      'frequency': frequency,
      'module': module,
    };
    
    if (advancedMode) {
      if (modulation != null) params['modulation'] = modulation;
      if (bandwidth != null) params['bandwidth'] = bandwidth;
      if (deviation != null) params['deviation'] = deviation;
      if (dataRate != null) params['dataRate'] = dataRate;
    } else {
      if (preset != null) params['preset'] = preset;
    }
    
    return params;
  }
  
  @override
  String toString() {
    return 'RecordConfig('
        'frequency: $frequency MHz, '
        'module: $module, '
        'preset: $preset, '
        'modulation: $modulation)';
  }
}
