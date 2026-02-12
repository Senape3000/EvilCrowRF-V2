import 'package:flutter/material.dart';
import '../providers/ble_provider.dart';
import '../models/directory_tree_node.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'directory_tree_widget.dart';

class _DirectoryPickerDialog extends StatefulWidget {
  final String title;
  final BleProvider bleProvider;

  const _DirectoryPickerDialog({
    required this.title,
    required this.bleProvider,
  });

  @override
  State<_DirectoryPickerDialog> createState() => __DirectoryPickerDialogState();
}

class __DirectoryPickerDialogState extends State<_DirectoryPickerDialog> {
  int _selectedPathType = 0;
  List<DirectoryTreeNode> _directories = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _loadDirectoryTree(_selectedPathType);
  }

  Future<void> _loadDirectoryTree(int pathType) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final directories = await widget.bleProvider.getDirectoryTree(pathType: pathType);
      setState(() {
        _directories = directories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onPathTypeChanged(int? pathType) {
    if (pathType != null && pathType != _selectedPathType) {
      setState(() {
        _selectedPathType = pathType;
        _selectedPath = null;
      });
      _loadDirectoryTree(pathType);
    }
  }

  void _onDirectorySelected(String path) {
    setState(() {
      _selectedPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pathTypeNames = {
      0: l10n.records,
      1: l10n.captured,
      2: l10n.presets,
      3: l10n.temp,
    };
    
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.primaryText),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Path type selector
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.storageLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedPathType,
                  items: pathTypeNames.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                    );
                  }).toList(),
                  onChanged: _onPathTypeChanged,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Directory tree
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context)!.errorLoadingDirectories,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.primaryText),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : DirectoryTreeWidget(
                          directories: _directories,
                          onDirectorySelected: _onDirectorySelected,
                          selectedPath: _selectedPath,
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: _selectedPath != null
              ? () => Navigator.of(context).pop({
                    'path': _selectedPath!,
                    'pathType': _selectedPathType,
                  })
              : null,
          child: Text(AppLocalizations.of(context)!.select),
        ),
      ],
    );
  }
}

// Export a function to show the dialog
Future<Map<String, dynamic>?> showDirectoryPickerDialog(BuildContext context, String title, BleProvider bleProvider) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _DirectoryPickerDialog(
      title: title,
      bleProvider: bleProvider,
    ),
  );
}

