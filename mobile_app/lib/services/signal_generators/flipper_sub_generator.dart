import '../cc1101/cc1101_calculator.dart';
import '../cc1101/cc1101_values.dart';
import '../signal_processing/signal_data.dart';
import 'base_signal_generator.dart';

/// Generator for FlipperZero .sub files
/// Creates files in FlipperZero SubGhz format for Flipper Zero compatibility
class FlipperSubGenerator extends BaseSignalGenerator {
  static const List<String> _supportedPresets = [
    'FuriHalSubGhzPresetOok270Async',
    'FuriHalSubGhzPresetOok650Async',
    'FuriHalSubGhzPreset2FSKDev238Async',
    'FuriHalSubGhzPreset2FSKDev476Async',
  ];
  
  static const Map<String, int> _modulationTypes = {
    '2-FSK': 0,
    'GFSK': 1,
    'ASK/OOK': 3,
    '4-FSK': 4,
    'MSK': 7,
  };
  
  static const Map<String, String> _configurationRegisters = {
    'MDMCFG4': '10',
    'MDMCFG3': '11',
    'MDMCFG2': '12',
    'DEVIATN': '15',
    'FREND0': '22',
  };
  
  // Signal parameters
  double? _frequency;
  double? _bandwidth;
  double? _dataRate;
  double? _deviation;
  String? _modulation;
  String? _dataRaw;
  String _preset = 'FuriHalSubGhzPresetCustom';
  bool _dcFilter = false;
  bool _manchesterEncoding = false;
  int _syncMode = 0;
  int _version = 1;
  
  final List<String> _errors = [];
  final CC1101Calculator _calculator = CC1101Calculator();
  
  /// Constructor
  FlipperSubGenerator();
  
  /// Set frequency
  FlipperSubGenerator setFrequency(double frequency) {
    _frequency = frequency;
    return this;
  }
  
  /// Set bandwidth
  FlipperSubGenerator setBandwidth(double bandwidth) {
    _bandwidth = bandwidth;
    return this;
  }
  
  /// Set data rate
  FlipperSubGenerator setDataRate(double dataRate) {
    _dataRate = dataRate;
    return this;
  }
  
  /// Set frequency deviation
  FlipperSubGenerator setDeviation(double deviation) {
    _deviation = deviation;
    return this;
  }
  
  /// Set modulation type
  FlipperSubGenerator setModulation(String modulation) {
    if (!_modulationTypes.containsKey(modulation)) {
      _errors.add('Unsupported modulation $modulation. Supported: ${_modulationTypes.keys.join(', ')}');
    }
    _modulation = modulation;
    return this;
  }
  
  /// Set preset
  FlipperSubGenerator setPreset(String preset) {
    _preset = preset;
    return this;
  }
  
  /// Set raw signal data
  FlipperSubGenerator setDataRaw(String dataRaw) {
    _dataRaw = dataRaw;
    return this;
  }
  
  /// Set DC filter
  FlipperSubGenerator setDcFilter(bool enabled) {
    _dcFilter = enabled;
    return this;
  }
  
  /// Set Manchester encoding
  FlipperSubGenerator setManchesterEncoding(bool enabled) {
    _manchesterEncoding = enabled;
    return this;
  }
  
  /// Set sync mode
  FlipperSubGenerator setSyncMode(int mode) {
    _syncMode = mode;
    return this;
  }
  
  /// Set format version
  FlipperSubGenerator setVersion(int version) {
    _version = version;
    return this;
  }
  
  /// Create generator from SignalData
  factory FlipperSubGenerator.fromSignalData(SignalData signalData) {
    final generator = FlipperSubGenerator();
    
    if (signalData.frequency != null) {
      generator.setFrequency(signalData.frequency!);
    }
    
    if (signalData.modulation != null) {
      generator.setModulation(signalData.modulation!);
    }
    
    if (signalData.rxBandwidth != null) {
      generator.setBandwidth(signalData.rxBandwidth! / 1000); // Convert to kHz
    }
    
    if (signalData.dataRate != null) {
      generator.setDataRate(signalData.dataRate! / 1000); // Convert to kBaud
    }
    
    if (signalData.deviation != null) {
      generator.setDeviation(signalData.deviation! / 1000); // Convert to kHz
    }
    
    if (signalData.preset != null) {
      generator.setPreset(signalData.preset!);
    }
    
    if (signalData.raw != null) {
      generator.setDataRaw(signalData.raw!);
    }
    
    return generator;
  }
  
  @override
  bool validate() {
    _errors.clear();
    
    if (_frequency == null) {
      _errors.add('Frequency is required');
    } else if (!CC1101Values.isValidFrequency(_frequency!)) {
      _errors.add('Invalid frequency: ${_frequency!.toStringAsFixed(2)} MHz. Must be in range 300-348, 387-464, or 779-928 MHz');
    }
    
    if (_dataRaw == null || _dataRaw!.trim().isEmpty) {
      _errors.add('Raw data is required');
    }
    
    if (_modulation != null && !_modulationTypes.containsKey(_modulation!)) {
      _errors.add('Unsupported modulation: $_modulation');
    }
    
    if (_dataRate != null && !CC1101Values.isValidDataRate(_dataRate!)) {
      _errors.add('Invalid data rate: ${_dataRate!.toStringAsFixed(2)} kBaud. Must be in range ${CC1101Values.dataRateLimits['min']}-${CC1101Values.dataRateLimits['max']} kBaud');
    }
    
    if (_deviation != null && !CC1101Values.isValidDeviation(_deviation!)) {
      _errors.add('Invalid deviation: ${_deviation!.toStringAsFixed(2)} kHz. Must be in range ${CC1101Values.deviationLimits['min']}-${CC1101Values.deviationLimits['max']} kHz');
    }
    
    return _errors.isEmpty;
  }
  
  @override
  String generate() {
    if (!validate()) {
      return _errors.join('\n');
    }
    
    final content = <String>[];
    content.add('Filetype: Flipper SubGhz RAW File');
    content.add(_generateVersion());
    content.add(_generateFrequency());
    content.add(_generatePreset());
    
    if (_preset == 'FuriHalSubGhzPresetCustom') {
      content.add(_generateCustomPresetModule());
      content.add(_generateCustomPresetData());
    }
    
    content.add('Protocol: RAW');
    
    if (_dataRaw != null) {
      final rows = _splitStringByWords(_dataRaw!, 512);
      for (final row in rows) {
        content.add('RAW_Data: $row');
      }
    }
    
    return content.join('\n');
  }
  
  @override
  List<String> getErrors() => List.unmodifiable(_errors);
  
  @override
  List<String> getSupportedExtensions() => ['.sub'];
  
  @override
  String getFormatDescription() => 'FlipperZero SubGhz RAW File';
  
  /// Generate file version
  String _generateVersion() {
    return 'Version: $_version';
  }
  
  /// Generate frequency string
  String _generateFrequency() {
    return 'Frequency: ${(_frequency! * 1000000).toInt()}';
  }
  
  /// Generate preset string
  String _generatePreset() {
    return 'Preset: $_preset';
  }
  
  /// Generate custom preset module string
  String _generateCustomPresetModule() {
    return 'Custom_preset_module: CC1101';
  }
  
  /// Generate custom preset data
  String _generateCustomPresetData() {
    final presetRow = <String>[];
    
    if (_bandwidth != null) {
      final bwHex = _calculator.bandwidthToHex(_bandwidth!);
      presetRow.add(_configurationRegisters['MDMCFG4']!);
      presetRow.add('${bwHex}0'); // Default data rate exponent
    }
    
    if (_dataRate != null) {
      final drHex = _calculator.dataRateToHex(_dataRate!);
      presetRow.add(_configurationRegisters['MDMCFG3']!);
      presetRow.add(drHex.m);
    }
    
    if (_deviation != null) {
      final devHex = _calculator.deviationToHex(_deviation!);
      presetRow.add(_configurationRegisters['DEVIATN']!);
      presetRow.add('${devHex.e}${devHex.m}');
    }
    
    if (_modulation != null) {
      presetRow.add(_configurationRegisters['MDMCFG2']!);
      final modulationNum = _modulationTypes[_modulation]!;
      final mdmcfg2High = (modulationNum + (_dcFilter ? 8 : 0)).toRadixString(16).toUpperCase();
      final mdmcfg2Low = (_syncMode + (_manchesterEncoding ? 8 : 0)).toRadixString(16).toUpperCase();
      presetRow.add('$mdmcfg2High$mdmcfg2Low');
      
      presetRow.add(_configurationRegisters['FREND0']!);
      final frend0 = _modulation == 'ASK/OOK' ? '11' : '10';
      presetRow.add(frend0);
    }
    
    presetRow.add('00 00 00 C0 00 00 00 00 00 00');
    
    return 'Custom_preset_data: ${presetRow.join(' ')}';
  }
  
  /// Split string into parts by words
  List<String> _splitStringByWords(String text, int wordLimit) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];
    
    for (int i = 0; i < words.length; i += wordLimit) {
      final chunk = words.skip(i).take(wordLimit).join(' ');
      chunks.add(chunk);
    }
    
    return chunks;
  }
  
  /// Get generation result
  SignalGenerationResult generateResult() {
    if (!validate()) {
      return SignalGenerationResult.error(errors: _errors);
    }
    
    final content = generate();
    return SignalGenerationResult.success(
      content: content,
      fileType: 'FlipperZero SubGhz',
      fileExtension: '.sub',
    );
  }
  
  @override
  String toString() {
    return 'FlipperSubGenerator('
        'frequency: $_frequency MHz, '
        'modulation: $_modulation, '
        'preset: $_preset, '
        'dataRaw: ${_dataRaw?.length ?? 0} chars)';
  }
}
