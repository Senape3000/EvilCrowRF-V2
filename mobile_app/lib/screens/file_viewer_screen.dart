import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/notification_provider.dart';
import '../services/file_parsers/file_parser_factory.dart';
import '../services/file_parsers/base_file_parser.dart';
import '../services/signal_processing/signal_data.dart';
import '../widgets/transmit_file_dialog.dart';
import '../theme/app_colors.dart';

class FileViewerScreen extends StatefulWidget {
  final dynamic fileItem;
  final String filePath;
  final int pathType;  // 0=RECORDS, 1=SIGNALS, 2=PRESETS, 3=TEMP

  const FileViewerScreen({
    super.key,
    required this.fileItem,
    required this.filePath,
    this.pathType = 0,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen>
    with TickerProviderStateMixin {
  String? fileContent;
  bool isLoading = false;
  String? errorMessage;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  
  // Parse data
  FileParseResult? parseResult;
  bool hasParser = false;
  String? fileExtension;
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    
    // Determine file extension
    fileExtension = widget.fileItem.name.split('.').last.toLowerCase();
    
    // Initial tab count (Raw always present)
    _tabController = TabController(length: 1, vsync: this);
    
    // Defer file loading until build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadFileContent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFileContent() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
      fileContent = null;
    });

    try {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      
      // Log file path for debugging
      
      // Use filePath as-is and let readFileContent handle path construction
      // based on pathType (0-3=relative, 4-5=absolute)
      String filePath = widget.filePath;
      
      print('Loading file: path="$filePath", pathType=${widget.pathType}');
      
      // Read file from ESP (pathType determines how path is interpreted)
      final content = await bleProvider.readFileContent(filePath, pathType: widget.pathType);
      
      if (mounted) {
        // Check if response is an error from ESP
        if (content.startsWith('{"type":"error"')) {
          try {
            final errorData = jsonDecode(content);
            setState(() {
              errorMessage = '${errorData['error']}: ${errorData['details']}';
              isLoading = false;
            });
            return;
          } catch (e) {
            // If JSON parsing failed, show as-is
          }
        }
        
        // Parse file if a suitable parser exists
        _parseFileContent(content);
        
        setState(() {
          fileContent = content;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void _parseFileContent(String content) {
    try {
      // Try to find a suitable parser
      parseResult = FileParserFactory.parseFile(content, filename: widget.fileItem.name);
      hasParser = parseResult?.success ?? false;
      
      // Update tab count
      final tabCount = hasParser ? 2 : 1; // Parsed + Raw or Raw only
      if (_tabController.length != tabCount) {
        _tabController.dispose();
        _tabController = TabController(length: tabCount, vsync: this);
      }
    } catch (e) {
      hasParser = false;
      parseResult = null;
    }
  }

  Future<void> _downloadFile() async {
    if (!mounted) return;
    
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      
      // Load file from ESP
      final content = await bleProvider.downloadFile(
        widget.filePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              downloadProgress = progress;
            });
          }
        },
      );
      
      if (mounted && content != null) {
        // Check if response is an error from ESP
        if (content.startsWith('{"type":"error"')) {
          try {
            final errorData = jsonDecode(content);
            throw Exception('${errorData['error']}: ${errorData['details']}');
          } catch (e) {
            // If JSON parsing failed, use as-is
            throw Exception(content);
          }
        }
        
        // Save file to device
        await _saveFileToDevice(content);
        
        setState(() {
          isDownloading = false;
          downloadProgress = 0.0;
        });
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showSuccess(AppLocalizations.of(context)!.fileDownloadedSuccessfully(widget.fileItem.name));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
          downloadProgress = 0.0;
        });
        
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.showError(AppLocalizations.of(context)!.downloadFailed(e.toString()));
      }
    }
  }

  Future<void> _saveFileToDevice(String content) async {
    try {
      // Convert string to bytes for saving
      final bytes = Uint8List.fromList(utf8.encode(content));
      print('_saveFileToDevice: Starting save process for file: ${widget.fileItem.name}, size: ${bytes.length} bytes');
      
      // On Android and iOS FilePicker.saveFile requires byte data
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.of(context)!.saveFileAs,
        fileName: widget.fileItem.name,
        bytes: bytes, // Pass bytes for Android/iOS
        allowedExtensions: null, // Allow any file type
      );
      
      if (outputFile != null && outputFile.isNotEmpty) {
        print('_saveFileToDevice: File saved successfully to: $outputFile');
        
        // Verify file actually exists
        final file = File(outputFile);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('_saveFileToDevice: File verified, size: $fileSize bytes');
          
          if (mounted) {
            final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
            notificationProvider.showSuccess(AppLocalizations.of(context)!.fileSaved(outputFile));
          }
        } else {
          // On some platforms FilePicker saves the file itself, verify with small delay
          await Future.delayed(const Duration(milliseconds: 100));
          if (await file.exists()) {
            if (mounted) {
              final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
              notificationProvider.showSuccess(AppLocalizations.of(context)!.fileSaved(outputFile));
            }
          } else {
            throw Exception('File was not created at path: $outputFile');
          }
        }
      } else {
        print('_saveFileToDevice: User cancelled save dialog, copying to clipboard');
        // If user cancelled save, copy to clipboard
        await Clipboard.setData(ClipboardData(text: content));
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showInfo(AppLocalizations.of(context)!.fileContentCopiedToClipboard);
        }
      }
    } catch (e) {
      print('_saveFileToDevice: Error during save: $e');
      // On error save to Downloads folder as fallback (user-accessible)
      try {
        print('_saveFileToDevice: Trying fallback to Downloads directory');
        final downloadsDir = await _getDownloadsDirectory();
        final fileName = widget.fileItem.name;
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsString(content);
        
        // Verify file was actually saved
        if (await file.exists()) {
          final fileSize = await file.length();
          print('_saveFileToDevice: File saved to Downloads, size: $fileSize bytes');
          
          if (mounted) {
            final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
            notificationProvider.showWarning(AppLocalizations.of(context)!.fileSavedToDocuments(file.path));
          }
        } else {
          throw Exception('File was written but does not exist');
        }
      } catch (e2) {
        print('_saveFileToDevice: Fallback also failed: $e2');
        // Last resort - copy to clipboard
        await Clipboard.setData(ClipboardData(text: content));
        
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          notificationProvider.showError(AppLocalizations.of(context)!.couldNotSaveFile(e.toString()));
        }
      }
    }
  }

  /// Get the public Downloads directory on Android, or Documents as fallback.
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // On Android, use the public Downloads directory
      final downloadsPath = '/storage/emulated/0/Download';
      final dir = Directory(downloadsPath);
      if (await dir.exists()) {
        return dir;
      }
    }
    // Fallback: try path_provider's downloads directory
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir;
    // Ultimate fallback: app Documents directory
    return await getApplicationDocumentsDirectory();
  }

  String _getFileExtension() {
    final fileName = widget.fileItem.name;
    final lastDot = fileName.lastIndexOf('.');
    return lastDot != -1 ? fileName.substring(lastDot + 1).toLowerCase() : '';
  }

  bool _isTransmittableFile() {
    final extension = _getFileExtension();
    return extension == 'sub';
  }

  Future<void> _transmitSignal() async {
    if (!mounted) return;
    
    await TransmitFileDialog.showAndTransmit(
      context,
      fileName: widget.fileItem.name,
      filePath: widget.filePath,
      pathType: widget.pathType,
    );
  }

  Widget _buildHexView(String content) {
    final bytes = content.codeUnits;
    final hexLines = <String>[];
    
    for (int i = 0; i < bytes.length; i += 16) {
      final lineBytes = bytes.skip(i).take(16).toList();
      final hexPart = lineBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      final asciiPart = lineBytes
          .map((b) => b >= 32 && b <= 126 ? String.fromCharCode(b) : '.')
          .join('');
      
      hexLines.add('${i.toRadixString(16).padLeft(8, '0')}: $hexPart | $asciiPart');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hexLines.length,
      itemBuilder: (context, index) {
        return SelectableText(
          hexLines[index],
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        );
      },
    );
  }

  Widget _buildJsonView(String content) {
    try {
      final jsonData = jsonDecode(content);
      final formattedJson = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          formattedJson,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      );
    } catch (e) {
      return _buildTextView(content);
    }
  }

  Widget _buildTextView(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildImageView(String content) {
    // TODO: Implement image preview for supported formats
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported,
            size: 64,
            color: AppColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.imagePreviewNotSupported,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(0), // Switch to text view
            child: Text(AppLocalizations.of(context)!.viewAsText),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedTab() {
    if (parseResult == null || !parseResult!.success) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.failedToParseFile,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            if (parseResult?.errors.isNotEmpty == true)
            Text(
                parseResult!.errors.first,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final signalData = parseResult!.signalData!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main signal parameters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.signalParameters,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (signalData.frequency != null)
                    _buildInfoRow(AppLocalizations.of(context)!.frequency, '${signalData.frequency!.toStringAsFixed(2)} MHz'),
                  if (signalData.modulation != null)
                    _buildInfoRow(AppLocalizations.of(context)!.modulation, signalData.modulation!),
                  if (signalData.dataRate != null)
                    _buildInfoRow(AppLocalizations.of(context)!.dataRate, '${signalData.dataRate!.toStringAsFixed(1)} kBaud'),
                  if (signalData.deviation != null)
                    _buildInfoRow(AppLocalizations.of(context)!.deviation, '±${signalData.deviation!.toStringAsFixed(1)} kHz'),
                  if (signalData.rxBandwidth != null)
                    _buildInfoRow(AppLocalizations.of(context)!.rxBandwidth, '${signalData.rxBandwidth!.toStringAsFixed(1)} kHz'),
                  if (signalData.protocol != null)
                    _buildInfoRow(AppLocalizations.of(context)!.protocol, signalData.protocol!),
                  if (signalData.preset != null)
                    _buildInfoRow(AppLocalizations.of(context)!.preset, signalData.preset!),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Signal data
          if (signalData.raw != null || signalData.binary != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.signalData,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (signalData.samplesCount != null)
                      _buildInfoRow(AppLocalizations.of(context)!.samplesCount, signalData.samplesCount!.toString()),
                    if (signalData.raw != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.rawData,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          signalData.raw!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    if (signalData.binary != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.binaryData,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          signalData.binary!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Warnings
          if (parseResult!.warnings.isNotEmpty) ...[
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.warnings,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...parseResult!.warnings.map((warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $warning',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexTab() {
    if (fileContent == null) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noContentAvailable),
      );
    }
    
    return _buildHexView(fileContent!);
  }

  Widget _buildRawTab() {
    if (fileContent == null) {
      if (errorMessage != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.secondaryText),
              const SizedBox(height: 16),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFileContent,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.reload),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 48, color: AppColors.secondaryText),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noContentAvailable),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFileContent,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.reload),
            ),
          ],
        ),
      );
    }
    
    return _buildTextView(fileContent!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48, // Compact toolbar
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Show full filename in dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        AppLocalizations.of(context)!.file,
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                      content: SelectableText(
                        widget.fileItem.name,
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context)!.ok),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  widget.fileItem.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (!isLoading && fileContent != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                iconColor: Theme.of(context).colorScheme.onPrimary,
                onSelected: (value) async {
                  switch (value) {
                    case 'copy':
                      await Clipboard.setData(ClipboardData(text: fileContent!));
                      if (mounted) {
                        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
                        notificationProvider.showInfo(AppLocalizations.of(context)!.fileContentCopiedToClipboard);
                      }
                      break;
                    case 'download':
                      if (!isDownloading) {
                        await _downloadFile();
                      }
                      break;
                    case 'transmit':
                      if (!isLoading && _isTransmittableFile()) {
                        await _transmitSignal();
                      }
                      break;
                    case 'reload':
                      await _loadFileContent();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20, color: Theme.of(context).iconTheme.color),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.copyToClipboard),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'download',
                    enabled: !isDownloading,
                    child: Row(
                      children: [
                        isDownloading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Icon(Icons.download, size: 20, color: Theme.of(context).iconTheme.color),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.downloadFile),
                      ],
                    ),
                  ),
                  if (_isTransmittableFile())
                    PopupMenuItem<String>(
                      value: 'transmit',
                      enabled: !isLoading,
                      child: Row(
                        children: [
                          Icon(Icons.send, size: 20, color: Theme.of(context).iconTheme.color),
                          const SizedBox(width: 12),
                          Text(AppLocalizations.of(context)!.transmitSignal),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'reload',
                    enabled: !isLoading,
                    child: Row(
                      children: [
                        isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Icon(Icons.refresh, size: 20, color: Theme.of(context).iconTheme.color),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.reload),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: isDownloading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: downloadProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              )
            : !isLoading && fileContent != null
                ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Theme.of(context).colorScheme.onPrimary,
                  labelColor: Theme.of(context).colorScheme.onPrimary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                  labelStyle: const TextStyle(fontSize: 13),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: hasParser ? [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.analytics, size: 16),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context)!.parsed),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code, size: 16),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context)!.raw),
                        ],
                      ),
                    ),
                  ] : [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code, size: 16),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context)!.raw),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                : null,
      ),
      body: Consumer<BleProvider>(
        builder: (context, bleProvider, _) {
          // Show loading indicator if file is being loaded
          if (isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.loadingFile),
                  const SizedBox(height: 8),
                  if (bleProvider.fileContentProgress > 0)
                    Text(
                      '${(bleProvider.fileContentProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (bleProvider.fileContentProgress > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      child: LinearProgressIndicator(
                        value: bleProvider.fileContentProgress,
                      ),
                    ),
                ],
              ),
            );
          }
          
          if (!bleProvider.isConnected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.notConnectedToDeviceFile,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.connectToDeviceToViewFiles,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: hasParser ? [
              _buildParsedTab(),
              _buildRawTab(),
            ] : [
              _buildRawTab(),
            ],
          );
        },
      ),
    );
  }
}
