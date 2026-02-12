import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../services/cc1101/cc1101_values.dart';
import '../widgets/record_screen_widgets.dart';

/// Signal transmission screen
/// Allows configuring CC1101 parameters and transmitting signals
class TransmitScreen extends StatefulWidget {
  const TransmitScreen({super.key});

  @override
  State<TransmitScreen> createState() => _TransmitScreenState();
}

class _TransmitScreenState extends State<TransmitScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedModule = 0;
  
  // Configurations for each module
  final List<TransmitConfig> _transmitConfigs = [];
  
  // Controllers for input fields
  final List<TextEditingController> _frequencyControllers = [];
  final List<TextEditingController> _dataRateControllers = [];
  final List<TextEditingController> _deviationControllers = [];
  final List<TextEditingController> _rawDataControllers = [];
  final List<TextEditingController> _repeatControllers = [];
  
  // Flags for tracking changes
  final List<bool> _configsChanged = [];
  
  @override
  void initState() {
    super.initState();
    _initializeConfigs();
    _tabController = TabController(length: 1, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }
  
  void _initializeConfigs() {
    // Initialize configurations for modules
    for (int i = 0; i < 2; i++) { // Assuming 2 CC1101 modules
       _transmitConfigs.add(TransmitConfig(
         frequency: 433.92,
         module: i,
         advancedMode: false,
         preset: 'Ook270',
         modulation: 'ASK/OOK',
         rawData: '',
         repeatCount: 1,
       ));
      
      _configsChanged.add(false);
      
      // Create controllers for input fields
      _frequencyControllers.add(TextEditingController(text: '433.92'));
      _dataRateControllers.add(TextEditingController());
      _deviationControllers.add(TextEditingController());
      _rawDataControllers.add(TextEditingController());
      _repeatControllers.add(TextEditingController(text: '1'));
    }
    
    // Update tab count based on module count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _tabController = TabController(length: _transmitConfigs.length, vsync: this);
        });
      }
    });
  }
  
  void _disposeControllers() {
    for (final controller in _frequencyControllers) {
      controller.dispose();
    }
    for (final controller in _dataRateControllers) {
      controller.dispose();
    }
    for (final controller in _deviationControllers) {
      controller.dispose();
    }
    for (final controller in _rawDataControllers) {
      controller.dispose();
    }
    for (final controller in _repeatControllers) {
      controller.dispose();
    }
  }
  
  void _updateSelectedModule(int index) {
    setState(() {
      _selectedModule = index;
    });
  }
  
  void _updateConfig(int moduleIndex, TransmitConfig newConfig) {
    setState(() {
      _transmitConfigs[moduleIndex] = newConfig;
      _configsChanged[moduleIndex] = true;
    });
  }
  
  void _transmitSignal(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    if (!bleProvider.isConnected) {
      _showErrorDialog(AppLocalizations.of(context)!.error, AppLocalizations.of(context)!.deviceNotConnected);
      return;
    }
    
    // Check module availability
    if (!bleProvider.isModuleAvailable(moduleIndex)) {
      final status = bleProvider.getModuleStatus(moduleIndex);
      _showErrorDialog(
        AppLocalizations.of(context)!.moduleBusy, 
        AppLocalizations.of(context)!.moduleBusyTransmitMessage(moduleIndex + 1, status)
      );
      return;
    }
    
    final config = _transmitConfigs[moduleIndex];
    
    // Validate configuration
    final errors = _validateTransmitConfig(config);
    if (errors.isNotEmpty) {
      _showErrorDialog(AppLocalizations.of(context)!.validationError, errors.join('\n'));
      return;
    }
    
     try {
       // Send binary transmission command via Enhanced Protocol
       await bleProvider.sendTransmitCommand(
         frequency: config.frequency,
         data: config.rawData,
         pulseDuration: 100, // TODO: Calculate from config
       );
       
       _showSuccessSnackBar(AppLocalizations.of(context)!.transmissionStartedOnModule(moduleIndex + 1));
     } catch (e) {
       _showErrorDialog(AppLocalizations.of(context)!.transmissionErrorLabel, AppLocalizations.of(context)!.failedToStartTransmission('$e'));
     }
  }
  
  void _transmitFromFile(int moduleIndex) async {
    final bleProvider = Provider.of<BleProvider>(context, listen: false);
    
    if (!bleProvider.isConnected) {
      _showErrorDialog(AppLocalizations.of(context)!.error, AppLocalizations.of(context)!.deviceNotConnected);
      return;
    }
    
    // TODO: Implement file picker
    _showErrorDialog(AppLocalizations.of(context)!.featureInDevelopment, AppLocalizations.of(context)!.fileSelectionLater);
  }
  
  List<String> _validateTransmitConfig(TransmitConfig config) {
    final errors = <String>[];
    
    // Frequency check
    if (!CC1101Values.isValidFrequency(config.frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(config.frequency);
      if (closest != null) {
        errors.add(AppLocalizations.of(context)!.invalidFrequencyClosest(config.frequency.toStringAsFixed(2), closest.toStringAsFixed(2)));
      } else {
        errors.add(AppLocalizations.of(context)!.invalidFrequencySimple(config.frequency.toStringAsFixed(2)));
      }
    }
    
    // Module check
    if (config.module < 0) {
      errors.add(AppLocalizations.of(context)!.invalidModuleNumber(config.module));
    }
    
    // Transmission data check
    if (config.rawData.trim().isEmpty) {
      errors.add(AppLocalizations.of(context)!.rawDataRequired);
    }
    
    // Repeat count check
    if (config.repeatCount < 1 || config.repeatCount > 100) {
      errors.add(AppLocalizations.of(context)!.repeatCountRange);
    }
    
    // Advanced mode parameter check
    if (config.advancedMode) {
      if (config.dataRate != null && !CC1101Values.isValidDataRate(config.dataRate!)) {
        errors.add(AppLocalizations.of(context)!.invalidDataRateValue(config.dataRate!.toStringAsFixed(2)));
      }
      
      if (config.deviation != null && !CC1101Values.isValidDeviation(config.deviation!)) {
        errors.add(AppLocalizations.of(context)!.invalidDeviationValue(config.deviation!.toStringAsFixed(2)));
      }
    }
    
    return errors;
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    notificationProvider.showSuccess(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // Compact TabBar
          Container(
            height: 48, // Compact height
            color: Theme.of(context).colorScheme.inversePrimary,
            child: TabBar(
              controller: _tabController,
              onTap: _updateSelectedModule,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: _transmitConfigs.asMap().entries.map((entry) {
                final index = entry.key;
                return Consumer<BleProvider>(
                  builder: (context, bleProvider, child) {
                    final isAvailable = bleProvider.isModuleAvailable(index);
                    final status = bleProvider.getModuleStatus(index);
                    
                return Tab(
                      icon: Stack(
                        children: [
                          Icon(
                            Icons.send, 
                            size: 18,
                            color: isAvailable ? null : Colors.grey,
                          ),
                          if (!isAvailable)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                  text: AppLocalizations.of(context)!.module(index + 1),
                  iconMargin: const EdgeInsets.only(bottom: 2),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _transmitConfigs.asMap().entries.map((entry) {
                final index = entry.key;
                final config = entry.value;
                
                return _buildModuleTab(index, config);
              }).toList(),
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _buildModuleTab(int moduleIndex, TransmitConfig config) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        final isTransmitting = bleProvider.cc1101Modules?[moduleIndex]['mode'] == 'SendSignal';
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Module status
              _buildModuleStatus(moduleIndex, bleProvider),
              
              const SizedBox(height: 12),
              
              // Transmission settings
              _buildTransmitSettings(moduleIndex, config, isTransmitting),
              
              const SizedBox(height: 12),
              
              // Data for transmission
              _buildTransmitData(moduleIndex, config, isTransmitting),
              
              const SizedBox(height: 12),
              
              // Control buttons
              _buildControlButtons(moduleIndex, isTransmitting),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildModuleStatus(int moduleIndex, BleProvider bleProvider) {
    final module = bleProvider.cc1101Modules?[moduleIndex];
    final mode = module?['mode'] ?? 'Unknown';
    final isConnected = bleProvider.isConnected;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (mode.toLowerCase()) {
      case 'idle':
        statusColor = Colors.green;
        statusIcon = Icons.pause_circle;
        break;
      case 'sendsignal':
        statusColor = Colors.orange;
        statusIcon = Icons.send;
        break;
      case 'detectsignal':
        statusColor = Colors.blue;
        statusIcon = Icons.radar;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.module(moduleIndex + 1),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.statusLabelWithMode(mode),
                    style: TextStyle(color: statusColor),
                  ),
                  Text(
                    AppLocalizations.of(context)!.connectionLabelWithStatus(isConnected ? AppLocalizations.of(context)!.connectionConnected : AppLocalizations.of(context)!.connectionDisconnected),
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTransmitSettings(int moduleIndex, TransmitConfig config, bool isTransmitting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.transmitSettings,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Frequency
            FrequencySelector(
              controller: _frequencyControllers[moduleIndex],
              value: config.frequency,
              onChanged: !isTransmitting ? (value) {
                if (value != null) {
                  _updateConfig(moduleIndex, config.copyWith(frequency: value));
                }
              } : null,
              enabled: !isTransmitting,
            ),
            
            const SizedBox(height: 16),
            
            // Mode (simple/advanced)
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.advancedMode),
              subtitle: Text(config.advancedMode ? AppLocalizations.of(context)!.manualConfiguration : AppLocalizations.of(context)!.usePresets),
              value: config.advancedMode,
              onChanged: isTransmitting ? null : (value) {
                _updateConfig(moduleIndex, config.copyWith(advancedMode: value));
              },
              secondary: Icon(
                config.advancedMode ? Icons.settings : Icons.tune,
                color: config.advancedMode ? Colors.orange : Colors.blue,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Settings depending on mode
            if (config.advancedMode) ...[
              _buildAdvancedSettings(moduleIndex, config, isTransmitting),
            ] else ...[
              _buildSimpleSettings(moduleIndex, config, isTransmitting),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSimpleSettings(int moduleIndex, TransmitConfig config, bool isTransmitting) {
    return PresetSelector(
      value: config.preset,
      onChanged: isTransmitting ? null : (value) {
        if (value != null) {
          _updateConfig(moduleIndex, config.copyWith(preset: value));
        }
      },
    );
  }
  
  Widget _buildAdvancedSettings(int moduleIndex, TransmitConfig config, bool isTransmitting) {
    return Column(
      children: [
        // Bandwidth
        BandwidthSelector(
          controller: TextEditingController(text: config.rxBandwidth?.toStringAsFixed(2) ?? ''),
          value: config.rxBandwidth,
          onChanged: isTransmitting ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(rxBandwidth: value));
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Data rate
        DataRateInputField(
          controller: _dataRateControllers[moduleIndex],
          value: config.dataRate,
          onChanged: isTransmitting ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(dataRate: value));
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Modulation type
        ModulationSelector(
          value: config.modulation,
          onChanged: isTransmitting ? null : (value) {
            if (value != null) {
              _updateConfig(moduleIndex, config.copyWith(modulation: value));
            }
          },
        ),
        
        // Deviation (FM modulation only)
        if (config.modulation == '2-FSK') ...[
          const SizedBox(height: 16),
          DeviationInputField(
            controller: _deviationControllers[moduleIndex],
            value: config.deviation,
            onChanged: isTransmitting ? null : (value) {
              if (value != null) {
                _updateConfig(moduleIndex, config.copyWith(deviation: value));
              }
            },
          ),
        ],
      ],
    );
  }
  
  Widget _buildTransmitData(int moduleIndex, TransmitConfig config, bool isTransmitting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.transmitData,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Raw data
            TextFormField(
              controller: _rawDataControllers[moduleIndex],
              enabled: !isTransmitting,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.rawDataLabel,
                hintText: AppLocalizations.of(context)!.rawDataHint,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
              maxLines: 5,
              onChanged: (value) {
                _updateConfig(moduleIndex, config.copyWith(rawData: value));
              },
            ),
            
            const SizedBox(height: 16),
            
            // Repeat count
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _repeatControllers[moduleIndex],
                    enabled: !isTransmitting,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.repeatCount,
                      hintText: AppLocalizations.of(context)!.repeatCountHint,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final repeat = int.tryParse(value) ?? 1;
                      _updateConfig(moduleIndex, config.copyWith(repeatCount: repeat));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: isTransmitting ? null : () => _transmitFromFile(moduleIndex),
                  icon: const Icon(Icons.file_upload),
                  label: Text(AppLocalizations.of(context)!.loadFile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButtons(int moduleIndex, bool isTransmitting) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isTransmitting ? null : () => _transmitSignal(moduleIndex),
            icon: const Icon(Icons.send),
            label: Text(AppLocalizations.of(context)!.transmitSignal),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.transmitScreenHelp),
        content: SingleChildScrollView(
          child: Text(
            AppLocalizations.of(context)!.transmitScreenHelpContent,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }
}

/// Configuration for signal transmission
class TransmitConfig {
  final double frequency;
  final String? preset;
  final int module;
  final String? modulation;
  final double? bandwidth;
  final double? deviation;
  final double? dataRate;
  final double? rxBandwidth;
  final bool advancedMode;
  final String rawData;
  final int repeatCount;
  
  TransmitConfig({
    required this.frequency,
    this.preset,
    required this.module,
    this.modulation,
    this.bandwidth,
    this.deviation,
    this.dataRate,
    this.rxBandwidth,
    this.advancedMode = false,
    this.rawData = '',
    this.repeatCount = 1,
  });
  
  /// Create copy with modifications
  TransmitConfig copyWith({
    double? frequency,
    String? preset,
    int? module,
    String? modulation,
    double? bandwidth,
    double? deviation,
    double? dataRate,
    double? rxBandwidth,
    bool? advancedMode,
    String? rawData,
    int? repeatCount,
  }) {
    return TransmitConfig(
      frequency: frequency ?? this.frequency,
      preset: preset ?? this.preset,
      module: module ?? this.module,
      modulation: modulation ?? this.modulation,
      bandwidth: bandwidth ?? this.bandwidth,
      deviation: deviation ?? this.deviation,
      dataRate: dataRate ?? this.dataRate,
      rxBandwidth: rxBandwidth ?? this.rxBandwidth,
      advancedMode: advancedMode ?? this.advancedMode,
      rawData: rawData ?? this.rawData,
      repeatCount: repeatCount ?? this.repeatCount,
    );
  }
  
  /// Convert to device parameters
  Map<String, dynamic> toDeviceParams() {
    final params = <String, dynamic>{
      'frequency': frequency,
      'module': module,
      'data': rawData,
      'repeat': repeatCount,
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
    return 'TransmitConfig('
        'frequency: $frequency MHz, '
        'module: $module, '
        'preset: $preset, '
        'modulation: $modulation, '
        'rawData: ${rawData.length} chars, '
        'repeatCount: $repeatCount)';
  }
}
