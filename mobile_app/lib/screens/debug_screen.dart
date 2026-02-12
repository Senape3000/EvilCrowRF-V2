import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/log_provider.dart';
import '../widgets/log_viewer_widget.dart';
import '../l10n/app_localizations.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final TextEditingController _commandController = TextEditingController();

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Compact header
          Container(
            height: 48, // Compact height
            color: Theme.of(context).colorScheme.inversePrimary,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.bug_report, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.debug,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Consumer<LogProvider>(
                  builder: (context, logProvider, child) {
                    return IconButton(
                      onPressed: () => logProvider.clearLogs(),
                      icon: const Icon(Icons.clear_all),
                      tooltip: AppLocalizations.of(context)!.clearAllLogs,
                    );
                  },
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Consumer<BleProvider>(
              builder: (context, bleProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              bleProvider.isConnected 
                                ? Icons.bluetooth_connected 
                                : Icons.bluetooth_disabled,
                              color: bleProvider.isConnected ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.connectionStatus,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bleProvider.statusMessage,
                          style: TextStyle(
                            color: _getStatusColor(bleProvider.statusMessage),
                          ),
                        ),
                        if (bleProvider.isConnected) ...[
                          const SizedBox(height: 8),
                          Text(AppLocalizations.of(context)!.deviceLabel(bleProvider.savedDeviceName ?? 'Unknown')),
                          Text(AppLocalizations.of(context)!.deviceIdLabel(bleProvider.savedDeviceId ?? 'Unknown')),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Command Input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.sendCommand,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commandController,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!.enterCommand,
                                  border: const OutlineInputBorder(),
                                  hintText: AppLocalizations.of(context)!.commandHint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles ? () {
                                if (_commandController.text.isNotEmpty) {
                                  bleProvider.sendCommand(_commandController.text);
                                  _commandController.clear();
                                }
                              } : null,
                              child: bleProvider.isLoadingFiles 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(AppLocalizations.of(context)!.send),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Debug Controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.debugControls,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Connection Controls
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: bleProvider.isConnected 
                                ? () => bleProvider.disconnect()
                                : null,
                              icon: const Icon(Icons.bluetooth_disabled),
                              label: Text(AppLocalizations.of(context)!.disconnect),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => bleProvider.clearKnownDevice(),
                              icon: const Icon(Icons.clear_all),
                              label: Text(AppLocalizations.of(context)!.clearCachedDevice),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => bleProvider.clearFileCache(),
                              icon: const Icon(Icons.folder_delete),
                              label: Text(AppLocalizations.of(context)!.clearFileCache),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => bleProvider.requestPermissions(),
                              icon: const Icon(Icons.security),
                              label: Text(AppLocalizations.of(context)!.requestPermissions),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Test Commands
                        Text(
                          AppLocalizations.of(context)!.testCommands,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles
                                ? () => bleProvider.sendCommand('SCAN')
                                : null,
                              child: const Text('SCAN'),
                            ),
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles
                                ? () => bleProvider.sendCommand('RECORD')
                                : null,
                              child: const Text('RECORD'),
                            ),
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles
                                ? () => bleProvider.sendCommand('PLAY')
                                : null,
                              child: const Text('PLAY'),
                            ),
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles
                                ? () => bleProvider.sendCommand('STOP')
                                : null,
                              child: const Text('STOP'),
                            ),
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles
                                ? () => bleProvider.sendCommand('REBOOT')
                                : null,
                              child: Text(AppLocalizations.of(context)!.rebootDevice),
                            ),
                            ElevatedButton(
                              onPressed: bleProvider.isConnected && !bleProvider.isLoadingFiles
                                ? () => bleProvider.refreshFileList()
                                : null,
                              child: bleProvider.isLoadingFiles 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(AppLocalizations.of(context)!.refreshFiles),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Logs Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.activityLogs,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(
                          height: 300,
                          child: LogViewerWidget(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('permissions denied') || 
        status.contains('not granted') ||
        status.contains('error')) {
      return Colors.red;
    }
    if (status.contains('Connected')) return Colors.green;
    if (status.contains('Scanning') || status.contains('Connecting')) return Colors.blue;
    return Colors.grey[600]!;
  }
}
