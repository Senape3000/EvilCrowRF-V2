import 'dart:math';

/// Calculator for CC1101 module parameters
/// Provides functions for converting between physical values and hex codes
class CC1101Calculator {
  static const double oscillatorFrequency = 26e6; // 26 MHz
  
  /// CC1101 registers
  static const Map<String, String> registers = {
    'IOCFG2': '00',
    'IOCFG1': '01',
    'IOCFG0': '02',
    'FIFOTHR': '03',
    'SYNC1': '04',
    'SYNC0': '05',
    'PKTLEN': '06',
    'PKTCTRL1': '07',
    'PKTCTRL0': '08',
    'ADDR': '09',
    'CHANNR': '0A',
    'FSCTRL1': '0B',
    'FSCTRL0': '0C',
    'FREQ2': '0D',
    'FREQ1': '0E',
    'FREQ0': '0F',
    'MDMCFG4': '10',
    'MDMCFG3': '11',
    'MDMCFG2': '12',
    'MDMCFG1': '13',
    'MDMCFG0': '14',
    'DEVIATN': '15',
    'MCSM2': '16',
    'MCSM1': '17',
    'MCSM0': '18',
    'FOCCFG': '19',
    'BSCFG': '1A',
    'AGCCTRL2': '1B',
    'AGCCTRL1': '1C',
    'AGCCTRL0': '1D',
    'WOREVT1': '1E',
    'WOREVT0': '1F',
    'WORCTRL': '20',
    'FREND1': '21',
    'FREND0': '22',
    'FSCAL3': '23',
    'FSCAL2': '24',
    'FSCAL1': '25',
    'FSCAL0': '26',
    'RCCTRL1': '27',
    'RCCTRL0': '28',
    'FSTEST': '29',
    'PTEST': '2A',
    'AGCTEST': '2B',
    'TEST2': '2C',
    'TEST1': '2D',
    'TEST0': '2E',
  };
  
  /// Convert Data Rate to hex
  /// [dataRate] - data rate in kBaud
  /// Returns structure with exponent and mantissa
  DataRateHex dataRateToHex(double dataRate) {
    final drateRaw = dataRate * 1000;
    final drateE = (log(drateRaw * (1 << 20) / oscillatorFrequency) / ln2).floor() & 0x0F;
    final drateM = ((drateRaw * (1 << 28)) / (oscillatorFrequency * (1 << drateE)) - 256).round();
    
    return DataRateHex(
      e: drateE.toRadixString(16).toUpperCase(),
      m: drateM.toRadixString(16).toUpperCase(),
    );
  }
  
  /// Convert Deviation to hex
  /// [deviation] - frequency deviation in kHz
  /// Returns structure with exponent and mantissa
  DeviationHex deviationToHex(double deviation) {
    final deviationRaw = deviation * 1000;
    final deviationE = (log(deviationRaw * (1 << 14) / oscillatorFrequency) / ln2).floor() & 0x07;
    final deviationM = ((deviationRaw * (1 << 17)) / (oscillatorFrequency * (1 << deviationE)) - 8).round() & 0x07;
    
    return DeviationHex(
      e: deviationE.toRadixString(16).toUpperCase(),
      m: deviationM.toRadixString(16).toUpperCase(),
    );
  }
  
  /// Convert Bandwidth to hex
  /// [bandwidth] - bandwidth in kHz
  /// Returns hex code for register
  String bandwidthToHex(double bandwidth) {
    const bandwidthList = [
      812000, 650000, 541000, 464000, 406000, 325000, 270000,
      232000, 203000, 162000, 135000, 116000, 102000, 81000,
      68000, 58000
    ];
    
    final bandwidthRaw = bandwidth * 1000;
    int bandwidthIndex = 15;
    
    for (int i = 0; i < 16; i++) {
      if (bandwidthRaw >= bandwidthList[i]) {
        bandwidthIndex = i;
        break;
      }
    }
    
    return bandwidthList[bandwidthIndex].toRadixString(16).toUpperCase();
  }
  
  /// Convert Frequency to hex
  /// [frequency] - frequency in MHz
  /// Returns structure with three frequency bytes
  FrequencyHex frequencyToHex(double frequency) {
    final frequencyRaw = frequency * 1000000;
    final frequencyWord = frequencyRaw * (1 << 16) / oscillatorFrequency;
    
    final frequencyHigh = (frequencyWord / (1 << 16)).floor() & 0xFF;
    final frequencyMiddle = (frequencyWord / (1 << 8)).floor() & 0xFF;
    final frequencyLow = frequencyWord.floor() & 0xFF;
    
    return FrequencyHex(
      high: frequencyHigh.toRadixString(16).toUpperCase(),
      middle: frequencyMiddle.toRadixString(16).toUpperCase(),
      low: frequencyLow.toRadixString(16).toUpperCase(),
    );
  }
  
  /// Parse CC1101 configuration from status
  /// [config] - register-to-value map
  /// Returns structure with parsed parameters
  CC1101Config parseConfig(Map<String, String> config) {
    final frequency = _hexToFrequency(
      config[registers['FREQ2']] ?? '00',
      config[registers['FREQ1']] ?? '00',
      config[registers['FREQ0']] ?? '00',
    );
    
    final bandwidth = _hexToBandwidth(config[registers['MDMCFG4']] ?? '00');
    final modulation = _hexToModulation(config[registers['MDMCFG2']] ?? '00');
    final modulationName = _hexToModulationName(config[registers['MDMCFG2']] ?? '00');
    final dataRate = _hexToDataRate(
      config[registers['MDMCFG4']] ?? '00',
      config[registers['MDMCFG3']] ?? '00',
    );
    final deviation = _hexToDeviation(config[registers['DEVIATN']] ?? '00');
    
    return CC1101Config(
      frequency: frequency,
      bandwidth: bandwidth,
      modulation: modulation,
      modulationName: modulationName,
      dataRate: dataRate,
      deviation: deviation,
    );
  }
  
  /// Convert hex to frequency
  double _hexToFrequency(String high, String middle, String low) {
    final frequencyHigh = int.parse(high, radix: 16);
    final frequencyMiddle = int.parse(middle, radix: 16);
    final frequencyLow = int.parse(low, radix: 16);
    
    final frequencyWord = (frequencyHigh << 16) | (frequencyMiddle << 8) | frequencyLow;
    final frequencyRaw = (frequencyWord * oscillatorFrequency) / (1 << 16);
    
    return frequencyRaw / 1000000;
  }
  
  /// Convert hex to bandwidth
  double _hexToBandwidth(String value) {
    final registryValue = int.parse(value, radix: 16);
    final chanbwE = (registryValue >> 6) & 0x03;
    final chanbwM = (registryValue >> 4) & 0x03;
    
    return oscillatorFrequency / (8 * (4 + chanbwM) * pow(2, chanbwE));
  }
  
  /// Convert hex to modulation type
  int _hexToModulation(String value) {
    return (int.parse(value, radix: 16) >> 4) & 7;
  }
  
  /// Convert hex to modulation name
  String _hexToModulationName(String value) {
    final mod = _hexToModulation(value);
    switch (mod) {
      case 0:
        return '2-FSK';
      case 1:
        return 'GFSK';
      case 3:
        return 'ASK/OOK';
      case 4:
        return '4-FSK';
      case 7:
        return 'MSK';
      default:
        return 'Unknown';
    }
  }
  
  /// Convert hex to data rate
  double _hexToDataRate(String mdmcfg4, String mdmcfg3) {
    final mdmcfg4Value = int.parse(mdmcfg4, radix: 16);
    final mdmcfg3Value = int.parse(mdmcfg3, radix: 16);
    final drateE = mdmcfg4Value & 0x0F;
    final drateM = mdmcfg3Value;
    
    return (oscillatorFrequency / pow(2, 28)) * (256 + drateM) * pow(2, drateE);
  }
  
  /// Convert hex to frequency deviation
  double _hexToDeviation(String deviatn) {
    final deviation = int.parse(deviatn, radix: 16);
    final deviationE = (deviation & 0x70) >> 4;
    final deviationM = deviation & 0x07;
    
    return (oscillatorFrequency / pow(2, 17)) * (8 + deviationM) * pow(2, deviationE);
  }
}

/// Structure for storing Data Rate in hex format
class DataRateHex {
  final String e; // Exponent
  final String m; // Mantissa
  
  DataRateHex({required this.e, required this.m});
  
  @override
  String toString() => 'DataRateHex(e: $e, m: $m)';
}

/// Structure for storing Deviation in hex format
class DeviationHex {
  final String e; // Exponent
  final String m; // Mantissa
  
  DeviationHex({required this.e, required this.m});
  
  @override
  String toString() => 'DeviationHex(e: $e, m: $m)';
}

/// Structure for storing Frequency in hex format
class FrequencyHex {
  final String high;   // High byte
  final String middle; // Middle byte
  final String low;    // Low byte
  
  FrequencyHex({required this.high, required this.middle, required this.low});
  
  @override
  String toString() => 'FrequencyHex(high: $high, middle: $middle, low: $low)';
}

/// CC1101 module configuration
class CC1101Config {
  final double frequency;      // Frequency in MHz
  final double bandwidth;      // Bandwidth in Hz
  final int modulation;        // Modulation type (number)
  final String modulationName; // Modulation name
  final double dataRate;       // Data rate in Hz
  final double deviation;      // Frequency deviation in Hz
  
  CC1101Config({
    required this.frequency,
    required this.bandwidth,
    required this.modulation,
    required this.modulationName,
    required this.dataRate,
    required this.deviation,
  });
  
  @override
  String toString() => 'CC1101Config('
      'frequency: ${frequency.toStringAsFixed(2)} MHz, '
      'bandwidth: ${(bandwidth / 1000).toStringAsFixed(2)} kHz, '
      'modulation: $modulationName, '
      'dataRate: ${(dataRate / 1000).toStringAsFixed(2)} kHz, '
      'deviation: ${(deviation / 1000).toStringAsFixed(2)} kHz)';
}

/// Parse CC1101 settings string
/// [settingsString] - string like "00 0D 01 2E 02 0D ..."
/// Returns register-to-value map
Map<String, String> parseSettingsString(String settingsString) {
  final Map<String, String> config = {};
  final parts = settingsString.trim().split(' ');
  
  for (int i = 0; i < parts.length - 1; i += 2) {
    final register = parts[i];
    final value = parts[i + 1];
    config[register] = value;
  }
  
  return config;
}

/// Parse module settings from string
/// [settingsString] - string like "00 0D 01 2E 02 0D ..."
/// Returns CC1101Config structure with parsed parameters
CC1101Config parseSettingsFromString(String settingsString) {
  final config = parseSettingsString(settingsString);
  final calculator = CC1101Calculator();
  return calculator.parseConfig(config);
}

