// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tut RF';

  @override
  String get home => 'Home';

  @override
  String get brute => 'Brute';

  @override
  String get record => 'Record';

  @override
  String get files => 'Files';

  @override
  String get settings => 'Settings';

  @override
  String get connectionRequired => 'Connection Required';

  @override
  String get connectionRequiredMessage =>
      'Please connect to a device first to access this feature.';

  @override
  String get ok => 'OK';

  @override
  String get permissionError => 'Permission Error';

  @override
  String get disconnected => 'Disconnected';

  @override
  String connected(String deviceName) {
    return 'Connected to $deviceName';
  }

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectingToKnownDevice => 'Connecting to known device...';

  @override
  String get scanningForDevice => 'Scanning for device...';

  @override
  String get deviceNotFound =>
      'Device not found. Make sure it\'s powered on and nearby.';

  @override
  String connectionError(String error) {
    return 'Connection error: $error';
  }

  @override
  String get bluetoothEnabled => 'Bluetooth enabled';

  @override
  String get bluetoothDisabled => 'Bluetooth disabled';

  @override
  String get somePermissionsDenied =>
      'Some permissions denied. Bluetooth may not work properly.';

  @override
  String get allPermissionsGranted =>
      'All permissions granted. Bluetooth ready.';

  @override
  String get bluetoothScanPermissionsNotGranted =>
      'Bluetooth scan permissions not granted';

  @override
  String get scanningForDevices => 'Scanning for devices...';

  @override
  String foundSupportedDevices(int count) {
    return 'Found $count supported device(s). Tap to connect.';
  }

  @override
  String get noSupportedDevicesFound =>
      'No supported devices found. Make sure ESP32 is powered on and nearby.';

  @override
  String scanError(String error) {
    return 'Scan error: $error';
  }

  @override
  String get scanStopped => 'Scan stopped';

  @override
  String stopScanError(String error) {
    return 'Stop scan error: $error';
  }

  @override
  String get requiredCharacteristicsNotFound =>
      'Required characteristics not found';

  @override
  String get requiredServiceNotFound => 'Required service not found';

  @override
  String get knownDeviceCleared =>
      'Known device cleared. Next connection will scan for devices.';

  @override
  String get notConnected => 'Not connected';

  @override
  String sendError(String error) {
    return 'Send error: $error';
  }

  @override
  String get commandTimeout => 'Command timeout - please try again';

  @override
  String get fileListLoadingTimeout =>
      'File list loading timeout - please try again';

  @override
  String get transmittingSignal => 'Transmitting signal...';

  @override
  String transmissionFailed(String error) {
    return 'Transmission failed: $error';
  }

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connect => 'Connect';

  @override
  String get scanForNewDevices => 'Scan for New Devices';

  @override
  String get scanForDevices => 'Scan for Devices';

  @override
  String get scanAgain => 'Scan Again';

  @override
  String foundSupportedDevicesCount(int count) {
    return 'Found $count supported device(s):';
  }

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get notConnectedToDevice => 'Not connected to device';

  @override
  String get connectToDeviceToManageFiles =>
      'Connect to a device to manage files';

  @override
  String get refresh => 'Refresh';

  @override
  String get stopLoading => 'Stop Loading';

  @override
  String get createDirectory => 'Create Directory';

  @override
  String get uploadFile => 'Upload File';

  @override
  String get exitMultiSelect => 'Exit Multi-Select';

  @override
  String get multiSelect => 'Multi-Select';

  @override
  String get directoryName => 'Directory name';

  @override
  String get enterDirectoryName => 'Enter directory name';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get copyFile => 'Copy File';

  @override
  String get newFileName => 'New file name';

  @override
  String destination(String path) {
    return 'Destination: $path';
  }

  @override
  String get copy => 'Copy';

  @override
  String get renameDirectory => 'Rename Directory';

  @override
  String get renameFile => 'Rename File';

  @override
  String get newDirectoryName => 'New directory name';

  @override
  String get rename => 'Rename';

  @override
  String get deleteDirectory => 'Delete Directory';

  @override
  String get deleteFile => 'Delete File';

  @override
  String deleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get deleteFiles => 'Delete Files';

  @override
  String deleteFilesConfirm(int count) {
    return 'Are you sure you want to delete $count files?';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clearSelection => 'Clear Selection';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get moveDirectory => 'Move Directory';

  @override
  String get moveFile => 'Move File';

  @override
  String get move => 'Move';

  @override
  String get records => 'Records';

  @override
  String get signals => 'Signals';

  @override
  String get captured => 'Captured';

  @override
  String get presets => 'Presets';

  @override
  String get temp => 'Temp';

  @override
  String get saveFileAs => 'Save file as...';

  @override
  String fileSaved(String path) {
    return 'File saved to: $path';
  }

  @override
  String get fileContentCopiedToClipboard => 'File content copied to clipboard';

  @override
  String fileSavedToDocuments(String path) {
    return 'File saved to Documents: $path';
  }

  @override
  String couldNotSaveFile(String error) {
    return 'Could not save file. Content copied to clipboard. Error: $error';
  }

  @override
  String downloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get downloadFailedNoContent => 'Download failed: No content received';

  @override
  String fileCopied(String name) {
    return 'File copied: $name';
  }

  @override
  String copyFailed(String error) {
    return 'Copy failed: $error';
  }

  @override
  String directoryRenamed(String name) {
    return 'Directory renamed to: $name';
  }

  @override
  String fileRenamed(String name) {
    return 'File renamed to: $name';
  }

  @override
  String renameFailed(String error) {
    return 'Rename failed: $error';
  }

  @override
  String directoryDeleted(String name) {
    return 'Directory deleted: $name';
  }

  @override
  String fileDeleted(String name) {
    return 'File deleted: $name';
  }

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String deletedFilesCount(int count, String extra) {
    return 'Deleted $count files$extra';
  }

  @override
  String get failed => 'failed';

  @override
  String directoryMoved(String name) {
    return 'Directory moved: $name';
  }

  @override
  String fileMoved(String name) {
    return 'File moved: $name';
  }

  @override
  String moveFailed(String error) {
    return 'Move failed: $error';
  }

  @override
  String directoryCreated(String name) {
    return 'Directory created: $name';
  }

  @override
  String failedToCreateDirectory(String error) {
    return 'Failed to create directory: $error';
  }

  @override
  String uploadingFile(String fileName) {
    return 'Uploading $fileName...';
  }

  @override
  String fileUploaded(String fileName) {
    return 'File uploaded: $fileName';
  }

  @override
  String uploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get selectedFileDoesNotExist => 'Selected file does not exist';

  @override
  String get uploadError => 'Upload Error';

  @override
  String failedToPickFile(String error) {
    return 'Failed to pick file: $error';
  }

  @override
  String get noLogsYet => 'No logs yet';

  @override
  String get commandsAndResponsesWillAppearHere =>
      'Commands and responses will appear here';

  @override
  String logsCount(int count) {
    return 'Logs ($count)';
  }

  @override
  String get clearAllLogs => 'Clear all logs';

  @override
  String get loadingFilePreview => 'Loading file preview...';

  @override
  String get previewError => 'Preview Error';

  @override
  String get retry => 'Retry';

  @override
  String chars(int count) {
    return '$count chars';
  }

  @override
  String get previewTruncated =>
      'Preview truncated. Open file to see full content.';

  @override
  String get clearFileCache => 'Clear File Cache';

  @override
  String get rebootDevice => 'Reboot Device';

  @override
  String get requestPermissions => 'Request Permissions';

  @override
  String get sendCommand => 'Send Command';

  @override
  String get enterCommand => 'Enter Command';

  @override
  String get commandHint => 'e.g., SCAN, RECORD, PLAY';

  @override
  String get send => 'Send';

  @override
  String get scanner => 'Scanner';

  @override
  String get clearList => 'Clear list';

  @override
  String get stop => 'Stop';

  @override
  String get start => 'Start';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get russian => 'Russian';

  @override
  String get systemDefault => 'System Default';

  @override
  String get deviceStatus => 'Device Status';

  @override
  String subGhzModule(int number) {
    return 'Sub-GHz Module $number';
  }

  @override
  String connectedToDevice(String deviceName) {
    return 'Connected: $deviceName';
  }

  @override
  String get sdCardReady => 'SD Card ready';

  @override
  String freeHeap(String kb) {
    return 'Free Heap';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get clearAll => 'Clear All';

  @override
  String get justNow => 'Just now';

  @override
  String get minutesAgo => 'm ago';

  @override
  String get hoursAgo => 'h ago';

  @override
  String get daysAgo => 'd ago';

  @override
  String get frequency => 'Frequency';

  @override
  String get modulation => 'Modulation';

  @override
  String get dataRate => 'Data Rate';

  @override
  String get bandwidth => 'Bandwidth';

  @override
  String get deviation => 'Deviation';

  @override
  String get rxBandwidth => 'RX Bandwidth';

  @override
  String get protocol => 'Protocol';

  @override
  String get preset => 'Preset';

  @override
  String get signalName => 'Signal Name';

  @override
  String get settingsParseError => 'Settings Parse Error';

  @override
  String get unknown => 'Unknown';

  @override
  String get idle => 'Idle';

  @override
  String get detecting => 'Detecting';

  @override
  String get recording => 'Recording';

  @override
  String get jamming => 'Jamming';

  @override
  String get jammingSettings => 'Jamming Settings';

  @override
  String get transmitting => 'Transmitting';

  @override
  String get scanning => 'Scanning';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusRecording => 'Recording';

  @override
  String get statusScanning => 'Scanning';

  @override
  String get statusTransmitting => 'Transmitting';

  @override
  String get kbps => 'kbps';

  @override
  String get hz => 'Hz';

  @override
  String get modulationAskOok => 'ASK/OOK';

  @override
  String get modulation2Fsk => '2-FSK';

  @override
  String get modulation4Fsk => '4-FSK';

  @override
  String get modulationGfsk => 'GFSK';

  @override
  String get modulationMsk => 'MSK';

  @override
  String get startRecordingToCaptureSignals =>
      'Start recording to capture signals';

  @override
  String frequencySearchStoppedForModule(int number) {
    return 'Frequency search stopped for Module $number';
  }

  @override
  String get error => 'Error';

  @override
  String get deviceNotConnected => 'Device not connected';

  @override
  String get moduleBusy => 'Module Busy';

  @override
  String moduleBusyMessage(int number, String mode) {
    return 'Module $number is currently in \"$mode\" mode.\\nWait for the current operation to complete or switch the module to Idle mode.';
  }

  @override
  String get validationError => 'Validation Error';

  @override
  String recordingStarted(int number) {
    return 'Recording started on module $number';
  }

  @override
  String get recordingError => 'Recording Error';

  @override
  String recordingStartFailed(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String recordingStopped(int number) {
    return 'Recording stopped on module $number';
  }

  @override
  String recordingStopFailed(String error) {
    return 'Failed to stop recording: $error';
  }

  @override
  String module(int number) {
    return 'Module $number';
  }

  @override
  String get startRecording => 'Start Recording';

  @override
  String get stopRecording => 'Stop Recording';

  @override
  String get advanced => 'Advanced';

  @override
  String get startJamming => 'Start Jamming';

  @override
  String get stopJamming => 'Stop Jamming';

  @override
  String jammingStarted(int module) {
    return 'Jamming started on Module $module';
  }

  @override
  String jammingStopped(int module) {
    return 'Jamming stopped on Module $module';
  }

  @override
  String get jammingError => 'Jamming Error';

  @override
  String jammingStartFailed(String error) {
    return 'Failed to start jamming: $error';
  }

  @override
  String jammingStopFailed(String error) {
    return 'Failed to stop jamming: $error';
  }

  @override
  String get stopFrequencySearch => 'Stop frequency search';

  @override
  String get searchForFrequency => 'Search for frequency';

  @override
  String signalsCaptured(Object count, Object number) {
    return 'Module $number Signals Captured ($count)';
  }

  @override
  String get recordedFiles => 'Recorded Files';

  @override
  String get saveSignal => 'Save Signal';

  @override
  String get enterSignalName => 'Enter a name for the signal:';

  @override
  String get deleteSignal => 'Delete Signal';

  @override
  String deleteSignalConfirm(String filename) {
    return 'Are you sure you want to delete \"$filename\"?\\n\\nThis action cannot be undone.';
  }

  @override
  String get recordScreenHelp => 'Record Screen Help';

  @override
  String fileDownloadedSuccessfully(String fileName) {
    return 'File \"$fileName\" downloaded successfully';
  }

  @override
  String get imagePreviewNotSupported => 'Image preview not supported yet';

  @override
  String get viewAsText => 'View as Text';

  @override
  String get failedToParseFile => 'Failed to parse file';

  @override
  String get signalParameters => 'Signal Parameters';

  @override
  String get signalData => 'Signal Data';

  @override
  String get samplesCount => 'Samples Count';

  @override
  String get rawData => 'Raw Data:';

  @override
  String get binaryData => 'Binary Data:';

  @override
  String get warnings => 'Warnings';

  @override
  String get noContentAvailable => 'No content available';

  @override
  String get copyToClipboard => 'Copy to Clipboard';

  @override
  String get downloadFile => 'Download File';

  @override
  String get transmitSignal => 'Transmit Signal';

  @override
  String get reload => 'Reload';

  @override
  String get parsed => 'Parsed';

  @override
  String get raw => 'Raw';

  @override
  String get loadingFile => 'Loading file...';

  @override
  String get notConnectedToDeviceFile => 'Not connected to device';

  @override
  String get connectToDeviceToViewFiles => 'Connect to a device to view files';

  @override
  String get transmitSignalConfirm =>
      'This will transmit the signal from this file.';

  @override
  String get file => 'File';

  @override
  String get transmitWarning =>
      'Only use in controlled environments. Check local regulations.';

  @override
  String get dontShowAgain => 'Don\'t show this again';

  @override
  String get resetTransmitConfirmation => 'Reset Transmit Confirmation';

  @override
  String get transmitConfirmationReset =>
      'Transmit confirmation dialog has been reset.';

  @override
  String get transmit => 'Transmit';

  @override
  String signalTransmissionStarted(String fileName) {
    return 'Signal transmission started: $fileName';
  }

  @override
  String transmissionError(String error) {
    return 'Transmission error: $error';
  }

  @override
  String get view => 'View';

  @override
  String get save => 'Save';

  @override
  String get loadingFiles => 'Loading...';

  @override
  String get noRecordedFiles => 'No recorded files';

  @override
  String get noFilesFound => 'No files found';

  @override
  String get recordSettings => 'Record Settings';

  @override
  String get mhz => 'MHz';

  @override
  String get khz => 'kHz';

  @override
  String get kbaud => 'kBaud';

  @override
  String signalSavedAs(String fileName) {
    return 'Signal saved as: $fileName';
  }

  @override
  String transmittingFile(String fileName) {
    return 'Transmitting file: $fileName';
  }

  @override
  String get recordingShort => 'Recording';

  @override
  String get freqShort => 'Freq';

  @override
  String get modShort => 'Mod';

  @override
  String get rateShort => 'Rate';

  @override
  String get bwShort => 'BW';

  @override
  String get clearDeviceCache => 'Clear Device Cache';

  @override
  String get clearDeviceCacheDescription => 'Remove saved device information';

  @override
  String filesLoadedCount(int loaded, int total) {
    return 'Files loaded: $loaded of $total';
  }

  @override
  String filesInDirectory(int count) {
    return 'Files in directory: $count';
  }

  @override
  String get noFiles => 'No files';

  @override
  String get searchProtocols => 'Search protocols...';

  @override
  String get attackMode => 'Attack Mode:';

  @override
  String get standardMode => 'Standard';

  @override
  String get deBruijnMode => 'DeBruijn';

  @override
  String get noProtocolsFound => 'No protocols found';

  @override
  String pausedProtocol(String name) {
    return 'Paused: $name';
  }

  @override
  String bruteForceRunning(String name) {
    return 'Brute Force Running: $name';
  }

  @override
  String get bruteResume => 'RESUME';

  @override
  String get brutePause => 'PAUSE';

  @override
  String get bruteStop => 'STOP';

  @override
  String get resumeInfo =>
      'Resume will re-transmit 5 codes before the pause point.';

  @override
  String get startBruteForce => 'Start Brute Force';

  @override
  String startBruteForceSuffix(String suffix) {
    return 'Start Brute Force$suffix';
  }

  @override
  String get keySpace => 'Key Space';

  @override
  String get delay => 'Delay';

  @override
  String get estTime => 'Est. Time';

  @override
  String largeKeyspaceWarning(int bits, String time) {
    return '$bits-bit keyspace is very large. Full scan may take $time.';
  }

  @override
  String get deviceWillTransmit =>
      'The device will start transmitting. You can stop at any time.';

  @override
  String bruteForceStarted(String name) {
    return 'Brute force started: $name';
  }

  @override
  String failedToStart(String error) {
    return 'Failed to start: $error';
  }

  @override
  String get bruteForcePausing => 'Brute force pausing...';

  @override
  String failedToPause(String error) {
    return 'Failed to pause: $error';
  }

  @override
  String get bruteForceResumed => 'Brute force resumed';

  @override
  String failedToResume(String error) {
    return 'Failed to resume: $error';
  }

  @override
  String get savedStateDiscarded => 'Saved bruter state discarded';

  @override
  String failedToDiscard(String error) {
    return 'Failed to discard state: $error';
  }

  @override
  String get bruteForceStopped => 'Brute force stopped';

  @override
  String failedToStop(String error) {
    return 'Failed to stop: $error';
  }

  @override
  String bruteForceCompleted(String name) {
    return 'Brute force completed: $name';
  }

  @override
  String bruteForceCancelled(String name) {
    return 'Brute force cancelled: $name';
  }

  @override
  String bruteForceErrorMsg(String name) {
    return 'Brute force error: $name';
  }

  @override
  String get deBruijnCompatible => 'DeBruijn ✓';

  @override
  String get deBruijnTooltip =>
      'DeBruijn sequences cover all n-bit combinations in one continuous bitstream — ~90x faster';

  @override
  String get deBruijnFaster => 'DeBruijn (~90x faster)';

  @override
  String get modeLabel => 'Mode';

  @override
  String get moduleLabel => 'Module:';

  @override
  String get cc1101Module1 => 'CC1101-1';

  @override
  String get cc1101Module2 => 'CC1101-2';

  @override
  String get rssiLabel => 'RSSI:';

  @override
  String get scanningActive => 'Scanning active';

  @override
  String get scanningStopped => 'Scanning stopped';

  @override
  String get signalList => 'Signal List';

  @override
  String get spectrogramView => 'Spectrogram';

  @override
  String get searchingForSignals => 'Searching for signals...';

  @override
  String get pressStartToScan => 'Press Start to begin scanning';

  @override
  String get signalSpectrogram => 'Signal Spectrogram';

  @override
  String get signalStrengthStrong => 'Strong';

  @override
  String get signalStrengthMedium => 'Medium';

  @override
  String get signalStrengthWeak => 'Weak';

  @override
  String get signalStrengthNone => 'None';

  @override
  String errorStartingScan(String error) {
    return 'Error starting scan: $error';
  }

  @override
  String errorStoppingScan(String error) {
    return 'Error stopping scan: $error';
  }

  @override
  String get transmitSettings => 'Transmit Settings';

  @override
  String get advancedMode => 'Advanced Mode';

  @override
  String get manualConfiguration => 'Manual configuration';

  @override
  String get usePresets => 'Use presets';

  @override
  String get transmitData => 'Transmit Data';

  @override
  String get rawDataLabel => 'Raw Data';

  @override
  String get rawDataHint => 'Enter raw signal data (e.g., 100 200 300 400)';

  @override
  String get repeatCount => 'Repeat Count';

  @override
  String get repeatCountHint => '1-100';

  @override
  String get loadFile => 'Load File';

  @override
  String get transmitScreenHelp => 'Transmit Screen Help';

  @override
  String get transmitScreenHelpContent =>
      'This screen allows you to transmit RF signals using the CC1101 modules.\n\n• Select a module tab to configure its settings\n• Choose between Simple and Advanced modes\n• Simple mode uses presets for quick setup\n• Advanced mode allows fine-tuning of parameters\n• Enter raw signal data in the text field\n• Set the number of repetitions (1-100)\n• Use \"Load File\" to load signal data from a file\n• Click \"Transmit Signal\" to start transmission\n\nMake sure your device is connected before transmitting.';

  @override
  String statusLabelWithMode(String mode) {
    return 'Status: $mode';
  }

  @override
  String get connectionConnected => 'Connected';

  @override
  String get connectionDisconnected => 'Disconnected';

  @override
  String connectionLabelWithStatus(String status) {
    return 'Connection: $status';
  }

  @override
  String transmissionStartedOnModule(int number) {
    return 'Transmission started on Module #$number';
  }

  @override
  String failedToStartTransmission(String error) {
    return 'Failed to start transmission: $error';
  }

  @override
  String get featureInDevelopment => 'Feature in development';

  @override
  String get fileSelectionLater => 'File selection will be implemented later';

  @override
  String moduleBusyTransmitMessage(int number, String mode) {
    return 'Module $number is currently in mode \"$mode\".\nWait for the current operation to finish or switch the module to Idle mode.';
  }

  @override
  String invalidFrequencyClosest(String freq, String closest) {
    return 'Invalid frequency $freq MHz. Closest valid: $closest MHz';
  }

  @override
  String invalidFrequencySimple(String freq) {
    return 'Invalid frequency $freq MHz';
  }

  @override
  String invalidModuleNumber(int number) {
    return 'Invalid module number: $number';
  }

  @override
  String get rawDataRequired => 'Raw data is required for transmission';

  @override
  String get repeatCountRange => 'Repeat count must be between 1 and 100';

  @override
  String invalidDataRateValue(String rate) {
    return 'Invalid data rate $rate kBaud';
  }

  @override
  String invalidDeviationValue(String value) {
    return 'Invalid deviation $value kHz';
  }

  @override
  String get transmissionErrorLabel => 'Transmission error';

  @override
  String get allCategory => 'All';

  @override
  String get nrfModule => 'nRF24L01 Module';

  @override
  String get nrfSubtitle => 'MouseJack / Spectrum / Jammer';

  @override
  String get nrfInitialize => 'Initialize NRF24';

  @override
  String get nrfNotDetected => 'nRF24L01 module not detected';

  @override
  String get connectToDeviceFirst => 'Connect to device first';

  @override
  String get mouseJack => 'MouseJack';

  @override
  String get spectrum => 'Spectrum';

  @override
  String get jammer => 'Jammer';

  @override
  String get scan => 'Scan';

  @override
  String get startScan => 'Start Scan';

  @override
  String get stopScan => 'Stop Scan';

  @override
  String get refreshTargets => 'Refresh targets';

  @override
  String targetsCount(int count) {
    return 'Targets ($count)';
  }

  @override
  String get noDevicesFoundYet => 'No devices found yet';

  @override
  String get attack => 'Attack';

  @override
  String get injectText => 'Inject Text';

  @override
  String get textToInject => 'Text to inject...';

  @override
  String get duckyScript => 'DuckyScript';

  @override
  String get duckyPathHint => '/DATA/DUCKY/payload.txt';

  @override
  String get run => 'Run';

  @override
  String get stopAttack => 'Stop Attack';

  @override
  String get startAnalyzer => 'Start Analyzer';

  @override
  String channelLabel(int ch) {
    return 'CH $ch';
  }

  @override
  String get jammerDisclaimer =>
      'For educational use only. Jamming may be illegal in your jurisdiction.';

  @override
  String get mode => 'Mode';

  @override
  String get fullSpectrum => 'Full Spectrum';

  @override
  String get fullSpectrumDesc => '1-124 channels';

  @override
  String get wifiMode => 'WiFi';

  @override
  String get wifiModeDesc => '2.4 GHz WiFi channels';

  @override
  String get bleMode => 'BLE';

  @override
  String get bleModeDesc => 'BLE data channels';

  @override
  String get bleAdvertising => 'BLE Advertising';

  @override
  String get bleAdvertisingDesc => 'BLE advert channels';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get bluetoothDesc => 'Classic BT channels';

  @override
  String get usbWireless => 'USB Wireless';

  @override
  String get usbWirelessDesc => 'USB wireless channels';

  @override
  String get videoStreaming => 'Video Streaming';

  @override
  String get videoStreamingDesc => 'Video channels';

  @override
  String get rcControllers => 'RC Controllers';

  @override
  String get rcControllersDesc => 'RC channels';

  @override
  String get singleChannel => 'Single Channel';

  @override
  String get singleChannelDesc => 'One specific channel';

  @override
  String get customHopper => 'Custom Hopper';

  @override
  String get customHopperDesc => 'Custom range + step';

  @override
  String get channel => 'Channel';

  @override
  String channelFreq(int ch, int freq) {
    return 'Channel: $ch ($freq MHz)';
  }

  @override
  String get hopperConfig => 'Hopper Config';

  @override
  String get stopLabel => 'Stop';

  @override
  String get step => 'Step';

  @override
  String get startJammer => 'Start Jammer';

  @override
  String get stopJammer => 'Stop Jammer';

  @override
  String get deviceInfo => 'Device Info';

  @override
  String get currentFirmware => 'Current Firmware';

  @override
  String freeHeapBytes(int bytes) {
    return '$bytes bytes';
  }

  @override
  String get connection => 'Connection';

  @override
  String get firmwareUpdate => 'Firmware Update';

  @override
  String get latestVersion => 'Latest Version';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get upToDate => 'No (up to date)';

  @override
  String get yes => 'Yes';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checking => 'Checking...';

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Downloading firmware...';

  @override
  String downloadComplete(int bytes) {
    return 'Download complete ($bytes bytes)';
  }

  @override
  String get noNewVersion => 'No new version available.';

  @override
  String get apiError => 'API Error';

  @override
  String get otaTransfer => 'OTA Transfer';

  @override
  String sendingChunk(int current, int total) {
    return 'Sending chunk $current/$total';
  }

  @override
  String get firmwareUploadedSuccess => 'Firmware uploaded successfully!';

  @override
  String get deviceWillVerify => 'Device will verify and install the update.';

  @override
  String firmwareReady(int bytes) {
    return 'Firmware ready: $bytes bytes';
  }

  @override
  String get startOtaUpdate => 'Start OTA Update';

  @override
  String get otaTransferComplete =>
      'OTA transfer complete! Device will reboot.';

  @override
  String transferFailed(String error) {
    return 'Transfer failed: $error';
  }

  @override
  String get md5Mismatch => 'MD5 mismatch! File may be corrupted.';

  @override
  String get debugModeDisabled => 'Debug mode disabled';

  @override
  String get debugModeEnabled => 'Debug mode enabled';

  @override
  String get debug => 'Debug';

  @override
  String get disableDbg => 'Disable DBG';

  @override
  String get subGhzTab => 'Sub-GHz';

  @override
  String get nrfTab => 'NRF';

  @override
  String get settingsSyncedWithDevice => 'Settings synced with device';

  @override
  String get appSettings => 'App Settings';

  @override
  String get appSettingsSubtitle => 'Language, cache, permissions';

  @override
  String get rfSettings => 'RF Settings';

  @override
  String get syncedWithDevice => 'Synced with device';

  @override
  String get localOnly => 'Local only';

  @override
  String get bruteforceSettings => 'Bruteforce Settings';

  @override
  String get radioSettings => 'Radio Settings';

  @override
  String get scannerSettings => 'Scanner Settings';

  @override
  String interFrameDelay(int ms) {
    return 'Inter-frame Delay: $ms ms';
  }

  @override
  String get delayBetweenTransmissions => 'Delay between each RF transmission';

  @override
  String repeatsCount(int count) {
    return 'Repeats: ${count}x';
  }

  @override
  String get transmissionsPerCode => 'Transmissions per code (1-10)';

  @override
  String txPowerLevel(int level) {
    return 'TX Power: Level $level';
  }

  @override
  String get bruterTxPowerDesc => 'Bruter transmission power (0=Min, 7=Max)';

  @override
  String get txPowerInfoDesc =>
      'TX power in dBm. Higher = longer range but more interference. Default: +10 dBm.';

  @override
  String rssiThreshold(int dbm) {
    return 'RSSI Threshold: $dbm dBm';
  }

  @override
  String get minSignalStrengthDesc =>
      'Minimum signal strength to detect (-120 to -20)';

  @override
  String get nrf24Settings => 'nRF24 Settings';

  @override
  String get nrf24SettingsSubtitle => 'PA level, data rate, channel';

  @override
  String get nrf24ConfigDesc =>
      'Configure the nRF24L01 radio module for MouseJack attacks, spectrum analysis, and jamming.';

  @override
  String paLevel(String level) {
    return 'PA Level: $level';
  }

  @override
  String get transmissionPowerDesc => 'Transmission power (MIN → MAX)';

  @override
  String nrfDataRate(String rate) {
    return 'Data Rate: $rate';
  }

  @override
  String get radioDataRateDesc => 'Radio data rate — lower = longer range';

  @override
  String defaultChannel(int ch) {
    return 'Default Channel: $ch';
  }

  @override
  String autoRetransmit(int count) {
    return 'Auto-Retransmit: ${count}x';
  }

  @override
  String get retransmitCountDesc => 'Retransmit count on failure (0-15)';

  @override
  String get sendToDevice => 'Send to Device';

  @override
  String get connectToDeviceToApply => 'Connect to device to apply';

  @override
  String get nrf24SettingsSent => 'nRF24 settings sent to device';

  @override
  String failedToSendNrf24Settings(String error) {
    return 'Failed to send nRF24 settings: $error';
  }

  @override
  String get hwButtons => 'HW Buttons';

  @override
  String get configureHwButtonActions => 'Configure hardware button actions';

  @override
  String get hwButtonsDesc =>
      'Assign an action to each physical button on the device. Press \"Send to Device\" to apply.';

  @override
  String get button1Gpio34 => 'Button 1 (GPIO34)';

  @override
  String get button2Gpio35 => 'Button 2 (GPIO35)';

  @override
  String get buttonConfigSent => 'Button config sent to device';

  @override
  String failedToSendConfig(String error) {
    return 'Failed to send config: $error';
  }

  @override
  String get firmwareInfo => 'Firmware Info';

  @override
  String versionLabel(String version) {
    return 'Version: v$version';
  }

  @override
  String fwVersionDetails(int major, int minor, int patch) {
    return 'Major: $major | Minor: $minor | Patch: $patch';
  }

  @override
  String get waitingForDeviceResponse =>
      'Waiting for device response...\nPlease try again in a moment.';

  @override
  String get tapOtaUpdateDesc =>
      'Tap \"OTA Update\" below to check for updates and flash new firmware.';

  @override
  String deviceFwVersion(String version) {
    return 'Device FW: v$version';
  }

  @override
  String get updateFirmwareDesc =>
      'Update firmware via BLE OTA or check for new releases on GitHub.';

  @override
  String get checkFwVersion => 'Check FW Version';

  @override
  String get otaUpdate => 'OTA Update';

  @override
  String get connectToADeviceFirst => 'Connect to a device first';

  @override
  String get checkingForAppUpdates => 'Checking for app updates...';

  @override
  String appUpToDate(String version) {
    return 'App is up to date (v$version)';
  }

  @override
  String get appUpdateAvailable => 'App Update Available';

  @override
  String currentVersionLabel(String version) {
    return 'Current: v$version';
  }

  @override
  String latestVersionLabel(String version) {
    return 'Latest: v$version';
  }

  @override
  String get changelogLabel => 'Changelog:';

  @override
  String get later => 'Later';

  @override
  String get downloadAndInstall => 'Download & Install';

  @override
  String updateCheckFailed(String error) {
    return 'Update check failed: $error';
  }

  @override
  String get downloadingApk => 'Downloading APK...';

  @override
  String apkSavedPleaseInstall(String path) {
    return 'APK saved to: $path\nPlease install manually.';
  }

  @override
  String get checkAppUpdate => 'Check App Update';

  @override
  String get about => 'About';

  @override
  String get appName => 'EvilCrow RF V2';

  @override
  String get appTagline => 'Sub-GHz RF Security Tool';

  @override
  String get connectionStatus => 'Connection Status';

  @override
  String get debugControls => 'Debug Controls';

  @override
  String get clearCachedDevice => 'Clear Cached Device';

  @override
  String get refreshFiles => 'Refresh Files';

  @override
  String get activityLogs => 'Activity Logs';

  @override
  String get hideUnknown => 'Hide Unknown';

  @override
  String get sdCard => 'SD Card';

  @override
  String get internal => 'Internal';

  @override
  String get internalLittleFs => 'Internal (LittleFS)';

  @override
  String get directory => 'Directory';

  @override
  String get flashLocalBinary => 'Flash Local Binary';

  @override
  String get selectBinFileDesc =>
      'Select a .bin firmware file from your device to flash directly via BLE OTA.';

  @override
  String get selectBin => 'Select .bin';

  @override
  String get flash => 'Flash';

  @override
  String fileLabel(String path) {
    return 'File: $path';
  }

  @override
  String get localFirmwareUploaded => 'Local firmware uploaded!';

  @override
  String changelogVersion(String version) {
    return 'Changelog — v$version';
  }

  @override
  String get startingOtaTransfer => 'Starting OTA transfer...';

  @override
  String get frequencyRequired => 'Frequency is required';

  @override
  String get invalidFrequencyFormat => 'Invalid frequency format';

  @override
  String get frequencyRangeError =>
      'Frequency must be in range 300-348, 387-464, or 779-928 MHz';

  @override
  String get selectFrequency => 'Select Frequency';

  @override
  String get invalidDataRateFormat => 'Invalid data rate format';

  @override
  String dataRateRangeError(String min, String max) {
    return 'Data rate must be between $min and $max kBaud';
  }

  @override
  String get invalidDeviationFormat => 'Invalid deviation format';

  @override
  String deviationRangeError(String min, String max) {
    return 'Deviation must be between $min and $max kHz';
  }

  @override
  String get errors => 'Errors';

  @override
  String get noSignalDataToPreview => 'No signal data to preview';

  @override
  String get signalPreview => 'Signal Preview';

  @override
  String get dataLength => 'Data Length';

  @override
  String get sampleData => 'Sample Data:';

  @override
  String get loadSignalFile => 'Load Signal File';

  @override
  String get selectFile => 'Select File';

  @override
  String get formats => 'Formats';

  @override
  String get supportedFormatsShort =>
      'Supported formats: .sub (FlipperZero), .json (TUT)';

  @override
  String get supportedFileFormats => 'Supported File Formats';

  @override
  String get readyToTransmit => 'Ready to Transmit';

  @override
  String percentComplete(int progress) {
    return '$progress% complete';
  }

  @override
  String get validationErrors => 'Validation Errors';

  @override
  String get noTransmissionHistory => 'No transmission history';

  @override
  String get transmissionHistory => 'Transmission History';

  @override
  String get success => 'Success';

  @override
  String get goUp => 'Go Up';

  @override
  String get connectToDeviceToSeeFiles => 'Connect to device to see files';

  @override
  String get noFilesAvailableForSelection => 'No files available for selection';

  @override
  String get deselectFile => 'Deselect file';

  @override
  String get selectFileTooltip => 'Select file';

  @override
  String get saveToSignals => 'Save to Signals';

  @override
  String get fullPath => 'Full Path';

  @override
  String get downloadingFiles => 'Downloading files...';

  @override
  String get close => 'Close';

  @override
  String get root => 'Root';

  @override
  String get noSubdirectories => 'No subdirectories';

  @override
  String get storageLabel => 'Storage: ';

  @override
  String get errorLoadingDirectories => 'Error loading directories';

  @override
  String get select => 'Select';

  @override
  String get settingsNotAvailable => 'Settings not available';

  @override
  String playingFile(String filename) {
    return 'Playing file: $filename';
  }

  @override
  String failedToSaveSignal(String error) {
    return 'Failed to save signal: $error';
  }

  @override
  String failedToDeleteFile(String error) {
    return 'Failed to delete file: $error';
  }

  @override
  String deletingFile(String name) {
    return 'Deleting file: $name';
  }

  @override
  String get recordScreenHelpContent =>
      'This screen allows you to record RF signals using the CC1101 modules.\n\n• Select a module tab to configure its settings\n• Tap Start Recording to begin capturing\n• Detected signals appear in real-time\n• Save captured signals with custom names\n• Play back or transmit saved recordings\n\nFor best results, place the antenna close to the transmitter.';

  @override
  String frequencySearchStarted(int number) {
    return 'Frequency search started for Module $number';
  }

  @override
  String failedToStartFrequencySearch(String error) {
    return 'Failed to start frequency search: $error';
  }

  @override
  String failedToStopFrequencySearch(String error) {
    return 'Failed to stop frequency search: $error';
  }

  @override
  String get standingOnShoulders => 'Standing on the shoulders of giants';

  @override
  String get githubProfile => 'GitHub Profile';

  @override
  String get donate => 'Donate';

  @override
  String get sdrMode => 'SDR MODE';

  @override
  String get sdrModeActiveSubtitle => 'Active — SubGhz ops blocked';

  @override
  String get sdrModeInactiveSubtitle => 'CC1101 spectrum & raw RX via USB';

  @override
  String get sdrConnectViaUsb => 'Connect via USB serial for SDR streaming.';

  @override
  String get connectedStatus => 'Connected';

  @override
  String get disconnectedStatus => 'Disconnected';

  @override
  String get testCommands => 'Test Commands:';

  @override
  String deviceLabel(String name) {
    return 'Device: $name';
  }

  @override
  String deviceIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get stateIdle => 'Idle';

  @override
  String get stateDetecting => 'Detecting';

  @override
  String get stateRecording => 'Recording';

  @override
  String get stateTransmitting => 'Transmitting';

  @override
  String get stateUnknown => 'Unknown';

  @override
  String get nrf24Jamming => 'NRF24: Jamming';

  @override
  String get nrf24Scanning => 'NRF24: Scanning';

  @override
  String get nrf24Attacking => 'NRF24: Attacking';

  @override
  String get nrf24SpectrumActive => 'NRF24: Spectrum';

  @override
  String get nrf24Idle => 'NRF24: Idle';

  @override
  String batteryTooltip(int percentage, String volts, String charging) {
    return 'Battery: $percentage% ($volts V)$charging';
  }

  @override
  String get specialThanks => '★ Special Thanks ★';

  @override
  String get frequencyLabel => 'Frequency';

  @override
  String get modulationLabel => 'Modulation';

  @override
  String get dataRateLabel => 'Data Rate';

  @override
  String get deviationLabel => 'Deviation';

  @override
  String get dataLengthLabel => 'Data Length';

  @override
  String get flipperSubGhzFormat => 'FlipperZero SubGhz (.sub)';

  @override
  String get flipperSubGhzDetails =>
      '• Raw signal data format\n• Used by Flipper Zero device\n• Contains frequency and modulation settings';

  @override
  String get tutJsonFormat => 'TUT JSON (.json)';

  @override
  String get tutJsonDetails =>
      '• JSON format with signal parameters\n• Used by TUT (Test & Utility Tool)\n• Contains frequency, data rate, and raw data';

  @override
  String sdCardPath(String path) {
    return 'SD Card: $path';
  }

  @override
  String get rfScanner => 'RF Scanner';

  @override
  String moreSamples(int count) {
    return '+$count more';
  }

  @override
  String sampleCount(int count) {
    return '$count samples';
  }

  @override
  String transmitHistorySubtitle(
      String time, int moduleNumber, int repeatCount) {
    return '$time • Module $moduleNumber • $repeatCount repeats';
  }

  @override
  String downloadingFile(String name) {
    return 'Downloading file: $name';
  }

  @override
  String moduleStatus(int number, String mode) {
    return 'Module $number: $mode';
  }

  @override
  String get transmittingEllipsis => 'Transmitting...';

  @override
  String get chargingIndicator => ' ⚡ Charging';
}
