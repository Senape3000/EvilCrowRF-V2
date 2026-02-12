import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Tut RF'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @brute.
  ///
  /// In en, this message translates to:
  /// **'Brute'**
  String get brute;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Dialog title when connection is required
  ///
  /// In en, this message translates to:
  /// **'Connection Required'**
  String get connectionRequired;

  /// Dialog message when connection is required
  ///
  /// In en, this message translates to:
  /// **'Please connect to a device first to access this feature.'**
  String get connectionRequiredMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Permission error title
  ///
  /// In en, this message translates to:
  /// **'Permission Error'**
  String get permissionError;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Connection status message
  ///
  /// In en, this message translates to:
  /// **'Connected to {deviceName}'**
  String connected(String deviceName);

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connectingToKnownDevice.
  ///
  /// In en, this message translates to:
  /// **'Connecting to known device...'**
  String get connectingToKnownDevice;

  /// No description provided for @scanningForDevice.
  ///
  /// In en, this message translates to:
  /// **'Scanning for device...'**
  String get scanningForDevice;

  /// No description provided for @deviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Device not found. Make sure it\'s powered on and nearby.'**
  String get deviceNotFound;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error: {error}'**
  String connectionError(String error);

  /// No description provided for @bluetoothEnabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth enabled'**
  String get bluetoothEnabled;

  /// No description provided for @bluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disabled'**
  String get bluetoothDisabled;

  /// No description provided for @somePermissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Some permissions denied. Bluetooth may not work properly.'**
  String get somePermissionsDenied;

  /// No description provided for @allPermissionsGranted.
  ///
  /// In en, this message translates to:
  /// **'All permissions granted. Bluetooth ready.'**
  String get allPermissionsGranted;

  /// No description provided for @bluetoothScanPermissionsNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth scan permissions not granted'**
  String get bluetoothScanPermissionsNotGranted;

  /// No description provided for @scanningForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices...'**
  String get scanningForDevices;

  /// No description provided for @foundSupportedDevices.
  ///
  /// In en, this message translates to:
  /// **'Found {count} supported device(s). Tap to connect.'**
  String foundSupportedDevices(int count);

  /// No description provided for @noSupportedDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No supported devices found. Make sure ESP32 is powered on and nearby.'**
  String get noSupportedDevicesFound;

  /// No description provided for @scanError.
  ///
  /// In en, this message translates to:
  /// **'Scan error: {error}'**
  String scanError(String error);

  /// No description provided for @scanStopped.
  ///
  /// In en, this message translates to:
  /// **'Scan stopped'**
  String get scanStopped;

  /// No description provided for @stopScanError.
  ///
  /// In en, this message translates to:
  /// **'Stop scan error: {error}'**
  String stopScanError(String error);

  /// No description provided for @requiredCharacteristicsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Required characteristics not found'**
  String get requiredCharacteristicsNotFound;

  /// No description provided for @requiredServiceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Required service not found'**
  String get requiredServiceNotFound;

  /// No description provided for @knownDeviceCleared.
  ///
  /// In en, this message translates to:
  /// **'Known device cleared. Next connection will scan for devices.'**
  String get knownDeviceCleared;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @sendError.
  ///
  /// In en, this message translates to:
  /// **'Send error: {error}'**
  String sendError(String error);

  /// No description provided for @commandTimeout.
  ///
  /// In en, this message translates to:
  /// **'Command timeout - please try again'**
  String get commandTimeout;

  /// No description provided for @fileListLoadingTimeout.
  ///
  /// In en, this message translates to:
  /// **'File list loading timeout - please try again'**
  String get fileListLoadingTimeout;

  /// No description provided for @transmittingSignal.
  ///
  /// In en, this message translates to:
  /// **'Transmitting signal...'**
  String get transmittingSignal;

  /// No description provided for @transmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transmission failed: {error}'**
  String transmissionFailed(String error);

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @scanForNewDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for New Devices'**
  String get scanForNewDevices;

  /// No description provided for @scanForDevices.
  ///
  /// In en, this message translates to:
  /// **'Scan for Devices'**
  String get scanForDevices;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan Again'**
  String get scanAgain;

  /// No description provided for @foundSupportedDevicesCount.
  ///
  /// In en, this message translates to:
  /// **'Found {count} supported device(s):'**
  String foundSupportedDevicesCount(int count);

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @notConnectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Not connected to device'**
  String get notConnectedToDevice;

  /// No description provided for @connectToDeviceToManageFiles.
  ///
  /// In en, this message translates to:
  /// **'Connect to a device to manage files'**
  String get connectToDeviceToManageFiles;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @stopLoading.
  ///
  /// In en, this message translates to:
  /// **'Stop Loading'**
  String get stopLoading;

  /// No description provided for @createDirectory.
  ///
  /// In en, this message translates to:
  /// **'Create Directory'**
  String get createDirectory;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFile;

  /// No description provided for @exitMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Exit Multi-Select'**
  String get exitMultiSelect;

  /// No description provided for @multiSelect.
  ///
  /// In en, this message translates to:
  /// **'Multi-Select'**
  String get multiSelect;

  /// No description provided for @directoryName.
  ///
  /// In en, this message translates to:
  /// **'Directory name'**
  String get directoryName;

  /// No description provided for @enterDirectoryName.
  ///
  /// In en, this message translates to:
  /// **'Enter directory name'**
  String get enterDirectoryName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @copyFile.
  ///
  /// In en, this message translates to:
  /// **'Copy File'**
  String get copyFile;

  /// No description provided for @newFileName.
  ///
  /// In en, this message translates to:
  /// **'New file name'**
  String get newFileName;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination: {path}'**
  String destination(String path);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @renameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Rename Directory'**
  String get renameDirectory;

  /// No description provided for @renameFile.
  ///
  /// In en, this message translates to:
  /// **'Rename File'**
  String get renameFile;

  /// No description provided for @newDirectoryName.
  ///
  /// In en, this message translates to:
  /// **'New directory name'**
  String get newDirectoryName;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @deleteDirectory.
  ///
  /// In en, this message translates to:
  /// **'Delete Directory'**
  String get deleteDirectory;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete File'**
  String get deleteFile;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get deleteFiles;

  /// No description provided for @deleteFilesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} files?'**
  String deleteFilesConfirm(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get clearSelection;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// No description provided for @moveDirectory.
  ///
  /// In en, this message translates to:
  /// **'Move Directory'**
  String get moveDirectory;

  /// No description provided for @moveFile.
  ///
  /// In en, this message translates to:
  /// **'Move File'**
  String get moveFile;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get records;

  /// No description provided for @signals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get signals;

  /// No description provided for @captured.
  ///
  /// In en, this message translates to:
  /// **'Captured'**
  String get captured;

  /// No description provided for @presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// No description provided for @temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get temp;

  /// No description provided for @saveFileAs.
  ///
  /// In en, this message translates to:
  /// **'Save file as...'**
  String get saveFileAs;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved to: {path}'**
  String fileSaved(String path);

  /// No description provided for @fileContentCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'File content copied to clipboard'**
  String get fileContentCopiedToClipboard;

  /// No description provided for @fileSavedToDocuments.
  ///
  /// In en, this message translates to:
  /// **'File saved to Documents: {path}'**
  String fileSavedToDocuments(String path);

  /// No description provided for @couldNotSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Could not save file. Content copied to clipboard. Error: {error}'**
  String couldNotSaveFile(String error);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// No description provided for @downloadFailedNoContent.
  ///
  /// In en, this message translates to:
  /// **'Download failed: No content received'**
  String get downloadFailedNoContent;

  /// No description provided for @fileCopied.
  ///
  /// In en, this message translates to:
  /// **'File copied: {name}'**
  String fileCopied(String name);

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String copyFailed(String error);

  /// No description provided for @directoryRenamed.
  ///
  /// In en, this message translates to:
  /// **'Directory renamed to: {name}'**
  String directoryRenamed(String name);

  /// No description provided for @fileRenamed.
  ///
  /// In en, this message translates to:
  /// **'File renamed to: {name}'**
  String fileRenamed(String name);

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Rename failed: {error}'**
  String renameFailed(String error);

  /// No description provided for @directoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Directory deleted: {name}'**
  String directoryDeleted(String name);

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted: {name}'**
  String fileDeleted(String name);

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @deletedFilesCount.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} files{extra}'**
  String deletedFilesCount(int count, String extra);

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get failed;

  /// No description provided for @directoryMoved.
  ///
  /// In en, this message translates to:
  /// **'Directory moved: {name}'**
  String directoryMoved(String name);

  /// No description provided for @fileMoved.
  ///
  /// In en, this message translates to:
  /// **'File moved: {name}'**
  String fileMoved(String name);

  /// No description provided for @moveFailed.
  ///
  /// In en, this message translates to:
  /// **'Move failed: {error}'**
  String moveFailed(String error);

  /// No description provided for @directoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Directory created: {name}'**
  String directoryCreated(String name);

  /// No description provided for @failedToCreateDirectory.
  ///
  /// In en, this message translates to:
  /// **'Failed to create directory: {error}'**
  String failedToCreateDirectory(String error);

  /// No description provided for @uploadingFile.
  ///
  /// In en, this message translates to:
  /// **'Uploading {fileName}...'**
  String uploadingFile(String fileName);

  /// No description provided for @fileUploaded.
  ///
  /// In en, this message translates to:
  /// **'File uploaded: {fileName}'**
  String fileUploaded(String fileName);

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// No description provided for @selectedFileDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Selected file does not exist'**
  String get selectedFileDoesNotExist;

  /// No description provided for @uploadError.
  ///
  /// In en, this message translates to:
  /// **'Upload Error'**
  String get uploadError;

  /// No description provided for @failedToPickFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick file: {error}'**
  String failedToPickFile(String error);

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsYet;

  /// No description provided for @commandsAndResponsesWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Commands and responses will appear here'**
  String get commandsAndResponsesWillAppearHere;

  /// No description provided for @logsCount.
  ///
  /// In en, this message translates to:
  /// **'Logs ({count})'**
  String logsCount(int count);

  /// No description provided for @clearAllLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs'**
  String get clearAllLogs;

  /// No description provided for @loadingFilePreview.
  ///
  /// In en, this message translates to:
  /// **'Loading file preview...'**
  String get loadingFilePreview;

  /// No description provided for @previewError.
  ///
  /// In en, this message translates to:
  /// **'Preview Error'**
  String get previewError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @chars.
  ///
  /// In en, this message translates to:
  /// **'{count} chars'**
  String chars(int count);

  /// No description provided for @previewTruncated.
  ///
  /// In en, this message translates to:
  /// **'Preview truncated. Open file to see full content.'**
  String get previewTruncated;

  /// No description provided for @clearFileCache.
  ///
  /// In en, this message translates to:
  /// **'Clear File Cache'**
  String get clearFileCache;

  /// No description provided for @rebootDevice.
  ///
  /// In en, this message translates to:
  /// **'Reboot Device'**
  String get rebootDevice;

  /// No description provided for @requestPermissions.
  ///
  /// In en, this message translates to:
  /// **'Request Permissions'**
  String get requestPermissions;

  /// No description provided for @sendCommand.
  ///
  /// In en, this message translates to:
  /// **'Send Command'**
  String get sendCommand;

  /// No description provided for @enterCommand.
  ///
  /// In en, this message translates to:
  /// **'Enter Command'**
  String get enterCommand;

  /// No description provided for @commandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., SCAN, RECORD, PLAY'**
  String get commandHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @scanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get scanner;

  /// No description provided for @clearList.
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get clearList;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @deviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Device Status'**
  String get deviceStatus;

  /// No description provided for @subGhzModule.
  ///
  /// In en, this message translates to:
  /// **'Sub-GHz Module {number}'**
  String subGhzModule(int number);

  /// No description provided for @connectedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connected: {deviceName}'**
  String connectedToDevice(String deviceName);

  /// No description provided for @sdCardReady.
  ///
  /// In en, this message translates to:
  /// **'SD Card ready'**
  String get sdCardReady;

  /// No description provided for @freeHeap.
  ///
  /// In en, this message translates to:
  /// **'Free Heap'**
  String freeHeap(String kb);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'m ago'**
  String get minutesAgo;

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'h ago'**
  String get hoursAgo;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'d ago'**
  String get daysAgo;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @modulation.
  ///
  /// In en, this message translates to:
  /// **'Modulation'**
  String get modulation;

  /// No description provided for @dataRate.
  ///
  /// In en, this message translates to:
  /// **'Data Rate'**
  String get dataRate;

  /// No description provided for @bandwidth.
  ///
  /// In en, this message translates to:
  /// **'Bandwidth'**
  String get bandwidth;

  /// No description provided for @deviation.
  ///
  /// In en, this message translates to:
  /// **'Deviation'**
  String get deviation;

  /// No description provided for @rxBandwidth.
  ///
  /// In en, this message translates to:
  /// **'RX Bandwidth'**
  String get rxBandwidth;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @preset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get preset;

  /// No description provided for @signalName.
  ///
  /// In en, this message translates to:
  /// **'Signal Name'**
  String get signalName;

  /// No description provided for @settingsParseError.
  ///
  /// In en, this message translates to:
  /// **'Settings Parse Error'**
  String get settingsParseError;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @detecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting'**
  String get detecting;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recording;

  /// No description provided for @jamming.
  ///
  /// In en, this message translates to:
  /// **'Jamming'**
  String get jamming;

  /// No description provided for @jammingSettings.
  ///
  /// In en, this message translates to:
  /// **'Jamming Settings'**
  String get jammingSettings;

  /// No description provided for @transmitting.
  ///
  /// In en, this message translates to:
  /// **'Transmitting'**
  String get transmitting;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanning;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get statusRecording;

  /// No description provided for @statusScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get statusScanning;

  /// No description provided for @statusTransmitting.
  ///
  /// In en, this message translates to:
  /// **'Transmitting'**
  String get statusTransmitting;

  /// No description provided for @kbps.
  ///
  /// In en, this message translates to:
  /// **'kbps'**
  String get kbps;

  /// No description provided for @hz.
  ///
  /// In en, this message translates to:
  /// **'Hz'**
  String get hz;

  /// No description provided for @modulationAskOok.
  ///
  /// In en, this message translates to:
  /// **'ASK/OOK'**
  String get modulationAskOok;

  /// No description provided for @modulation2Fsk.
  ///
  /// In en, this message translates to:
  /// **'2-FSK'**
  String get modulation2Fsk;

  /// No description provided for @modulation4Fsk.
  ///
  /// In en, this message translates to:
  /// **'4-FSK'**
  String get modulation4Fsk;

  /// No description provided for @modulationGfsk.
  ///
  /// In en, this message translates to:
  /// **'GFSK'**
  String get modulationGfsk;

  /// No description provided for @modulationMsk.
  ///
  /// In en, this message translates to:
  /// **'MSK'**
  String get modulationMsk;

  /// No description provided for @startRecordingToCaptureSignals.
  ///
  /// In en, this message translates to:
  /// **'Start recording to capture signals'**
  String get startRecordingToCaptureSignals;

  /// No description provided for @frequencySearchStoppedForModule.
  ///
  /// In en, this message translates to:
  /// **'Frequency search stopped for Module {number}'**
  String frequencySearchStoppedForModule(int number);

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @deviceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Device not connected'**
  String get deviceNotConnected;

  /// No description provided for @moduleBusy.
  ///
  /// In en, this message translates to:
  /// **'Module Busy'**
  String get moduleBusy;

  /// No description provided for @moduleBusyMessage.
  ///
  /// In en, this message translates to:
  /// **'Module {number} is currently in \"{mode}\" mode.\\nWait for the current operation to complete or switch the module to Idle mode.'**
  String moduleBusyMessage(int number, String mode);

  /// No description provided for @validationError.
  ///
  /// In en, this message translates to:
  /// **'Validation Error'**
  String get validationError;

  /// No description provided for @recordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started on module {number}'**
  String recordingStarted(int number);

  /// No description provided for @recordingError.
  ///
  /// In en, this message translates to:
  /// **'Recording Error'**
  String get recordingError;

  /// No description provided for @recordingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String recordingStartFailed(String error);

  /// No description provided for @recordingStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped on module {number}'**
  String recordingStopped(int number);

  /// No description provided for @recordingStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop recording: {error}'**
  String recordingStopFailed(String error);

  /// No description provided for @module.
  ///
  /// In en, this message translates to:
  /// **'Module {number}'**
  String module(int number);

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @startJamming.
  ///
  /// In en, this message translates to:
  /// **'Start Jamming'**
  String get startJamming;

  /// No description provided for @stopJamming.
  ///
  /// In en, this message translates to:
  /// **'Stop Jamming'**
  String get stopJamming;

  /// No description provided for @jammingStarted.
  ///
  /// In en, this message translates to:
  /// **'Jamming started on Module {module}'**
  String jammingStarted(int module);

  /// No description provided for @jammingStopped.
  ///
  /// In en, this message translates to:
  /// **'Jamming stopped on Module {module}'**
  String jammingStopped(int module);

  /// No description provided for @jammingError.
  ///
  /// In en, this message translates to:
  /// **'Jamming Error'**
  String get jammingError;

  /// No description provided for @jammingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start jamming: {error}'**
  String jammingStartFailed(String error);

  /// No description provided for @jammingStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop jamming: {error}'**
  String jammingStopFailed(String error);

  /// No description provided for @stopFrequencySearch.
  ///
  /// In en, this message translates to:
  /// **'Stop frequency search'**
  String get stopFrequencySearch;

  /// No description provided for @searchForFrequency.
  ///
  /// In en, this message translates to:
  /// **'Search for frequency'**
  String get searchForFrequency;

  /// No description provided for @signalsCaptured.
  ///
  /// In en, this message translates to:
  /// **'Module {number} Signals Captured ({count})'**
  String signalsCaptured(Object count, Object number);

  /// No description provided for @recordedFiles.
  ///
  /// In en, this message translates to:
  /// **'Recorded Files'**
  String get recordedFiles;

  /// No description provided for @saveSignal.
  ///
  /// In en, this message translates to:
  /// **'Save Signal'**
  String get saveSignal;

  /// No description provided for @enterSignalName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the signal:'**
  String get enterSignalName;

  /// No description provided for @deleteSignal.
  ///
  /// In en, this message translates to:
  /// **'Delete Signal'**
  String get deleteSignal;

  /// No description provided for @deleteSignalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{filename}\"?\\n\\nThis action cannot be undone.'**
  String deleteSignalConfirm(String filename);

  /// No description provided for @recordScreenHelp.
  ///
  /// In en, this message translates to:
  /// **'Record Screen Help'**
  String get recordScreenHelp;

  /// No description provided for @fileDownloadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'File \"{fileName}\" downloaded successfully'**
  String fileDownloadedSuccessfully(String fileName);

  /// No description provided for @imagePreviewNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Image preview not supported yet'**
  String get imagePreviewNotSupported;

  /// No description provided for @viewAsText.
  ///
  /// In en, this message translates to:
  /// **'View as Text'**
  String get viewAsText;

  /// No description provided for @failedToParseFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse file'**
  String get failedToParseFile;

  /// No description provided for @signalParameters.
  ///
  /// In en, this message translates to:
  /// **'Signal Parameters'**
  String get signalParameters;

  /// No description provided for @signalData.
  ///
  /// In en, this message translates to:
  /// **'Signal Data'**
  String get signalData;

  /// No description provided for @samplesCount.
  ///
  /// In en, this message translates to:
  /// **'Samples Count'**
  String get samplesCount;

  /// No description provided for @rawData.
  ///
  /// In en, this message translates to:
  /// **'Raw Data:'**
  String get rawData;

  /// No description provided for @binaryData.
  ///
  /// In en, this message translates to:
  /// **'Binary Data:'**
  String get binaryData;

  /// No description provided for @warnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warnings;

  /// No description provided for @noContentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get noContentAvailable;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// No description provided for @downloadFile.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get downloadFile;

  /// No description provided for @transmitSignal.
  ///
  /// In en, this message translates to:
  /// **'Transmit Signal'**
  String get transmitSignal;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @parsed.
  ///
  /// In en, this message translates to:
  /// **'Parsed'**
  String get parsed;

  /// No description provided for @raw.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get raw;

  /// No description provided for @loadingFile.
  ///
  /// In en, this message translates to:
  /// **'Loading file...'**
  String get loadingFile;

  /// No description provided for @notConnectedToDeviceFile.
  ///
  /// In en, this message translates to:
  /// **'Not connected to device'**
  String get notConnectedToDeviceFile;

  /// No description provided for @connectToDeviceToViewFiles.
  ///
  /// In en, this message translates to:
  /// **'Connect to a device to view files'**
  String get connectToDeviceToViewFiles;

  /// No description provided for @transmitSignalConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will transmit the signal from this file.'**
  String get transmitSignalConfirm;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @transmitWarning.
  ///
  /// In en, this message translates to:
  /// **'Only use in controlled environments. Check local regulations.'**
  String get transmitWarning;

  /// No description provided for @dontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get dontShowAgain;

  /// No description provided for @resetTransmitConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Reset Transmit Confirmation'**
  String get resetTransmitConfirmation;

  /// No description provided for @transmitConfirmationReset.
  ///
  /// In en, this message translates to:
  /// **'Transmit confirmation dialog has been reset.'**
  String get transmitConfirmationReset;

  /// No description provided for @transmit.
  ///
  /// In en, this message translates to:
  /// **'Transmit'**
  String get transmit;

  /// No description provided for @signalTransmissionStarted.
  ///
  /// In en, this message translates to:
  /// **'Signal transmission started: {fileName}'**
  String signalTransmissionStarted(String fileName);

  /// No description provided for @transmissionError.
  ///
  /// In en, this message translates to:
  /// **'Transmission error: {error}'**
  String transmissionError(String error);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @loadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingFiles;

  /// No description provided for @noRecordedFiles.
  ///
  /// In en, this message translates to:
  /// **'No recorded files'**
  String get noRecordedFiles;

  /// No description provided for @noFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get noFilesFound;

  /// No description provided for @recordSettings.
  ///
  /// In en, this message translates to:
  /// **'Record Settings'**
  String get recordSettings;

  /// No description provided for @mhz.
  ///
  /// In en, this message translates to:
  /// **'MHz'**
  String get mhz;

  /// No description provided for @khz.
  ///
  /// In en, this message translates to:
  /// **'kHz'**
  String get khz;

  /// No description provided for @kbaud.
  ///
  /// In en, this message translates to:
  /// **'kBaud'**
  String get kbaud;

  /// No description provided for @signalSavedAs.
  ///
  /// In en, this message translates to:
  /// **'Signal saved as: {fileName}'**
  String signalSavedAs(String fileName);

  /// No description provided for @transmittingFile.
  ///
  /// In en, this message translates to:
  /// **'Transmitting file: {fileName}'**
  String transmittingFile(String fileName);

  /// No description provided for @recordingShort.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingShort;

  /// No description provided for @freqShort.
  ///
  /// In en, this message translates to:
  /// **'Freq'**
  String get freqShort;

  /// No description provided for @modShort.
  ///
  /// In en, this message translates to:
  /// **'Mod'**
  String get modShort;

  /// No description provided for @rateShort.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateShort;

  /// No description provided for @bwShort.
  ///
  /// In en, this message translates to:
  /// **'BW'**
  String get bwShort;

  /// No description provided for @clearDeviceCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Device Cache'**
  String get clearDeviceCache;

  /// No description provided for @clearDeviceCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove saved device information'**
  String get clearDeviceCacheDescription;

  /// No description provided for @filesLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'Files loaded: {loaded} of {total}'**
  String filesLoadedCount(int loaded, int total);

  /// No description provided for @filesInDirectory.
  ///
  /// In en, this message translates to:
  /// **'Files in directory: {count}'**
  String filesInDirectory(int count);

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get noFiles;

  /// No description provided for @searchProtocols.
  ///
  /// In en, this message translates to:
  /// **'Search protocols...'**
  String get searchProtocols;

  /// No description provided for @attackMode.
  ///
  /// In en, this message translates to:
  /// **'Attack Mode:'**
  String get attackMode;

  /// No description provided for @standardMode.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardMode;

  /// No description provided for @deBruijnMode.
  ///
  /// In en, this message translates to:
  /// **'DeBruijn'**
  String get deBruijnMode;

  /// No description provided for @noProtocolsFound.
  ///
  /// In en, this message translates to:
  /// **'No protocols found'**
  String get noProtocolsFound;

  /// No description provided for @pausedProtocol.
  ///
  /// In en, this message translates to:
  /// **'Paused: {name}'**
  String pausedProtocol(String name);

  /// No description provided for @bruteForceRunning.
  ///
  /// In en, this message translates to:
  /// **'Brute Force Running: {name}'**
  String bruteForceRunning(String name);

  /// No description provided for @bruteResume.
  ///
  /// In en, this message translates to:
  /// **'RESUME'**
  String get bruteResume;

  /// No description provided for @brutePause.
  ///
  /// In en, this message translates to:
  /// **'PAUSE'**
  String get brutePause;

  /// No description provided for @bruteStop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get bruteStop;

  /// No description provided for @resumeInfo.
  ///
  /// In en, this message translates to:
  /// **'Resume will re-transmit 5 codes before the pause point.'**
  String get resumeInfo;

  /// No description provided for @startBruteForce.
  ///
  /// In en, this message translates to:
  /// **'Start Brute Force'**
  String get startBruteForce;

  /// No description provided for @startBruteForceSuffix.
  ///
  /// In en, this message translates to:
  /// **'Start Brute Force{suffix}'**
  String startBruteForceSuffix(String suffix);

  /// No description provided for @keySpace.
  ///
  /// In en, this message translates to:
  /// **'Key Space'**
  String get keySpace;

  /// No description provided for @delay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get delay;

  /// No description provided for @estTime.
  ///
  /// In en, this message translates to:
  /// **'Est. Time'**
  String get estTime;

  /// No description provided for @largeKeyspaceWarning.
  ///
  /// In en, this message translates to:
  /// **'{bits}-bit keyspace is very large. Full scan may take {time}.'**
  String largeKeyspaceWarning(int bits, String time);

  /// No description provided for @deviceWillTransmit.
  ///
  /// In en, this message translates to:
  /// **'The device will start transmitting. You can stop at any time.'**
  String get deviceWillTransmit;

  /// No description provided for @bruteForceStarted.
  ///
  /// In en, this message translates to:
  /// **'Brute force started: {name}'**
  String bruteForceStarted(String name);

  /// No description provided for @failedToStart.
  ///
  /// In en, this message translates to:
  /// **'Failed to start: {error}'**
  String failedToStart(String error);

  /// No description provided for @bruteForcePausing.
  ///
  /// In en, this message translates to:
  /// **'Brute force pausing...'**
  String get bruteForcePausing;

  /// No description provided for @failedToPause.
  ///
  /// In en, this message translates to:
  /// **'Failed to pause: {error}'**
  String failedToPause(String error);

  /// No description provided for @bruteForceResumed.
  ///
  /// In en, this message translates to:
  /// **'Brute force resumed'**
  String get bruteForceResumed;

  /// No description provided for @failedToResume.
  ///
  /// In en, this message translates to:
  /// **'Failed to resume: {error}'**
  String failedToResume(String error);

  /// No description provided for @savedStateDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Saved bruter state discarded'**
  String get savedStateDiscarded;

  /// No description provided for @failedToDiscard.
  ///
  /// In en, this message translates to:
  /// **'Failed to discard state: {error}'**
  String failedToDiscard(String error);

  /// No description provided for @bruteForceStopped.
  ///
  /// In en, this message translates to:
  /// **'Brute force stopped'**
  String get bruteForceStopped;

  /// No description provided for @failedToStop.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop: {error}'**
  String failedToStop(String error);

  /// No description provided for @bruteForceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Brute force completed: {name}'**
  String bruteForceCompleted(String name);

  /// No description provided for @bruteForceCancelled.
  ///
  /// In en, this message translates to:
  /// **'Brute force cancelled: {name}'**
  String bruteForceCancelled(String name);

  /// No description provided for @bruteForceErrorMsg.
  ///
  /// In en, this message translates to:
  /// **'Brute force error: {name}'**
  String bruteForceErrorMsg(String name);

  /// No description provided for @deBruijnCompatible.
  ///
  /// In en, this message translates to:
  /// **'DeBruijn ✓'**
  String get deBruijnCompatible;

  /// No description provided for @deBruijnTooltip.
  ///
  /// In en, this message translates to:
  /// **'DeBruijn sequences cover all n-bit combinations in one continuous bitstream — ~90x faster'**
  String get deBruijnTooltip;

  /// No description provided for @deBruijnFaster.
  ///
  /// In en, this message translates to:
  /// **'DeBruijn (~90x faster)'**
  String get deBruijnFaster;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @moduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Module:'**
  String get moduleLabel;

  /// No description provided for @cc1101Module1.
  ///
  /// In en, this message translates to:
  /// **'CC1101-1'**
  String get cc1101Module1;

  /// No description provided for @cc1101Module2.
  ///
  /// In en, this message translates to:
  /// **'CC1101-2'**
  String get cc1101Module2;

  /// No description provided for @rssiLabel.
  ///
  /// In en, this message translates to:
  /// **'RSSI:'**
  String get rssiLabel;

  /// No description provided for @scanningActive.
  ///
  /// In en, this message translates to:
  /// **'Scanning active'**
  String get scanningActive;

  /// No description provided for @scanningStopped.
  ///
  /// In en, this message translates to:
  /// **'Scanning stopped'**
  String get scanningStopped;

  /// No description provided for @signalList.
  ///
  /// In en, this message translates to:
  /// **'Signal List'**
  String get signalList;

  /// No description provided for @spectrogramView.
  ///
  /// In en, this message translates to:
  /// **'Spectrogram'**
  String get spectrogramView;

  /// No description provided for @searchingForSignals.
  ///
  /// In en, this message translates to:
  /// **'Searching for signals...'**
  String get searchingForSignals;

  /// No description provided for @pressStartToScan.
  ///
  /// In en, this message translates to:
  /// **'Press Start to begin scanning'**
  String get pressStartToScan;

  /// No description provided for @signalSpectrogram.
  ///
  /// In en, this message translates to:
  /// **'Signal Spectrogram'**
  String get signalSpectrogram;

  /// No description provided for @signalStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get signalStrengthStrong;

  /// No description provided for @signalStrengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get signalStrengthMedium;

  /// No description provided for @signalStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get signalStrengthWeak;

  /// No description provided for @signalStrengthNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get signalStrengthNone;

  /// No description provided for @errorStartingScan.
  ///
  /// In en, this message translates to:
  /// **'Error starting scan: {error}'**
  String errorStartingScan(String error);

  /// No description provided for @errorStoppingScan.
  ///
  /// In en, this message translates to:
  /// **'Error stopping scan: {error}'**
  String errorStoppingScan(String error);

  /// No description provided for @transmitSettings.
  ///
  /// In en, this message translates to:
  /// **'Transmit Settings'**
  String get transmitSettings;

  /// No description provided for @advancedMode.
  ///
  /// In en, this message translates to:
  /// **'Advanced Mode'**
  String get advancedMode;

  /// No description provided for @manualConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Manual configuration'**
  String get manualConfiguration;

  /// No description provided for @usePresets.
  ///
  /// In en, this message translates to:
  /// **'Use presets'**
  String get usePresets;

  /// No description provided for @transmitData.
  ///
  /// In en, this message translates to:
  /// **'Transmit Data'**
  String get transmitData;

  /// No description provided for @rawDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Raw Data'**
  String get rawDataLabel;

  /// No description provided for @rawDataHint.
  ///
  /// In en, this message translates to:
  /// **'Enter raw signal data (e.g., 100 200 300 400)'**
  String get rawDataHint;

  /// No description provided for @repeatCount.
  ///
  /// In en, this message translates to:
  /// **'Repeat Count'**
  String get repeatCount;

  /// No description provided for @repeatCountHint.
  ///
  /// In en, this message translates to:
  /// **'1-100'**
  String get repeatCountHint;

  /// No description provided for @loadFile.
  ///
  /// In en, this message translates to:
  /// **'Load File'**
  String get loadFile;

  /// No description provided for @transmitScreenHelp.
  ///
  /// In en, this message translates to:
  /// **'Transmit Screen Help'**
  String get transmitScreenHelp;

  /// No description provided for @transmitScreenHelpContent.
  ///
  /// In en, this message translates to:
  /// **'This screen allows you to transmit RF signals using the CC1101 modules.\n\n• Select a module tab to configure its settings\n• Choose between Simple and Advanced modes\n• Simple mode uses presets for quick setup\n• Advanced mode allows fine-tuning of parameters\n• Enter raw signal data in the text field\n• Set the number of repetitions (1-100)\n• Use \"Load File\" to load signal data from a file\n• Click \"Transmit Signal\" to start transmission\n\nMake sure your device is connected before transmitting.'**
  String get transmitScreenHelpContent;

  /// No description provided for @statusLabelWithMode.
  ///
  /// In en, this message translates to:
  /// **'Status: {mode}'**
  String statusLabelWithMode(String mode);

  /// No description provided for @connectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionConnected;

  /// No description provided for @connectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionDisconnected;

  /// No description provided for @connectionLabelWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection: {status}'**
  String connectionLabelWithStatus(String status);

  /// No description provided for @transmissionStartedOnModule.
  ///
  /// In en, this message translates to:
  /// **'Transmission started on Module #{number}'**
  String transmissionStartedOnModule(int number);

  /// No description provided for @failedToStartTransmission.
  ///
  /// In en, this message translates to:
  /// **'Failed to start transmission: {error}'**
  String failedToStartTransmission(String error);

  /// No description provided for @featureInDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Feature in development'**
  String get featureInDevelopment;

  /// No description provided for @fileSelectionLater.
  ///
  /// In en, this message translates to:
  /// **'File selection will be implemented later'**
  String get fileSelectionLater;

  /// No description provided for @moduleBusyTransmitMessage.
  ///
  /// In en, this message translates to:
  /// **'Module {number} is currently in mode \"{mode}\".\nWait for the current operation to finish or switch the module to Idle mode.'**
  String moduleBusyTransmitMessage(int number, String mode);

  /// No description provided for @invalidFrequencyClosest.
  ///
  /// In en, this message translates to:
  /// **'Invalid frequency {freq} MHz. Closest valid: {closest} MHz'**
  String invalidFrequencyClosest(String freq, String closest);

  /// No description provided for @invalidFrequencySimple.
  ///
  /// In en, this message translates to:
  /// **'Invalid frequency {freq} MHz'**
  String invalidFrequencySimple(String freq);

  /// No description provided for @invalidModuleNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid module number: {number}'**
  String invalidModuleNumber(int number);

  /// No description provided for @rawDataRequired.
  ///
  /// In en, this message translates to:
  /// **'Raw data is required for transmission'**
  String get rawDataRequired;

  /// No description provided for @repeatCountRange.
  ///
  /// In en, this message translates to:
  /// **'Repeat count must be between 1 and 100'**
  String get repeatCountRange;

  /// No description provided for @invalidDataRateValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid data rate {rate} kBaud'**
  String invalidDataRateValue(String rate);

  /// No description provided for @invalidDeviationValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid deviation {value} kHz'**
  String invalidDeviationValue(String value);

  /// No description provided for @transmissionErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Transmission error'**
  String get transmissionErrorLabel;

  /// No description provided for @allCategory.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategory;

  /// No description provided for @nrfModule.
  ///
  /// In en, this message translates to:
  /// **'nRF24L01 Module'**
  String get nrfModule;

  /// No description provided for @nrfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MouseJack / Spectrum / Jammer'**
  String get nrfSubtitle;

  /// No description provided for @nrfInitialize.
  ///
  /// In en, this message translates to:
  /// **'Initialize NRF24'**
  String get nrfInitialize;

  /// No description provided for @nrfNotDetected.
  ///
  /// In en, this message translates to:
  /// **'nRF24L01 module not detected'**
  String get nrfNotDetected;

  /// No description provided for @connectToDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect to device first'**
  String get connectToDeviceFirst;

  /// No description provided for @mouseJack.
  ///
  /// In en, this message translates to:
  /// **'MouseJack'**
  String get mouseJack;

  /// No description provided for @spectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get spectrum;

  /// No description provided for @jammer.
  ///
  /// In en, this message translates to:
  /// **'Jammer'**
  String get jammer;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @startScan.
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// No description provided for @stopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop Scan'**
  String get stopScan;

  /// No description provided for @refreshTargets.
  ///
  /// In en, this message translates to:
  /// **'Refresh targets'**
  String get refreshTargets;

  /// No description provided for @targetsCount.
  ///
  /// In en, this message translates to:
  /// **'Targets ({count})'**
  String targetsCount(int count);

  /// No description provided for @noDevicesFoundYet.
  ///
  /// In en, this message translates to:
  /// **'No devices found yet'**
  String get noDevicesFoundYet;

  /// No description provided for @attack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get attack;

  /// No description provided for @injectText.
  ///
  /// In en, this message translates to:
  /// **'Inject Text'**
  String get injectText;

  /// No description provided for @textToInject.
  ///
  /// In en, this message translates to:
  /// **'Text to inject...'**
  String get textToInject;

  /// No description provided for @duckyScript.
  ///
  /// In en, this message translates to:
  /// **'DuckyScript'**
  String get duckyScript;

  /// No description provided for @duckyPathHint.
  ///
  /// In en, this message translates to:
  /// **'/DATA/DUCKY/payload.txt'**
  String get duckyPathHint;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @stopAttack.
  ///
  /// In en, this message translates to:
  /// **'Stop Attack'**
  String get stopAttack;

  /// No description provided for @startAnalyzer.
  ///
  /// In en, this message translates to:
  /// **'Start Analyzer'**
  String get startAnalyzer;

  /// No description provided for @channelLabel.
  ///
  /// In en, this message translates to:
  /// **'CH {ch}'**
  String channelLabel(int ch);

  /// No description provided for @jammerDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'For educational use only. Jamming may be illegal in your jurisdiction.'**
  String get jammerDisclaimer;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// No description provided for @fullSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Full Spectrum'**
  String get fullSpectrum;

  /// No description provided for @fullSpectrumDesc.
  ///
  /// In en, this message translates to:
  /// **'1-124 channels'**
  String get fullSpectrumDesc;

  /// No description provided for @wifiMode.
  ///
  /// In en, this message translates to:
  /// **'WiFi'**
  String get wifiMode;

  /// No description provided for @wifiModeDesc.
  ///
  /// In en, this message translates to:
  /// **'2.4 GHz WiFi channels'**
  String get wifiModeDesc;

  /// No description provided for @bleMode.
  ///
  /// In en, this message translates to:
  /// **'BLE'**
  String get bleMode;

  /// No description provided for @bleModeDesc.
  ///
  /// In en, this message translates to:
  /// **'BLE data channels'**
  String get bleModeDesc;

  /// No description provided for @bleAdvertising.
  ///
  /// In en, this message translates to:
  /// **'BLE Advertising'**
  String get bleAdvertising;

  /// No description provided for @bleAdvertisingDesc.
  ///
  /// In en, this message translates to:
  /// **'BLE advert channels'**
  String get bleAdvertisingDesc;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @bluetoothDesc.
  ///
  /// In en, this message translates to:
  /// **'Classic BT channels'**
  String get bluetoothDesc;

  /// No description provided for @usbWireless.
  ///
  /// In en, this message translates to:
  /// **'USB Wireless'**
  String get usbWireless;

  /// No description provided for @usbWirelessDesc.
  ///
  /// In en, this message translates to:
  /// **'USB wireless channels'**
  String get usbWirelessDesc;

  /// No description provided for @videoStreaming.
  ///
  /// In en, this message translates to:
  /// **'Video Streaming'**
  String get videoStreaming;

  /// No description provided for @videoStreamingDesc.
  ///
  /// In en, this message translates to:
  /// **'Video channels'**
  String get videoStreamingDesc;

  /// No description provided for @rcControllers.
  ///
  /// In en, this message translates to:
  /// **'RC Controllers'**
  String get rcControllers;

  /// No description provided for @rcControllersDesc.
  ///
  /// In en, this message translates to:
  /// **'RC channels'**
  String get rcControllersDesc;

  /// No description provided for @singleChannel.
  ///
  /// In en, this message translates to:
  /// **'Single Channel'**
  String get singleChannel;

  /// No description provided for @singleChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'One specific channel'**
  String get singleChannelDesc;

  /// No description provided for @customHopper.
  ///
  /// In en, this message translates to:
  /// **'Custom Hopper'**
  String get customHopper;

  /// No description provided for @customHopperDesc.
  ///
  /// In en, this message translates to:
  /// **'Custom range + step'**
  String get customHopperDesc;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// No description provided for @channelFreq.
  ///
  /// In en, this message translates to:
  /// **'Channel: {ch} ({freq} MHz)'**
  String channelFreq(int ch, int freq);

  /// No description provided for @hopperConfig.
  ///
  /// In en, this message translates to:
  /// **'Hopper Config'**
  String get hopperConfig;

  /// No description provided for @stopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopLabel;

  /// No description provided for @step.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get step;

  /// No description provided for @startJammer.
  ///
  /// In en, this message translates to:
  /// **'Start Jammer'**
  String get startJammer;

  /// No description provided for @stopJammer.
  ///
  /// In en, this message translates to:
  /// **'Stop Jammer'**
  String get stopJammer;

  /// No description provided for @deviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get deviceInfo;

  /// No description provided for @currentFirmware.
  ///
  /// In en, this message translates to:
  /// **'Current Firmware'**
  String get currentFirmware;

  /// No description provided for @freeHeapBytes.
  ///
  /// In en, this message translates to:
  /// **'{bytes} bytes'**
  String freeHeapBytes(int bytes);

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @firmwareUpdate.
  ///
  /// In en, this message translates to:
  /// **'Firmware Update'**
  String get firmwareUpdate;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest Version'**
  String get latestVersion;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'No (up to date)'**
  String get upToDate;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get checking;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading firmware...'**
  String get downloading;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete ({bytes} bytes)'**
  String downloadComplete(int bytes);

  /// No description provided for @noNewVersion.
  ///
  /// In en, this message translates to:
  /// **'No new version available.'**
  String get noNewVersion;

  /// No description provided for @apiError.
  ///
  /// In en, this message translates to:
  /// **'API Error'**
  String get apiError;

  /// No description provided for @otaTransfer.
  ///
  /// In en, this message translates to:
  /// **'OTA Transfer'**
  String get otaTransfer;

  /// No description provided for @sendingChunk.
  ///
  /// In en, this message translates to:
  /// **'Sending chunk {current}/{total}'**
  String sendingChunk(int current, int total);

  /// No description provided for @firmwareUploadedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Firmware uploaded successfully!'**
  String get firmwareUploadedSuccess;

  /// No description provided for @deviceWillVerify.
  ///
  /// In en, this message translates to:
  /// **'Device will verify and install the update.'**
  String get deviceWillVerify;

  /// No description provided for @firmwareReady.
  ///
  /// In en, this message translates to:
  /// **'Firmware ready: {bytes} bytes'**
  String firmwareReady(int bytes);

  /// No description provided for @startOtaUpdate.
  ///
  /// In en, this message translates to:
  /// **'Start OTA Update'**
  String get startOtaUpdate;

  /// No description provided for @otaTransferComplete.
  ///
  /// In en, this message translates to:
  /// **'OTA transfer complete! Device will reboot.'**
  String get otaTransferComplete;

  /// No description provided for @transferFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed: {error}'**
  String transferFailed(String error);

  /// No description provided for @md5Mismatch.
  ///
  /// In en, this message translates to:
  /// **'MD5 mismatch! File may be corrupted.'**
  String get md5Mismatch;

  /// No description provided for @debugModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Debug mode disabled'**
  String get debugModeDisabled;

  /// No description provided for @debugModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Debug mode enabled'**
  String get debugModeEnabled;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @disableDbg.
  ///
  /// In en, this message translates to:
  /// **'Disable DBG'**
  String get disableDbg;

  /// No description provided for @subGhzTab.
  ///
  /// In en, this message translates to:
  /// **'Sub-GHz'**
  String get subGhzTab;

  /// No description provided for @nrfTab.
  ///
  /// In en, this message translates to:
  /// **'NRF'**
  String get nrfTab;

  /// No description provided for @settingsSyncedWithDevice.
  ///
  /// In en, this message translates to:
  /// **'Settings synced with device'**
  String get settingsSyncedWithDevice;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @appSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, cache, permissions'**
  String get appSettingsSubtitle;

  /// No description provided for @rfSettings.
  ///
  /// In en, this message translates to:
  /// **'RF Settings'**
  String get rfSettings;

  /// No description provided for @syncedWithDevice.
  ///
  /// In en, this message translates to:
  /// **'Synced with device'**
  String get syncedWithDevice;

  /// No description provided for @localOnly.
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get localOnly;

  /// No description provided for @bruteforceSettings.
  ///
  /// In en, this message translates to:
  /// **'Bruteforce Settings'**
  String get bruteforceSettings;

  /// No description provided for @radioSettings.
  ///
  /// In en, this message translates to:
  /// **'Radio Settings'**
  String get radioSettings;

  /// No description provided for @scannerSettings.
  ///
  /// In en, this message translates to:
  /// **'Scanner Settings'**
  String get scannerSettings;

  /// No description provided for @interFrameDelay.
  ///
  /// In en, this message translates to:
  /// **'Inter-frame Delay: {ms} ms'**
  String interFrameDelay(int ms);

  /// No description provided for @delayBetweenTransmissions.
  ///
  /// In en, this message translates to:
  /// **'Delay between each RF transmission'**
  String get delayBetweenTransmissions;

  /// No description provided for @repeatsCount.
  ///
  /// In en, this message translates to:
  /// **'Repeats: {count}x'**
  String repeatsCount(int count);

  /// No description provided for @transmissionsPerCode.
  ///
  /// In en, this message translates to:
  /// **'Transmissions per code (1-10)'**
  String get transmissionsPerCode;

  /// No description provided for @txPowerLevel.
  ///
  /// In en, this message translates to:
  /// **'TX Power: Level {level}'**
  String txPowerLevel(int level);

  /// No description provided for @bruterTxPowerDesc.
  ///
  /// In en, this message translates to:
  /// **'Bruter transmission power (0=Min, 7=Max)'**
  String get bruterTxPowerDesc;

  /// No description provided for @txPowerInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'TX power in dBm. Higher = longer range but more interference. Default: +10 dBm.'**
  String get txPowerInfoDesc;

  /// No description provided for @rssiThreshold.
  ///
  /// In en, this message translates to:
  /// **'RSSI Threshold: {dbm} dBm'**
  String rssiThreshold(int dbm);

  /// No description provided for @minSignalStrengthDesc.
  ///
  /// In en, this message translates to:
  /// **'Minimum signal strength to detect (-120 to -20)'**
  String get minSignalStrengthDesc;

  /// No description provided for @nrf24Settings.
  ///
  /// In en, this message translates to:
  /// **'nRF24 Settings'**
  String get nrf24Settings;

  /// No description provided for @nrf24SettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PA level, data rate, channel'**
  String get nrf24SettingsSubtitle;

  /// No description provided for @nrf24ConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure the nRF24L01 radio module for MouseJack attacks, spectrum analysis, and jamming.'**
  String get nrf24ConfigDesc;

  /// No description provided for @paLevel.
  ///
  /// In en, this message translates to:
  /// **'PA Level: {level}'**
  String paLevel(String level);

  /// No description provided for @transmissionPowerDesc.
  ///
  /// In en, this message translates to:
  /// **'Transmission power (MIN → MAX)'**
  String get transmissionPowerDesc;

  /// No description provided for @nrfDataRate.
  ///
  /// In en, this message translates to:
  /// **'Data Rate: {rate}'**
  String nrfDataRate(String rate);

  /// No description provided for @radioDataRateDesc.
  ///
  /// In en, this message translates to:
  /// **'Radio data rate — lower = longer range'**
  String get radioDataRateDesc;

  /// No description provided for @defaultChannel.
  ///
  /// In en, this message translates to:
  /// **'Default Channel: {ch}'**
  String defaultChannel(int ch);

  /// No description provided for @autoRetransmit.
  ///
  /// In en, this message translates to:
  /// **'Auto-Retransmit: {count}x'**
  String autoRetransmit(int count);

  /// No description provided for @retransmitCountDesc.
  ///
  /// In en, this message translates to:
  /// **'Retransmit count on failure (0-15)'**
  String get retransmitCountDesc;

  /// No description provided for @sendToDevice.
  ///
  /// In en, this message translates to:
  /// **'Send to Device'**
  String get sendToDevice;

  /// No description provided for @connectToDeviceToApply.
  ///
  /// In en, this message translates to:
  /// **'Connect to device to apply'**
  String get connectToDeviceToApply;

  /// No description provided for @nrf24SettingsSent.
  ///
  /// In en, this message translates to:
  /// **'nRF24 settings sent to device'**
  String get nrf24SettingsSent;

  /// No description provided for @failedToSendNrf24Settings.
  ///
  /// In en, this message translates to:
  /// **'Failed to send nRF24 settings: {error}'**
  String failedToSendNrf24Settings(String error);

  /// No description provided for @hwButtons.
  ///
  /// In en, this message translates to:
  /// **'HW Buttons'**
  String get hwButtons;

  /// No description provided for @configureHwButtonActions.
  ///
  /// In en, this message translates to:
  /// **'Configure hardware button actions'**
  String get configureHwButtonActions;

  /// No description provided for @hwButtonsDesc.
  ///
  /// In en, this message translates to:
  /// **'Assign an action to each physical button on the device. Press \"Send to Device\" to apply.'**
  String get hwButtonsDesc;

  /// No description provided for @button1Gpio34.
  ///
  /// In en, this message translates to:
  /// **'Button 1 (GPIO34)'**
  String get button1Gpio34;

  /// No description provided for @button2Gpio35.
  ///
  /// In en, this message translates to:
  /// **'Button 2 (GPIO35)'**
  String get button2Gpio35;

  /// No description provided for @buttonConfigSent.
  ///
  /// In en, this message translates to:
  /// **'Button config sent to device'**
  String get buttonConfigSent;

  /// No description provided for @failedToSendConfig.
  ///
  /// In en, this message translates to:
  /// **'Failed to send config: {error}'**
  String failedToSendConfig(String error);

  /// No description provided for @firmwareInfo.
  ///
  /// In en, this message translates to:
  /// **'Firmware Info'**
  String get firmwareInfo;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version: v{version}'**
  String versionLabel(String version);

  /// No description provided for @fwVersionDetails.
  ///
  /// In en, this message translates to:
  /// **'Major: {major} | Minor: {minor} | Patch: {patch}'**
  String fwVersionDetails(int major, int minor, int patch);

  /// No description provided for @waitingForDeviceResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for device response...\nPlease try again in a moment.'**
  String get waitingForDeviceResponse;

  /// No description provided for @tapOtaUpdateDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap \"OTA Update\" below to check for updates and flash new firmware.'**
  String get tapOtaUpdateDesc;

  /// No description provided for @deviceFwVersion.
  ///
  /// In en, this message translates to:
  /// **'Device FW: v{version}'**
  String deviceFwVersion(String version);

  /// No description provided for @updateFirmwareDesc.
  ///
  /// In en, this message translates to:
  /// **'Update firmware via BLE OTA or check for new releases on GitHub.'**
  String get updateFirmwareDesc;

  /// No description provided for @checkFwVersion.
  ///
  /// In en, this message translates to:
  /// **'Check FW Version'**
  String get checkFwVersion;

  /// No description provided for @otaUpdate.
  ///
  /// In en, this message translates to:
  /// **'OTA Update'**
  String get otaUpdate;

  /// No description provided for @connectToADeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect to a device first'**
  String get connectToADeviceFirst;

  /// No description provided for @checkingForAppUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for app updates...'**
  String get checkingForAppUpdates;

  /// No description provided for @appUpToDate.
  ///
  /// In en, this message translates to:
  /// **'App is up to date (v{version})'**
  String appUpToDate(String version);

  /// No description provided for @appUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'App Update Available'**
  String get appUpdateAvailable;

  /// No description provided for @currentVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current: v{version}'**
  String currentVersionLabel(String version);

  /// No description provided for @latestVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest: v{version}'**
  String latestVersionLabel(String version);

  /// No description provided for @changelogLabel.
  ///
  /// In en, this message translates to:
  /// **'Changelog:'**
  String get changelogLabel;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @downloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download & Install'**
  String get downloadAndInstall;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckFailed(String error);

  /// No description provided for @downloadingApk.
  ///
  /// In en, this message translates to:
  /// **'Downloading APK...'**
  String get downloadingApk;

  /// No description provided for @apkSavedPleaseInstall.
  ///
  /// In en, this message translates to:
  /// **'APK saved to: {path}\nPlease install manually.'**
  String apkSavedPleaseInstall(String path);

  /// No description provided for @checkAppUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check App Update'**
  String get checkAppUpdate;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'EvilCrow RF V2'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Sub-GHz RF Security Tool'**
  String get appTagline;

  /// No description provided for @connectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// No description provided for @debugControls.
  ///
  /// In en, this message translates to:
  /// **'Debug Controls'**
  String get debugControls;

  /// No description provided for @clearCachedDevice.
  ///
  /// In en, this message translates to:
  /// **'Clear Cached Device'**
  String get clearCachedDevice;

  /// No description provided for @refreshFiles.
  ///
  /// In en, this message translates to:
  /// **'Refresh Files'**
  String get refreshFiles;

  /// No description provided for @activityLogs.
  ///
  /// In en, this message translates to:
  /// **'Activity Logs'**
  String get activityLogs;

  /// No description provided for @hideUnknown.
  ///
  /// In en, this message translates to:
  /// **'Hide Unknown'**
  String get hideUnknown;

  /// No description provided for @sdCard.
  ///
  /// In en, this message translates to:
  /// **'SD Card'**
  String get sdCard;

  /// No description provided for @internal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get internal;

  /// No description provided for @internalLittleFs.
  ///
  /// In en, this message translates to:
  /// **'Internal (LittleFS)'**
  String get internalLittleFs;

  /// No description provided for @directory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get directory;

  /// No description provided for @flashLocalBinary.
  ///
  /// In en, this message translates to:
  /// **'Flash Local Binary'**
  String get flashLocalBinary;

  /// No description provided for @selectBinFileDesc.
  ///
  /// In en, this message translates to:
  /// **'Select a .bin firmware file from your device to flash directly via BLE OTA.'**
  String get selectBinFileDesc;

  /// No description provided for @selectBin.
  ///
  /// In en, this message translates to:
  /// **'Select .bin'**
  String get selectBin;

  /// No description provided for @flash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get flash;

  /// No description provided for @fileLabel.
  ///
  /// In en, this message translates to:
  /// **'File: {path}'**
  String fileLabel(String path);

  /// No description provided for @localFirmwareUploaded.
  ///
  /// In en, this message translates to:
  /// **'Local firmware uploaded!'**
  String get localFirmwareUploaded;

  /// No description provided for @changelogVersion.
  ///
  /// In en, this message translates to:
  /// **'Changelog — v{version}'**
  String changelogVersion(String version);

  /// No description provided for @startingOtaTransfer.
  ///
  /// In en, this message translates to:
  /// **'Starting OTA transfer...'**
  String get startingOtaTransfer;

  /// No description provided for @frequencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Frequency is required'**
  String get frequencyRequired;

  /// No description provided for @invalidFrequencyFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid frequency format'**
  String get invalidFrequencyFormat;

  /// No description provided for @frequencyRangeError.
  ///
  /// In en, this message translates to:
  /// **'Frequency must be in range 300-348, 387-464, or 779-928 MHz'**
  String get frequencyRangeError;

  /// No description provided for @selectFrequency.
  ///
  /// In en, this message translates to:
  /// **'Select Frequency'**
  String get selectFrequency;

  /// No description provided for @invalidDataRateFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid data rate format'**
  String get invalidDataRateFormat;

  /// No description provided for @dataRateRangeError.
  ///
  /// In en, this message translates to:
  /// **'Data rate must be between {min} and {max} kBaud'**
  String dataRateRangeError(String min, String max);

  /// No description provided for @invalidDeviationFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid deviation format'**
  String get invalidDeviationFormat;

  /// No description provided for @deviationRangeError.
  ///
  /// In en, this message translates to:
  /// **'Deviation must be between {min} and {max} kHz'**
  String deviationRangeError(String min, String max);

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errors;

  /// No description provided for @noSignalDataToPreview.
  ///
  /// In en, this message translates to:
  /// **'No signal data to preview'**
  String get noSignalDataToPreview;

  /// No description provided for @signalPreview.
  ///
  /// In en, this message translates to:
  /// **'Signal Preview'**
  String get signalPreview;

  /// No description provided for @dataLength.
  ///
  /// In en, this message translates to:
  /// **'Data Length'**
  String get dataLength;

  /// No description provided for @sampleData.
  ///
  /// In en, this message translates to:
  /// **'Sample Data:'**
  String get sampleData;

  /// No description provided for @loadSignalFile.
  ///
  /// In en, this message translates to:
  /// **'Load Signal File'**
  String get loadSignalFile;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @formats.
  ///
  /// In en, this message translates to:
  /// **'Formats'**
  String get formats;

  /// No description provided for @supportedFormatsShort.
  ///
  /// In en, this message translates to:
  /// **'Supported formats: .sub (FlipperZero), .json (TUT)'**
  String get supportedFormatsShort;

  /// No description provided for @supportedFileFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported File Formats'**
  String get supportedFileFormats;

  /// No description provided for @readyToTransmit.
  ///
  /// In en, this message translates to:
  /// **'Ready to Transmit'**
  String get readyToTransmit;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{progress}% complete'**
  String percentComplete(int progress);

  /// No description provided for @validationErrors.
  ///
  /// In en, this message translates to:
  /// **'Validation Errors'**
  String get validationErrors;

  /// No description provided for @noTransmissionHistory.
  ///
  /// In en, this message translates to:
  /// **'No transmission history'**
  String get noTransmissionHistory;

  /// No description provided for @transmissionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transmission History'**
  String get transmissionHistory;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @goUp.
  ///
  /// In en, this message translates to:
  /// **'Go Up'**
  String get goUp;

  /// No description provided for @connectToDeviceToSeeFiles.
  ///
  /// In en, this message translates to:
  /// **'Connect to device to see files'**
  String get connectToDeviceToSeeFiles;

  /// No description provided for @noFilesAvailableForSelection.
  ///
  /// In en, this message translates to:
  /// **'No files available for selection'**
  String get noFilesAvailableForSelection;

  /// No description provided for @deselectFile.
  ///
  /// In en, this message translates to:
  /// **'Deselect file'**
  String get deselectFile;

  /// No description provided for @selectFileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get selectFileTooltip;

  /// No description provided for @saveToSignals.
  ///
  /// In en, this message translates to:
  /// **'Save to Signals'**
  String get saveToSignals;

  /// No description provided for @fullPath.
  ///
  /// In en, this message translates to:
  /// **'Full Path'**
  String get fullPath;

  /// No description provided for @downloadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Downloading files...'**
  String get downloadingFiles;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @root.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get root;

  /// No description provided for @noSubdirectories.
  ///
  /// In en, this message translates to:
  /// **'No subdirectories'**
  String get noSubdirectories;

  /// No description provided for @storageLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage: '**
  String get storageLabel;

  /// No description provided for @errorLoadingDirectories.
  ///
  /// In en, this message translates to:
  /// **'Error loading directories'**
  String get errorLoadingDirectories;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @settingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Settings not available'**
  String get settingsNotAvailable;

  /// No description provided for @playingFile.
  ///
  /// In en, this message translates to:
  /// **'Playing file: {filename}'**
  String playingFile(String filename);

  /// No description provided for @failedToSaveSignal.
  ///
  /// In en, this message translates to:
  /// **'Failed to save signal: {error}'**
  String failedToSaveSignal(String error);

  /// No description provided for @failedToDeleteFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file: {error}'**
  String failedToDeleteFile(String error);

  /// No description provided for @deletingFile.
  ///
  /// In en, this message translates to:
  /// **'Deleting file: {name}'**
  String deletingFile(String name);

  /// No description provided for @recordScreenHelpContent.
  ///
  /// In en, this message translates to:
  /// **'This screen allows you to record RF signals using the CC1101 modules.\n\n• Select a module tab to configure its settings\n• Tap Start Recording to begin capturing\n• Detected signals appear in real-time\n• Save captured signals with custom names\n• Play back or transmit saved recordings\n\nFor best results, place the antenna close to the transmitter.'**
  String get recordScreenHelpContent;

  /// No description provided for @frequencySearchStarted.
  ///
  /// In en, this message translates to:
  /// **'Frequency search started for Module {number}'**
  String frequencySearchStarted(int number);

  /// No description provided for @failedToStartFrequencySearch.
  ///
  /// In en, this message translates to:
  /// **'Failed to start frequency search: {error}'**
  String failedToStartFrequencySearch(String error);

  /// No description provided for @failedToStopFrequencySearch.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop frequency search: {error}'**
  String failedToStopFrequencySearch(String error);

  /// No description provided for @standingOnShoulders.
  ///
  /// In en, this message translates to:
  /// **'Standing on the shoulders of giants'**
  String get standingOnShoulders;

  /// No description provided for @githubProfile.
  ///
  /// In en, this message translates to:
  /// **'GitHub Profile'**
  String get githubProfile;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// No description provided for @sdrMode.
  ///
  /// In en, this message translates to:
  /// **'SDR MODE'**
  String get sdrMode;

  /// No description provided for @sdrModeActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Active — SubGhz ops blocked'**
  String get sdrModeActiveSubtitle;

  /// No description provided for @sdrModeInactiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CC1101 spectrum & raw RX via USB'**
  String get sdrModeInactiveSubtitle;

  /// No description provided for @sdrConnectViaUsb.
  ///
  /// In en, this message translates to:
  /// **'Connect via USB serial for SDR streaming.'**
  String get sdrConnectViaUsb;

  /// No description provided for @connectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedStatus;

  /// No description provided for @disconnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnectedStatus;

  /// No description provided for @testCommands.
  ///
  /// In en, this message translates to:
  /// **'Test Commands:'**
  String get testCommands;

  /// No description provided for @deviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device: {name}'**
  String deviceLabel(String name);

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String deviceIdLabel(String id);

  /// No description provided for @stateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get stateIdle;

  /// No description provided for @stateDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting'**
  String get stateDetecting;

  /// No description provided for @stateRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get stateRecording;

  /// No description provided for @stateTransmitting.
  ///
  /// In en, this message translates to:
  /// **'Transmitting'**
  String get stateTransmitting;

  /// No description provided for @stateUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get stateUnknown;

  /// No description provided for @nrf24Jamming.
  ///
  /// In en, this message translates to:
  /// **'NRF24: Jamming'**
  String get nrf24Jamming;

  /// No description provided for @nrf24Scanning.
  ///
  /// In en, this message translates to:
  /// **'NRF24: Scanning'**
  String get nrf24Scanning;

  /// No description provided for @nrf24Attacking.
  ///
  /// In en, this message translates to:
  /// **'NRF24: Attacking'**
  String get nrf24Attacking;

  /// No description provided for @nrf24SpectrumActive.
  ///
  /// In en, this message translates to:
  /// **'NRF24: Spectrum'**
  String get nrf24SpectrumActive;

  /// No description provided for @nrf24Idle.
  ///
  /// In en, this message translates to:
  /// **'NRF24: Idle'**
  String get nrf24Idle;

  /// No description provided for @batteryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Battery: {percentage}% ({volts} V){charging}'**
  String batteryTooltip(int percentage, String volts, String charging);

  /// No description provided for @specialThanks.
  ///
  /// In en, this message translates to:
  /// **'★ Special Thanks ★'**
  String get specialThanks;

  /// No description provided for @frequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequencyLabel;

  /// No description provided for @modulationLabel.
  ///
  /// In en, this message translates to:
  /// **'Modulation'**
  String get modulationLabel;

  /// No description provided for @dataRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Data Rate'**
  String get dataRateLabel;

  /// No description provided for @deviationLabel.
  ///
  /// In en, this message translates to:
  /// **'Deviation'**
  String get deviationLabel;

  /// No description provided for @dataLengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Data Length'**
  String get dataLengthLabel;

  /// No description provided for @flipperSubGhzFormat.
  ///
  /// In en, this message translates to:
  /// **'FlipperZero SubGhz (.sub)'**
  String get flipperSubGhzFormat;

  /// No description provided for @flipperSubGhzDetails.
  ///
  /// In en, this message translates to:
  /// **'• Raw signal data format\n• Used by Flipper Zero device\n• Contains frequency and modulation settings'**
  String get flipperSubGhzDetails;

  /// No description provided for @tutJsonFormat.
  ///
  /// In en, this message translates to:
  /// **'TUT JSON (.json)'**
  String get tutJsonFormat;

  /// No description provided for @tutJsonDetails.
  ///
  /// In en, this message translates to:
  /// **'• JSON format with signal parameters\n• Used by TUT (Test & Utility Tool)\n• Contains frequency, data rate, and raw data'**
  String get tutJsonDetails;

  /// No description provided for @sdCardPath.
  ///
  /// In en, this message translates to:
  /// **'SD Card: {path}'**
  String sdCardPath(String path);

  /// No description provided for @rfScanner.
  ///
  /// In en, this message translates to:
  /// **'RF Scanner'**
  String get rfScanner;

  /// No description provided for @moreSamples.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreSamples(int count);

  /// No description provided for @sampleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} samples'**
  String sampleCount(int count);

  /// No description provided for @transmitHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{time} • Module {moduleNumber} • {repeatCount} repeats'**
  String transmitHistorySubtitle(
      String time, int moduleNumber, int repeatCount);

  /// No description provided for @downloadingFile.
  ///
  /// In en, this message translates to:
  /// **'Downloading file: {name}'**
  String downloadingFile(String name);

  /// No description provided for @moduleStatus.
  ///
  /// In en, this message translates to:
  /// **'Module {number}: {mode}'**
  String moduleStatus(int number, String mode);

  /// No description provided for @transmittingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Transmitting...'**
  String get transmittingEllipsis;

  /// No description provided for @chargingIndicator.
  ///
  /// In en, this message translates to:
  /// **' ⚡ Charging'**
  String get chargingIndicator;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
