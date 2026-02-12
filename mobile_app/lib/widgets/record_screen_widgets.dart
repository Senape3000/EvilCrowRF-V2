import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/cc1101/cc1101_values.dart';
import '../theme/app_colors.dart';

/// Combined frequency selector with validation
class FrequencySelector extends StatefulWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const FrequencySelector({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  String? _errorText;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
      // Check if this frequency is in predefined list
      final freqString = widget.value!.toStringAsFixed(2);
      if (CC1101Values.frequencies.contains(freqString)) {
        _selectedPreset = freqString;
      }
    }
    widget.controller.addListener(_validateFrequency);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateFrequency);
    super.dispose();
  }

  void _validateFrequency() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.frequencyRequired);
      return;
    }

    final frequency = double.tryParse(text);
    if (frequency == null) {
      setState(() => _errorText = AppLocalizations.of(context)!.invalidFrequencyFormat);
      return;
    }

    if (!CC1101Values.isValidFrequency(frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(frequency);
      if (closest != null) {
        setState(() => _errorText = AppLocalizations.of(context)!.invalidFrequencyClosest(frequency.toStringAsFixed(2), closest.toStringAsFixed(2)));
      } else {
        setState(() => _errorText = AppLocalizations.of(context)!.frequencyRangeError);
      }
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(frequency);
  }

  void _onPresetSelected(String? presetValue) {
    if (presetValue != null) {
      final floatValue = CC1101Values.getFrequencyFloat(presetValue);
      if (floatValue != null) {
        widget.controller.text = presetValue;
        widget.onChanged?.call(floatValue);
      }
    }
    setState(() => _selectedPreset = presetValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Frequency input field
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelText: '${AppLocalizations.of(context)!.frequency} (${AppLocalizations.of(context)!.mhz})',
            hintText: '300-348, 387-464, 779-928 ${AppLocalizations.of(context)!.mhz}',
            errorText: _errorText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.radio),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_drop_down),
              onPressed: widget.enabled ? () => _showFrequencyPicker() : null,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: (value) => _validateFrequency(),
        ),
      ],
    );
  }

  void _showFrequencyPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectFrequency),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: CC1101Values.frequencies.length,
            itemBuilder: (context, index) {
              final freq = CC1101Values.frequencies[index];
              final isSelected = _selectedPreset == freq;
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  '$freq ${AppLocalizations.of(context)!.mhz}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                onTap: () {
                  _onPresetSelected(freq);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }
}

/// Frequency input field with validation
class FrequencyInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const FrequencyInputField({
    super.key,
    required this.controller,
    required this.label,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<FrequencyInputField> createState() => _FrequencyInputFieldState();
}

class _FrequencyInputFieldState extends State<FrequencyInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
    }
    widget.controller.addListener(_validateFrequency);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateFrequency);
    super.dispose();
  }

  void _validateFrequency() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = AppLocalizations.of(context)!.frequencyRequired);
      return;
    }

    final frequency = double.tryParse(text);
    if (frequency == null) {
      setState(() => _errorText = AppLocalizations.of(context)!.invalidFrequencyFormat);
      return;
    }

    if (!CC1101Values.isValidFrequency(frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(frequency);
      if (closest != null) {
        setState(() => _errorText = AppLocalizations.of(context)!.invalidFrequencyClosest(frequency.toStringAsFixed(2), closest.toStringAsFixed(2)));
      } else {
        setState(() => _errorText = AppLocalizations.of(context)!.frequencyRangeError);
      }
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(frequency);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '300-348, 387-464, 779-928 MHz',
        errorText: _errorText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.radio),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) => _validateFrequency(),
    );
  }
}

/// Data rate input field with validation
class DataRateInputField extends StatefulWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const DataRateInputField({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<DataRateInputField> createState() => _DataRateInputFieldState();
}

class _DataRateInputFieldState extends State<DataRateInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
    }
    widget.controller.addListener(_validateDataRate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateDataRate);
    super.dispose();
  }

  void _validateDataRate() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged?.call(null);
      return;
    }

    final dataRate = double.tryParse(text);
    if (dataRate == null) {
      setState(() => _errorText = AppLocalizations.of(context)!.invalidDataRateFormat);
      return;
    }

    if (!CC1101Values.isValidDataRate(dataRate)) {
      setState(() => _errorText = AppLocalizations.of(context)!.dataRateRangeError(CC1101Values.dataRateLimits['min'].toString(), CC1101Values.dataRateLimits['max'].toString()));
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(dataRate);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: '${AppLocalizations.of(context)!.dataRate} (${AppLocalizations.of(context)!.kbps})',
        hintText: '${CC1101Values.dataRateLimits['min']}-${CC1101Values.dataRateLimits['max']}',
        errorText: _errorText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.speed),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) => _validateDataRate(),
    );
  }
}

/// Deviation input field with validation
class DeviationInputField extends StatefulWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const DeviationInputField({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<DeviationInputField> createState() => _DeviationInputFieldState();
}

class _DeviationInputFieldState extends State<DeviationInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
    }
    widget.controller.addListener(_validateDeviation);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateDeviation);
    super.dispose();
  }

  void _validateDeviation() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged?.call(null);
      return;
    }

    final deviation = double.tryParse(text);
    if (deviation == null) {
      setState(() => _errorText = AppLocalizations.of(context)!.invalidDeviationFormat);
      return;
    }

    if (!CC1101Values.isValidDeviation(deviation)) {
      setState(() => _errorText = AppLocalizations.of(context)!.deviationRangeError(CC1101Values.deviationLimits['min'].toString(), CC1101Values.deviationLimits['max'].toString()));
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(deviation);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      style: const TextStyle(
        color: AppColors.primaryText,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: '${AppLocalizations.of(context)!.deviation} (${AppLocalizations.of(context)!.khz})',
        hintText: '${CC1101Values.deviationLimits['min']}-${CC1101Values.deviationLimits['max']}',
        errorText: _errorText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.tune),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) => _validateDeviation(),
    );
  }
}

/// Preset selector
class PresetSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const PresetSelector({
    super.key,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.preset,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.settings),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isDense: true,
      items: CC1101Values.presets.map((preset) {
        return DropdownMenuItem<String>(
          value: preset['value'],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
                preset['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
              ),
          ),
        );
      }).toList(),
    );
  }
}

/// Bandwidth selector
class BandwidthSelector extends StatelessWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const BandwidthSelector({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Find current value in list
    String? currentValue;
    if (value != null) {
      final bandwidth = CC1101Values.bandwidths.firstWhere(
        (bw) => double.parse(bw['float']!) == value!,
        orElse: () => {'value': value!.toStringAsFixed(2)},
      );
      currentValue = bandwidth['value'];
    }

    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      onChanged: enabled ? (newValue) {
        if (newValue != null) {
          final floatValue = CC1101Values.getBandwidthFloat(newValue);
          if (floatValue != null) {
            onChanged?.call(floatValue);
          }
        }
      } : null,
      decoration: InputDecoration(
        labelText: '${AppLocalizations.of(context)!.bandwidth} (${AppLocalizations.of(context)!.khz})',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.straighten),
      ),
      items: CC1101Values.bandwidths.map((bandwidth) {
        return DropdownMenuItem<String>(
          value: bandwidth['value'],
          child: Text(
            '${bandwidth['value']} ${AppLocalizations.of(context)!.khz}',
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        );
      }).toList(),
    );
  }
}

/// Modulation type selector
class ModulationSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const ModulationSelector({
    super.key,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.modulation,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.radio),
      ),
      items: CC1101Values.getModulationNames().map((modulation) {
        return DropdownMenuItem<String>(
          value: modulation,
          child: Text(
            _getLocalizedModulationName(context, modulation),
            style: const TextStyle(color: AppColors.secondaryText),
          ),
        );
      }).toList(),
    );
  }
}

/// Widget for displaying preset info
class PresetInfoWidget extends StatelessWidget {
  final String presetValue;

  const PresetInfoWidget({
    super.key,
    required this.presetValue,
  });

  @override
  Widget build(BuildContext context) {
    final preset = CC1101Values.getPresetByValue(presetValue);
    
    if (preset == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.of(context)!.preset}: ${preset['name']}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('${AppLocalizations.of(context)!.modulation}: ${preset['modulation']}'),
            Text('${AppLocalizations.of(context)!.bandwidth}: ${preset['bandwidth']}'),
            Text('${AppLocalizations.of(context)!.dataRate}: ${preset['dataRate']}'),
            if (preset['deviation'] != null)
              Text('${AppLocalizations.of(context)!.deviation}: ${preset['deviation']}'),
          ],
        ),
      ),
    );
  }
}

/// Widget for displaying validation status
class ValidationStatusWidget extends StatelessWidget {
  final List<String> errors;
  final List<String> warnings;

  const ValidationStatusWidget({
    super.key,
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty && warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: errors.isNotEmpty 
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errors.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.errors,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Text(
                  '• $error',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              )),
            ],
            if (warnings.isNotEmpty) ...[
              if (errors.isNotEmpty) const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.warnings,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Text(
                  '• $warning',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Get localized modulation name
String _getLocalizedModulationName(BuildContext context, String modulationName) {
  final l10n = AppLocalizations.of(context)!;
  switch (modulationName) {
    case 'ASK/OOK':
      return l10n.modulationAskOok;
    case '2-FSK':
      return l10n.modulation2Fsk;
    case '4-FSK':
      return l10n.modulation4Fsk;
    case 'GFSK':
      return l10n.modulationGfsk;
    case 'MSK':
      return l10n.modulationMsk;
    default:
      return modulationName;
  }
}
