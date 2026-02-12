/// Predefined values for CC1101 module
/// Contains frequencies, bandwidths, presets and other constants
class CC1101Values {
  /// List of supported frequencies in MHz
  static const List<String> frequencies = [
    '300.00', '303.87', '304.25', '310.00', '315.00', '318.00',
    '390.00', '418.00', '433.07', '433.42', '433.92', '434.42',
    '434.77', '438.90', '868.35', '915.00', '916.80', '925.00',
  ];
  
  /// Data rate limits
  static const Map<String, double> dataRateLimits = {
    'min': 0.0248,  // Minimum data rate in kBaud
    'max': 1621.83, // Maximum data rate in kBaud
  };
  
  /// Frequency deviation limits
  static const Map<String, double> deviationLimits = {
    'min': 1.5869,  // Minimum deviation in kHz
    'max': 380.8593, // Maximum deviation in kHz
  };
  
  /// Allowed frequency ranges
  static const List<Map<String, double>> frequencyRanges = [
    {'min': 300.0, 'max': 348.0},
    {'min': 387.0, 'max': 464.0},
    {'min': 779.0, 'max': 928.0},
  ];
  
  /// Available bandwidths
  /// float - exact value for calculations
  /// value - display value
  static const List<Map<String, String>> bandwidths = [
    {'float': '812.500', 'value': '812.50'},
    {'float': '650.000', 'value': '650.00'},
    {'float': '541.667', 'value': '541.67'},
    {'float': '464.286', 'value': '464.29'},
    {'float': '406.250', 'value': '406.25'},
    {'float': '325.000', 'value': '325.00'},
    {'float': '270.833', 'value': '270.83'},
    {'float': '232.143', 'value': '232.14'},
    {'float': '203.125', 'value': '203.13'},
    {'float': '162.500', 'value': '162.50'},
    {'float': '135.417', 'value': '135.41'},
    {'float': '116.071', 'value': '116.07'},
    {'float': '101.563', 'value': '101.56'},
    {'float': '81.250', 'value': '81.25'},
    {'float': '67.708', 'value': '67.70'},
    {'float': '58.036', 'value': '58.04'},
  ];
  
  /// Predefined presets for quick setup
  static const List<Map<String, dynamic>> presets = [
    {
      'name': 'AM 270',
      'value': 'Ook270',
      'fzName': 'FuriHalSubGhzPresetOok270Async',
      'modulation': 'ASK/OOK (AM)',
      'bandwidth': '270.83 kHz',
      'dataRate': '3.79 kBaud',
    },
    {
      'name': 'AM 650',
      'value': 'Ook650',
      'fzName': 'FuriHalSubGhzPresetOok650Async',
      'modulation': 'ASK/OOK (AM)',
      'bandwidth': '650.00 kHz',
      'dataRate': '3.79 kBaud',
    },
    {
      'name': 'FM 2.38',
      'value': '2FSKDev238',
      'fzName': 'FuriHalSubGhzPreset2FSKDev238Async',
      'modulation': '2-FSK (FM)',
      'bandwidth': '270.83 kHz',
      'deviation': '2.38 kHz',
      'dataRate': '4.80 kBaud',
    },
    {
      'name': 'FM 47.6',
      'value': '2FSKDev476',
      'fzName': 'FuriHalSubGhzPreset2FSKDev476Async',
      'modulation': '2-FSK (FM)',
      'bandwidth': '270.83 kHz',
      'deviation': '47.6 kHz',
      'dataRate': '4.80 kBaud',
    },
  ];
  
  /// Modulation types
  static const Map<String, int> modulationTypes = {
    '2-FSK': 0,
    'GFSK': 1,
    'ASK/OOK': 3,
    '4-FSK': 4,
    'MSK': 7,
  };
  
  /// Reverse mapping: modulation number -> name
  static const Map<int, String> modulationNames = {
    0: '2-FSK',
    1: 'GFSK',
    3: 'ASK/OOK',
    4: '4-FSK',
    7: 'MSK',
  };
  
  /// Validate frequency
  /// [frequency] - frequency in MHz
  /// Returns true if frequency is in valid range
  static bool isValidFrequency(double frequency) {
    for (final range in frequencyRanges) {
      if (frequency >= range['min']! && frequency <= range['max']!) {
        return true;
      }
    }
    return false;
  }
  
  /// Get float frequency value from string value
  static double? getFrequencyFloat(String value) {
    try {
      if (frequencies.contains(value)) {
        return double.parse(value);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get nearest valid frequency
  /// [frequency] - original frequency in MHz
  /// Returns nearest valid frequency or original if valid
  static double? getClosestValidFrequency(double frequency) {
    double? closest;
    double minDifference = double.infinity;
    
    for (final range in frequencyRanges) {
      final min = range['min']!;
      final max = range['max']!;
      
      if (frequency < min) {
        final difference = min - frequency;
        if (difference < minDifference) {
          minDifference = difference;
          closest = min;
        }
      } else if (frequency > max) {
        final difference = frequency - max;
        if (difference < minDifference) {
          minDifference = difference;
          closest = max;
        }
      } else {
        return frequency; // Already valid
      }
    }
    
    return closest;
  }
  
  /// Validate data rate
  /// [dataRate] - data rate in kBaud
  /// Returns true if data rate is in valid range
  static bool isValidDataRate(double dataRate) {
    return dataRate >= dataRateLimits['min']! && 
           dataRate <= dataRateLimits['max']!;
  }
  
  /// Validate frequency deviation
  /// [deviation] - deviation in kHz
  /// Returns true if deviation is in valid range
  static bool isValidDeviation(double deviation) {
    return deviation >= deviationLimits['min']! && 
           deviation <= deviationLimits['max']!;
  }
  
  /// Get clamped data rate value
  /// [dataRate] - original data rate in kBaud
  /// Returns value within allowed range
  static double limitDataRate(double dataRate) {
    if (dataRate < dataRateLimits['min']!) {
      return dataRateLimits['min']!;
    }
    if (dataRate > dataRateLimits['max']!) {
      return dataRateLimits['max']!;
    }
    return dataRate;
  }
  
  /// Get clamped frequency deviation value
  /// [deviation] - original deviation in kHz
  /// Returns value within allowed range
  static double limitDeviation(double deviation) {
    if (deviation < deviationLimits['min']!) {
      return deviationLimits['min']!;
    }
    if (deviation > deviationLimits['max']!) {
      return deviationLimits['max']!;
    }
    return deviation;
  }
  
  /// Get preset by value
  /// [value] - preset value (e.g. 'Ook270')
  /// Returns preset or null if not found
  static Map<String, dynamic>? getPresetByValue(String value) {
    try {
      return presets.firstWhere((preset) => preset['value'] == value);
    } catch (e) {
      return null;
    }
  }
  
  /// Get preset by FZ name
  /// [fzName] - FlipperZero preset name (e.g. 'FuriHalSubGhzPresetOok270Async')
  /// Returns preset or null if not found
  static Map<String, dynamic>? getPresetByFzName(String fzName) {
    try {
      return presets.firstWhere((preset) => preset['fzName'] == fzName);
    } catch (e) {
      return null;
    }
  }
  
  /// Get modulation name by number
  /// [modulation] - modulation number
  /// Returns modulation name or 'Unknown'
  static String getModulationName(int modulation) {
    return modulationNames[modulation] ?? 'Unknown';
  }
  
  /// Get modulation number by name
  /// [name] - modulation name
  /// Returns modulation number or null if not found
  static int? getModulationNumber(String name) {
    return modulationTypes[name];
  }
  
  /// Get list of modulation names
  /// Returns list of available modulation names
  static List<String> getModulationNames() {
    return modulationTypes.keys.toList();
  }
  
  /// Get list of bandwidth values
  /// Returns list of values for display
  static List<String> getBandwidthValues() {
    return bandwidths.map((bw) => bw['value']!).toList();
  }
  
  /// Get exact bandwidth value
  /// [displayValue] - display value (e.g. '270.83')
  /// Returns exact value for calculations
  static double? getBandwidthFloat(String displayValue) {
    try {
      final bandwidth = bandwidths.firstWhere(
        (bw) => bw['value'] == displayValue
      );
      return double.parse(bandwidth['float']!);
    } catch (e) {
      return null;
    }
  }
}
