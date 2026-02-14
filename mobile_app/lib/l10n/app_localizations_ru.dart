// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Tut RF';

  @override
  String get home => 'Главная';

  @override
  String get brute => 'Брут';

  @override
  String get record => 'Запись';

  @override
  String get files => 'Файлы';

  @override
  String get settings => 'Настройки';

  @override
  String get connectionRequired => 'Требуется подключение';

  @override
  String get connectionRequiredMessage =>
      'Пожалуйста, сначала подключитесь к устройству для доступа к этой функции.';

  @override
  String get ok => 'ОК';

  @override
  String get permissionError => 'Ошибка разрешений';

  @override
  String get disconnected => 'Отключено';

  @override
  String connected(String deviceName) {
    return 'Подключено к $deviceName';
  }

  @override
  String get connecting => 'Подключение...';

  @override
  String get connectingToKnownDevice =>
      'Подключение к известному устройству...';

  @override
  String get scanningForDevice => 'Поиск устройства...';

  @override
  String get deviceNotFound =>
      'Устройство не найдено. Убедитесь, что оно включено и находится рядом.';

  @override
  String connectionError(String error) {
    return 'Ошибка подключения: $error';
  }

  @override
  String get bluetoothEnabled => 'Bluetooth включен';

  @override
  String get bluetoothDisabled => 'Bluetooth выключен';

  @override
  String get somePermissionsDenied =>
      'Некоторые разрешения отклонены. Bluetooth может работать неправильно.';

  @override
  String get allPermissionsGranted =>
      'Все разрешения предоставлены. Bluetooth готов к работе.';

  @override
  String get bluetoothScanPermissionsNotGranted =>
      'Разрешения на сканирование Bluetooth не предоставлены';

  @override
  String get scanningForDevices => 'Поиск устройств...';

  @override
  String foundSupportedDevices(int count) {
    return 'Найдено поддерживаемых устройств: $count. Нажмите для подключения.';
  }

  @override
  String get noSupportedDevicesFound =>
      'Поддерживаемые устройства не найдены. Убедитесь, что ESP32 включен и находится рядом.';

  @override
  String scanError(String error) {
    return 'Ошибка сканирования: $error';
  }

  @override
  String get scanStopped => 'Сканирование остановлено';

  @override
  String stopScanError(String error) {
    return 'Ошибка остановки сканирования: $error';
  }

  @override
  String get requiredCharacteristicsNotFound =>
      'Необходимые характеристики не найдены';

  @override
  String get requiredServiceNotFound => 'Необходимая служба не найдена';

  @override
  String get knownDeviceCleared =>
      'Известное устройство удалено. Следующее подключение будет искать устройства.';

  @override
  String get notConnected => 'Не подключено';

  @override
  String sendError(String error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String get commandTimeout =>
      'Превышено время ожидания команды - попробуйте снова';

  @override
  String get fileListLoadingTimeout =>
      'Превышено время ожидания загрузки списка файлов - попробуйте снова';

  @override
  String get transmittingSignal => 'Передача сигнала...';

  @override
  String transmissionFailed(String error) {
    return 'Ошибка передачи: $error';
  }

  @override
  String get disconnect => 'Отключить';

  @override
  String get connect => 'Подключить';

  @override
  String get scanForNewDevices => 'Искать новые устройства';

  @override
  String get scanForDevices => 'Искать устройства';

  @override
  String get scanAgain => 'Искать снова';

  @override
  String foundSupportedDevicesCount(int count) {
    return 'Найдено поддерживаемых устройств: $count';
  }

  @override
  String get unknownDevice => 'Неизвестное устройство';

  @override
  String get notConnectedToDevice => 'Не подключено к устройству';

  @override
  String get connectToDeviceToManageFiles =>
      'Подключитесь к устройству для управления файлами';

  @override
  String get refresh => 'Обновить';

  @override
  String get stopLoading => 'Остановить загрузку';

  @override
  String get createDirectory => 'Создать папку';

  @override
  String get uploadFile => 'Загрузить файл';

  @override
  String get exitMultiSelect => 'Выйти из режима выбора';

  @override
  String get multiSelect => 'Множественный выбор';

  @override
  String get directoryName => 'Имя папки';

  @override
  String get enterDirectoryName => 'Введите имя папки';

  @override
  String get create => 'Создать';

  @override
  String get cancel => 'Отмена';

  @override
  String get copyFile => 'Копировать файл';

  @override
  String get newFileName => 'Новое имя файла';

  @override
  String destination(String path) {
    return 'Назначение: $path';
  }

  @override
  String get copy => 'Копировать';

  @override
  String get renameDirectory => 'Переименовать папку';

  @override
  String get renameFile => 'Переименовать файл';

  @override
  String get newDirectoryName => 'Новое имя папки';

  @override
  String get rename => 'Переименовать';

  @override
  String get deleteDirectory => 'Удалить папку';

  @override
  String get deleteFile => 'Удалить файл';

  @override
  String deleteConfirm(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?';
  }

  @override
  String get delete => 'Удалить';

  @override
  String get deleteFiles => 'Удалить файлы';

  @override
  String deleteFilesConfirm(int count) {
    return 'Вы уверены, что хотите удалить $count файлов?';
  }

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get clearSelection => 'Очистить выбор';

  @override
  String get deleteSelected => 'Удалить выбранное';

  @override
  String get moveDirectory => 'Переместить папку';

  @override
  String get moveFile => 'Переместить файл';

  @override
  String get move => 'Переместить';

  @override
  String get records => 'Записи';

  @override
  String get signals => 'Сигналы';

  @override
  String get captured => 'Захвачено';

  @override
  String get presets => 'Пресеты';

  @override
  String get temp => 'Временные';

  @override
  String get saveFileAs => 'Сохранить файл как...';

  @override
  String fileSaved(String path) {
    return 'Файл сохранен: $path';
  }

  @override
  String get fileContentCopiedToClipboard =>
      'Содержимое файла скопировано в буфер обмена';

  @override
  String fileSavedToDocuments(String path) {
    return 'Файл сохранен в Документы: $path';
  }

  @override
  String couldNotSaveFile(String error) {
    return 'Не удалось сохранить файл. Содержимое скопировано в буфер обмена. Ошибка: $error';
  }

  @override
  String downloadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get downloadFailedNoContent =>
      'Ошибка загрузки: Содержимое не получено';

  @override
  String fileCopied(String name) {
    return 'Файл скопирован: $name';
  }

  @override
  String copyFailed(String error) {
    return 'Ошибка копирования: $error';
  }

  @override
  String directoryRenamed(String name) {
    return 'Папка переименована: $name';
  }

  @override
  String fileRenamed(String name) {
    return 'Файл переименован: $name';
  }

  @override
  String renameFailed(String error) {
    return 'Ошибка переименования: $error';
  }

  @override
  String directoryDeleted(String name) {
    return 'Папка удалена: $name';
  }

  @override
  String fileDeleted(String name) {
    return 'Файл удален: $name';
  }

  @override
  String deleteFailed(String error) {
    return 'Ошибка удаления: $error';
  }

  @override
  String deletedFilesCount(int count, String extra) {
    return 'Удалено файлов: $count$extra';
  }

  @override
  String get failed => 'ошибок';

  @override
  String directoryMoved(String name) {
    return 'Папка перемещена: $name';
  }

  @override
  String fileMoved(String name) {
    return 'Файл перемещен: $name';
  }

  @override
  String moveFailed(String error) {
    return 'Ошибка перемещения: $error';
  }

  @override
  String directoryCreated(String name) {
    return 'Папка создана: $name';
  }

  @override
  String failedToCreateDirectory(String error) {
    return 'Не удалось создать папку: $error';
  }

  @override
  String uploadingFile(String fileName) {
    return 'Загрузка $fileName...';
  }

  @override
  String fileUploaded(String fileName) {
    return 'Файл загружен: $fileName';
  }

  @override
  String uploadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get selectedFileDoesNotExist => 'Выбранный файл не существует';

  @override
  String get uploadError => 'Ошибка загрузки';

  @override
  String failedToPickFile(String error) {
    return 'Не удалось выбрать файл: $error';
  }

  @override
  String get noLogsYet => 'Логов пока нет';

  @override
  String get commandsAndResponsesWillAppearHere =>
      'Команды и ответы будут отображаться здесь';

  @override
  String logsCount(int count) {
    return 'Логи ($count)';
  }

  @override
  String get clearAllLogs => 'Очистить все логи';

  @override
  String get loadingFilePreview => 'Загрузка preview файла...';

  @override
  String get previewError => 'Ошибка предпросмотра';

  @override
  String get retry => 'Повторить';

  @override
  String chars(int count) {
    return '$count символов';
  }

  @override
  String get previewTruncated =>
      'Предпросмотр обрезан. Откройте файл, чтобы увидеть полное содержимое.';

  @override
  String get clearFileCache => 'Очистить кеш файлов';

  @override
  String get rebootDevice => 'Перезагрузить';

  @override
  String get requestPermissions => 'Запросить разрешения';

  @override
  String get sendCommand => 'Отправить команду';

  @override
  String get enterCommand => 'Введите команду';

  @override
  String get commandHint => 'например, SCAN, RECORD, PLAY';

  @override
  String get send => 'Отправить';

  @override
  String get scanner => 'Сканер';

  @override
  String get clearList => 'Очистить список';

  @override
  String get stop => 'Стоп';

  @override
  String get start => 'Старт';

  @override
  String get language => 'Язык';

  @override
  String get selectLanguage => 'Выберите язык';

  @override
  String get english => 'English';

  @override
  String get russian => 'Русский';

  @override
  String get systemDefault => 'По умолчанию системы';

  @override
  String get deviceStatus => 'Статус устройства';

  @override
  String subGhzModule(int number) {
    return 'Sub-GHz Модуль $number';
  }

  @override
  String connectedToDevice(String deviceName) {
    return 'Подключено: $deviceName';
  }

  @override
  String get sdCardReady => 'SD карта готова';

  @override
  String freeHeap(String kb) {
    return 'Свободная память';
  }

  @override
  String get notifications => 'Уведомления';

  @override
  String get noNotifications => 'Нет уведомлений';

  @override
  String get clearAll => 'Очистить все';

  @override
  String get justNow => 'Только что';

  @override
  String get minutesAgo => ' мин назад';

  @override
  String get hoursAgo => ' ч назад';

  @override
  String get daysAgo => ' дн назад';

  @override
  String get frequency => 'Частота';

  @override
  String get modulation => 'Манипуляция';

  @override
  String get dataRate => 'Скорость передачи данных';

  @override
  String get bandwidth => 'Полоса пропускания';

  @override
  String get deviation => 'Отклонение';

  @override
  String get rxBandwidth => 'Полоса пропускания RX';

  @override
  String get protocol => 'Протокол';

  @override
  String get preset => 'Пресет';

  @override
  String get signalName => 'Имя сигнала';

  @override
  String get settingsParseError => 'Ошибка разбора настроек';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get idle => 'Ожидание';

  @override
  String get detecting => 'Обнаружение';

  @override
  String get recording => 'Запись';

  @override
  String get jamming => 'Глушение';

  @override
  String get jammingSettings => 'Настройки глушения';

  @override
  String get transmitting => 'Передача';

  @override
  String get scanning => 'Сканирование';

  @override
  String get statusIdle => 'Бездействие';

  @override
  String get statusRecording => 'Запись';

  @override
  String get statusScanning => 'Сканирование';

  @override
  String get statusTransmitting => 'Отправка';

  @override
  String get kbps => 'кбит/с';

  @override
  String get hz => 'Гц';

  @override
  String get modulationAskOok => 'ASK/OOK (АМн-ВВ)';

  @override
  String get modulation2Fsk => '2-FSK (ЧМн-2)';

  @override
  String get modulation4Fsk => '4-FSK (ЧМн-4)';

  @override
  String get modulationGfsk => 'GFSK (ГЧМн)';

  @override
  String get modulationMsk => 'MSK (ММн)';

  @override
  String get startRecordingToCaptureSignals =>
      'Начните запись для захвата сигналов';

  @override
  String frequencySearchStoppedForModule(int number) {
    return 'Поиск частоты остановлен для Модуля $number';
  }

  @override
  String get error => 'Ошибка';

  @override
  String get deviceNotConnected => 'Устройство не подключено';

  @override
  String get moduleBusy => 'Модуль занят';

  @override
  String moduleBusyMessage(int number, String mode) {
    return 'Модуль $number сейчас в режиме \"$mode\".\\nДождитесь завершения текущей операции или переведите модуль в режим Ожидание.';
  }

  @override
  String get validationError => 'Ошибка валидации';

  @override
  String recordingStarted(int number) {
    return 'Запись начата на Модуле №$number';
  }

  @override
  String get recordingError => 'Ошибка записи';

  @override
  String recordingStartFailed(String error) {
    return 'Не удалось начать запись: $error';
  }

  @override
  String recordingStopped(int number) {
    return 'Запись остановлена на Модуле №$number';
  }

  @override
  String recordingStopFailed(String error) {
    return 'Не удалось остановить запись: $error';
  }

  @override
  String module(int number) {
    return 'Модуль $number';
  }

  @override
  String get startRecording => 'Начать запись';

  @override
  String get stopRecording => 'Остановить запись';

  @override
  String get advanced => 'Расширенные';

  @override
  String get startJamming => 'Начать глушение';

  @override
  String get stopJamming => 'Остановить глушение';

  @override
  String jammingStarted(int module) {
    return 'Глушение запущено на Модуле №$module';
  }

  @override
  String jammingStopped(int module) {
    return 'Глушение остановлено на Модуле №$module';
  }

  @override
  String get jammingError => 'Ошибка глушения';

  @override
  String jammingStartFailed(String error) {
    return 'Не удалось запустить глушение: $error';
  }

  @override
  String jammingStopFailed(String error) {
    return 'Не удалось остановить глушение: $error';
  }

  @override
  String get stopFrequencySearch => 'Остановить поиск частоты';

  @override
  String get searchForFrequency => 'Искать частоту';

  @override
  String signalsCaptured(Object count, Object number) {
    return 'Сигналов захвачено на Модуле №$number: $count';
  }

  @override
  String get recordedFiles => 'Записанные файлы';

  @override
  String get saveSignal => 'Сохранить сигнал';

  @override
  String get enterSignalName => 'Введите имя для сигнала:';

  @override
  String get deleteSignal => 'Удалить сигнал';

  @override
  String deleteSignalConfirm(String filename) {
    return 'Вы уверены, что хотите удалить \"$filename\"?\\n\\nЭто действие нельзя отменить.';
  }

  @override
  String get recordScreenHelp => 'Справка по экрану записи';

  @override
  String fileDownloadedSuccessfully(String fileName) {
    return 'Файл \"$fileName\" успешно загружен';
  }

  @override
  String get imagePreviewNotSupported =>
      'Предпросмотр изображений пока не поддерживается';

  @override
  String get viewAsText => 'Просмотр как текст';

  @override
  String get failedToParseFile => 'Не удалось разобрать файл';

  @override
  String get signalParameters => 'Параметры сигнала';

  @override
  String get signalData => 'Данные сигнала';

  @override
  String get samplesCount => 'Количество сэмплов';

  @override
  String get rawData => 'Необработанные данные:';

  @override
  String get binaryData => 'Двоичные данные:';

  @override
  String get warnings => 'Предупреждения';

  @override
  String get noContentAvailable => 'Содержимое недоступно';

  @override
  String get copyToClipboard => 'Копировать в буфер обмена';

  @override
  String get downloadFile => 'Загрузить файл';

  @override
  String get transmitSignal => 'Передать сигнал';

  @override
  String get reload => 'Перезагрузить';

  @override
  String get parsed => 'Разобрано';

  @override
  String get raw => 'Исходный';

  @override
  String get loadingFile => 'Загрузка файла...';

  @override
  String get notConnectedToDeviceFile => 'Не подключено к устройству';

  @override
  String get connectToDeviceToViewFiles =>
      'Подключитесь к устройству для просмотра файлов';

  @override
  String get transmitSignalConfirm => 'Это передаст сигнал из этого файла.';

  @override
  String get file => 'Файл';

  @override
  String get transmitWarning =>
      'Используйте только в контролируемых условиях. Проверьте местные правила.';

  @override
  String get dontShowAgain => 'Больше не показывать';

  @override
  String get resetTransmitConfirmation => 'Сбросить подтверждение передачи';

  @override
  String get transmitConfirmationReset =>
      'Диалог подтверждения передачи сброшен.';

  @override
  String get transmit => 'Передать';

  @override
  String signalTransmissionStarted(String fileName) {
    return 'Передача сигнала начата: $fileName';
  }

  @override
  String transmissionError(String error) {
    return 'Ошибка передачи: $error';
  }

  @override
  String get view => 'Просмотр';

  @override
  String get save => 'Сохранить';

  @override
  String get loadingFiles => 'Загрузка...';

  @override
  String get noRecordedFiles => 'Нет записанных файлов';

  @override
  String get noFilesFound => 'Файлы не найдены';

  @override
  String get recordSettings => 'Настройки записи';

  @override
  String get mhz => 'МГц';

  @override
  String get khz => 'кГц';

  @override
  String get kbaud => 'кБод';

  @override
  String signalSavedAs(String fileName) {
    return 'Сигнал сохранён как: $fileName';
  }

  @override
  String transmittingFile(String fileName) {
    return 'Передача сигнала из файла: $fileName';
  }

  @override
  String get recordingShort => 'Запись';

  @override
  String get freqShort => 'Част';

  @override
  String get modShort => 'Мод';

  @override
  String get rateShort => 'Скорость';

  @override
  String get bwShort => 'Полоса';

  @override
  String get clearDeviceCache => 'Очистить кеш устройств';

  @override
  String get clearDeviceCacheDescription =>
      'Удалить сохранённую информацию об устройствах';

  @override
  String filesLoadedCount(int loaded, int total) {
    return 'Загружено файлов: $loaded из $total';
  }

  @override
  String filesInDirectory(int count) {
    return 'Файлов в директории: $count';
  }

  @override
  String get noFiles => 'Нет файлов';

  @override
  String get searchProtocols => 'Поиск протоколов...';

  @override
  String get attackMode => 'Режим атаки:';

  @override
  String get standardMode => 'Стандарт';

  @override
  String get deBruijnMode => 'Де Брёйн';

  @override
  String get noProtocolsFound => 'Протоколы не найдены';

  @override
  String pausedProtocol(String name) {
    return 'Пауза: $name';
  }

  @override
  String bruteForceRunning(String name) {
    return 'Брутфорс запущен: $name';
  }

  @override
  String get bruteResume => 'ПРОДОЛЖ.';

  @override
  String get brutePause => 'ПАУЗА';

  @override
  String get bruteStop => 'СТОП';

  @override
  String get resumeInfo =>
      'При продолжении будут переотправлены 5 кодов перед точкой паузы.';

  @override
  String get startBruteForce => 'Запустить брутфорс';

  @override
  String startBruteForceSuffix(String suffix) {
    return 'Запустить брутфорс$suffix';
  }

  @override
  String get keySpace => 'Пространство ключей';

  @override
  String get delay => 'Задержка';

  @override
  String get estTime => 'Прим. время';

  @override
  String largeKeyspaceWarning(int bits, String time) {
    return '$bits-битное пространство ключей очень велико. Полное сканирование может занять $time.';
  }

  @override
  String get deviceWillTransmit =>
      'Устройство начнёт передачу. Вы можете остановить в любой момент.';

  @override
  String bruteForceStarted(String name) {
    return 'Брутфорс запущен: $name';
  }

  @override
  String failedToStart(String error) {
    return 'Не удалось запустить: $error';
  }

  @override
  String get bruteForcePausing => 'Приостановка брутфорса...';

  @override
  String failedToPause(String error) {
    return 'Не удалось приостановить: $error';
  }

  @override
  String get bruteForceResumed => 'Брутфорс возобновлён';

  @override
  String failedToResume(String error) {
    return 'Не удалось возобновить: $error';
  }

  @override
  String get savedStateDiscarded => 'Сохранённое состояние брутера сброшено';

  @override
  String failedToDiscard(String error) {
    return 'Не удалось сбросить состояние: $error';
  }

  @override
  String get bruteForceStopped => 'Брутфорс остановлен';

  @override
  String failedToStop(String error) {
    return 'Не удалось остановить: $error';
  }

  @override
  String bruteForceCompleted(String name) {
    return 'Брутфорс завершён: $name';
  }

  @override
  String bruteForceCancelled(String name) {
    return 'Брутфорс отменён: $name';
  }

  @override
  String bruteForceErrorMsg(String name) {
    return 'Ошибка брутфорса: $name';
  }

  @override
  String get deBruijnCompatible => 'Де Брёйн ✓';

  @override
  String get deBruijnTooltip =>
      'Последовательности Де Брёйна покрывают все n-битные комбинации в одном непрерывном потоке — ~90x быстрее';

  @override
  String get deBruijnFaster => 'Де Брёйн (~в 90 раз быстрее)';

  @override
  String get modeLabel => 'Режим';

  @override
  String get moduleLabel => 'Модуль:';

  @override
  String get cc1101Module1 => 'CC1101-1';

  @override
  String get cc1101Module2 => 'CC1101-2';

  @override
  String get rssiLabel => 'RSSI:';

  @override
  String get scanningActive => 'Сканирование активно';

  @override
  String get scanningStopped => 'Сканирование остановлено';

  @override
  String get signalList => 'Список сигналов';

  @override
  String get spectrogramView => 'Спектрограмма';

  @override
  String get searchingForSignals => 'Поиск сигналов...';

  @override
  String get pressStartToScan => 'Нажмите Старт для начала сканирования';

  @override
  String get signalSpectrogram => 'Спектрограмма сигнала';

  @override
  String get signalStrengthStrong => 'Сильный';

  @override
  String get signalStrengthMedium => 'Средний';

  @override
  String get signalStrengthWeak => 'Слабый';

  @override
  String get signalStrengthNone => 'Нет';

  @override
  String errorStartingScan(String error) {
    return 'Ошибка запуска сканирования: $error';
  }

  @override
  String errorStoppingScan(String error) {
    return 'Ошибка остановки сканирования: $error';
  }

  @override
  String get transmitSettings => 'Настройки передачи';

  @override
  String get advancedMode => 'Расширенный режим';

  @override
  String get manualConfiguration => 'Ручная настройка';

  @override
  String get usePresets => 'Использовать пресеты';

  @override
  String get transmitData => 'Данные для передачи';

  @override
  String get rawDataLabel => 'Исходные данные';

  @override
  String get rawDataHint => 'Введите данные сигнала (напр., 100 200 300 400)';

  @override
  String get repeatCount => 'Число повторов';

  @override
  String get repeatCountHint => '1-100';

  @override
  String get loadFile => 'Загрузить файл';

  @override
  String get transmitScreenHelp => 'Справка по экрану передачи';

  @override
  String get transmitScreenHelpContent =>
      'Этот экран позволяет передавать RF-сигналы через модули CC1101.\n\n• Выберите вкладку модуля для настройки\n• Переключайтесь между простым и расширенным режимами\n• Простой режим использует пресеты для быстрой настройки\n• Расширенный режим позволяет точную настройку параметров\n• Введите данные сигнала в текстовое поле\n• Установите число повторов (1-100)\n• Используйте «Загрузить файл» для загрузки данных из файла\n• Нажмите «Передать сигнал» для начала передачи\n\nУбедитесь, что устройство подключено перед передачей.';

  @override
  String statusLabelWithMode(String mode) {
    return 'Статус: $mode';
  }

  @override
  String get connectionConnected => 'Подключено';

  @override
  String get connectionDisconnected => 'Отключено';

  @override
  String connectionLabelWithStatus(String status) {
    return 'Подключение: $status';
  }

  @override
  String transmissionStartedOnModule(int number) {
    return 'Передача начата на Модуле №$number';
  }

  @override
  String failedToStartTransmission(String error) {
    return 'Не удалось начать передачу: $error';
  }

  @override
  String get featureInDevelopment => 'Функция в разработке';

  @override
  String get fileSelectionLater => 'Выбор файлов будет добавлен позже';

  @override
  String moduleBusyTransmitMessage(int number, String mode) {
    return 'Модуль $number сейчас в режиме \"$mode\".\nДождитесь завершения текущей операции или переведите модуль в режим Ожидание.';
  }

  @override
  String invalidFrequencyClosest(String freq, String closest) {
    return 'Некорректная частота $freq МГц. Ближайшая допустимая: $closest МГц';
  }

  @override
  String invalidFrequencySimple(String freq) {
    return 'Некорректная частота $freq МГц';
  }

  @override
  String invalidModuleNumber(int number) {
    return 'Некорректный номер модуля: $number';
  }

  @override
  String get rawDataRequired => 'Данные сигнала обязательны для передачи';

  @override
  String get repeatCountRange => 'Число повторов должно быть от 1 до 100';

  @override
  String invalidDataRateValue(String rate) {
    return 'Некорректная скорость передачи $rate кБод';
  }

  @override
  String invalidDeviationValue(String value) {
    return 'Некорректное отклонение $value кГц';
  }

  @override
  String get transmissionErrorLabel => 'Ошибка передачи';

  @override
  String get allCategory => 'Все';

  @override
  String get nrfModule => 'Модуль nRF24L01';

  @override
  String get nrfSubtitle => 'MouseJack / Спектр / Глушилка';

  @override
  String get nrfInitialize => 'Инициализировать NRF24';

  @override
  String get nrfNotDetected => 'Модуль nRF24L01 не обнаружен';

  @override
  String get connectToDeviceFirst => 'Сначала подключитесь к устройству';

  @override
  String get mouseJack => 'MouseJack';

  @override
  String get spectrum => 'Спектр';

  @override
  String get jammer => 'Глушилка';

  @override
  String get scan => 'Сканирование';

  @override
  String get startScan => 'Начать сканирование';

  @override
  String get stopScan => 'Остановить сканирование';

  @override
  String get refreshTargets => 'Обновить цели';

  @override
  String targetsCount(int count) {
    return 'Цели ($count)';
  }

  @override
  String get noDevicesFoundYet => 'Устройства пока не найдены';

  @override
  String get attack => 'Атака';

  @override
  String get injectText => 'Отправить текст';

  @override
  String get textToInject => 'Текст для отправки...';

  @override
  String get duckyScript => 'DuckyScript';

  @override
  String get duckyPathHint => '/DATA/DUCKY/payload.txt';

  @override
  String get run => 'Запуск';

  @override
  String get stopAttack => 'Остановить атаку';

  @override
  String get startAnalyzer => 'Запустить анализатор';

  @override
  String channelLabel(int ch) {
    return 'CH $ch';
  }

  @override
  String get jammerDisclaimer =>
      'Только для образовательных целей. Глушение может быть незаконным.';

  @override
  String get mode => 'Режим';

  @override
  String get fullSpectrum => 'Полный спектр';

  @override
  String get fullSpectrumDesc => '1-124 канала';

  @override
  String get wifiMode => 'WiFi';

  @override
  String get wifiModeDesc => 'Каналы WiFi 2.4 ГГц';

  @override
  String get bleMode => 'BLE';

  @override
  String get bleModeDesc => 'Каналы данных BLE';

  @override
  String get bleAdvertising => 'BLE реклама';

  @override
  String get bleAdvertisingDesc => 'Рекламные каналы BLE';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get bluetoothDesc => 'Классические каналы BT';

  @override
  String get usbWireless => 'USB беспроводной';

  @override
  String get usbWirelessDesc => 'Каналы USB беспроводных';

  @override
  String get videoStreaming => 'Видеопоток';

  @override
  String get videoStreamingDesc => 'Видео каналы';

  @override
  String get rcControllers => 'RC контроллеры';

  @override
  String get rcControllersDesc => 'Каналы RC';

  @override
  String get singleChannel => 'Один канал';

  @override
  String get singleChannelDesc => 'Один конкретный канал';

  @override
  String get customHopper => 'Свой хоппер';

  @override
  String get customHopperDesc => 'Диапазон + шаг';

  @override
  String get channel => 'Канал';

  @override
  String channelFreq(int ch, int freq) {
    return 'Канал: $ch ($freq МГц)';
  }

  @override
  String get hopperConfig => 'Настройки хоппера';

  @override
  String get stopLabel => 'Стоп';

  @override
  String get step => 'Шаг';

  @override
  String get startJammer => 'Запустить глушилку';

  @override
  String get stopJammer => 'Остановить глушилку';

  @override
  String get deviceInfo => 'Информация';

  @override
  String get currentFirmware => 'Текущая прошивка';

  @override
  String freeHeapBytes(int bytes) {
    return '$bytes байт';
  }

  @override
  String get connection => 'Подключение';

  @override
  String get firmwareUpdate => 'Обновление прошивки';

  @override
  String get latestVersion => 'Последняя версия';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String get upToDate => 'Нет (актуальная)';

  @override
  String get yes => 'Да';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get checking => 'Проверка...';

  @override
  String get download => 'Скачать';

  @override
  String get downloading => 'Загрузка прошивки...';

  @override
  String downloadComplete(int bytes) {
    return 'Загрузка завершена ($bytes байт)';
  }

  @override
  String get noNewVersion => 'Новых версий нет.';

  @override
  String get apiError => 'Ошибка API';

  @override
  String get otaTransfer => 'OTA передача';

  @override
  String sendingChunk(int current, int total) {
    return 'Отправка блока $current/$total';
  }

  @override
  String get firmwareUploadedSuccess => 'Прошивка загружена успешно!';

  @override
  String get deviceWillVerify => 'Устройство проверит и установит обновление.';

  @override
  String firmwareReady(int bytes) {
    return 'Прошивка готова: $bytes байт';
  }

  @override
  String get startOtaUpdate => 'Начать OTA обновление';

  @override
  String get otaTransferComplete =>
      'OTA передача завершена! Устройство перезагрузится.';

  @override
  String transferFailed(String error) {
    return 'Ошибка передачи: $error';
  }

  @override
  String get md5Mismatch => 'Несовпадение MD5! Файл повреждён.';

  @override
  String get debugModeDisabled => 'Режим отладки отключён';

  @override
  String get debugModeEnabled => 'Режим отладки включён';

  @override
  String get debug => 'Отладка';

  @override
  String get disableDbg => 'Отключить DBG';

  @override
  String get subGhzTab => 'Sub-GHz';

  @override
  String get nrfTab => 'NRF';

  @override
  String get settingsSyncedWithDevice =>
      'Настройки синхронизированы с устройством';

  @override
  String get appSettings => 'Настройки приложения';

  @override
  String get appSettingsSubtitle => 'Язык, кэш, разрешения';

  @override
  String get rfSettings => 'Настройки RF';

  @override
  String get rfSettingsSubtitle => 'Брутфорс, радио и сканер';

  @override
  String get syncedWithDevice => 'Синхронизировано с устройством';

  @override
  String get localOnly => 'Только локально';

  @override
  String get bruteforceSettings => 'Настройки брутфорса';

  @override
  String get radioSettings => 'Настройки радио';

  @override
  String get scannerSettings => 'Настройки сканера';

  @override
  String interFrameDelay(int ms) {
    return 'Задержка: $ms мс';
  }

  @override
  String get delayBetweenTransmissions => 'Задержка между передачами RF';

  @override
  String repeatsCount(int count) {
    return 'Повторы: ${count}x';
  }

  @override
  String get transmissionsPerCode => 'Передач на код (1-10)';

  @override
  String txPowerLevel(int level) {
    return 'Мощность TX: Уровень $level';
  }

  @override
  String get bruterTxPowerDesc => 'Мощность передачи брутера (0=Мин, 7=Макс)';

  @override
  String get txPowerInfoDesc =>
      'Мощность TX в дБм. Больше = дальше, но больше помех. По умолчанию: +10 дБм.';

  @override
  String rssiThreshold(int dbm) {
    return 'Порог RSSI: $dbm дБм';
  }

  @override
  String get minSignalStrengthDesc =>
      'Минимальная сила сигнала для обнаружения (от -120 до -20)';

  @override
  String get nrf24Settings => 'Настройки nRF24';

  @override
  String get nrf24SettingsSubtitle => 'PA уровень, скорость, канал';

  @override
  String get nrf24ConfigDesc =>
      'Конфигурация модуля nRF24L01 для атак MouseJack, анализа спектра и глушения.';

  @override
  String paLevel(String level) {
    return 'Уровень PA: $level';
  }

  @override
  String get transmissionPowerDesc => 'Мощность передачи (MIN → MAX)';

  @override
  String nrfDataRate(String rate) {
    return 'Скорость: $rate';
  }

  @override
  String get radioDataRateDesc => 'Скорость данных — ниже = дальше';

  @override
  String defaultChannel(int ch) {
    return 'Канал по умолчанию: $ch';
  }

  @override
  String autoRetransmit(int count) {
    return 'Авто-повтор: ${count}x';
  }

  @override
  String get retransmitCountDesc =>
      'Количество повторных передач при ошибке (0-15)';

  @override
  String get sendToDevice => 'Отправить на устройство';

  @override
  String get connectToDeviceToApply =>
      'Подключитесь к устройству для применения';

  @override
  String get nrf24SettingsSent => 'Настройки nRF24 отправлены';

  @override
  String failedToSendNrf24Settings(String error) {
    return 'Не удалось отправить настройки nRF24: $error';
  }

  @override
  String get hwButtons => 'Кнопки';

  @override
  String get configureHwButtonActions => 'Настроить действия кнопок';

  @override
  String get hwButtonsDesc =>
      'Назначьте действие каждой кнопке устройства. Нажмите «Отправить» для применения.';

  @override
  String get button1Gpio34 => 'Кнопка 1 (GPIO34)';

  @override
  String get button2Gpio35 => 'Кнопка 2 (GPIO35)';

  @override
  String get buttonConfigSent => 'Конфигурация кнопок отправлена';

  @override
  String failedToSendConfig(String error) {
    return 'Не удалось отправить конфигурацию: $error';
  }

  @override
  String get firmwareInfo => 'Информация о прошивке';

  @override
  String versionLabel(String version) {
    return 'Версия: v$version';
  }

  @override
  String fwVersionDetails(int major, int minor, int patch) {
    return 'Мажорная: $major | Минорная: $minor | Патч: $patch';
  }

  @override
  String get waitingForDeviceResponse =>
      'Ожидание ответа устройства...\nПопробуйте снова через мгновение.';

  @override
  String get tapOtaUpdateDesc =>
      'Нажмите «OTA обновление» для проверки обновлений и прошивки.';

  @override
  String deviceFwVersion(String version) {
    return 'Прошивка: v$version';
  }

  @override
  String get updateFirmwareDesc =>
      'Обновление прошивки через BLE OTA или проверка новых версий на GitHub.';

  @override
  String get checkFwVersion => 'Проверить версию';

  @override
  String get otaUpdate => 'OTA обновление';

  @override
  String get connectToADeviceFirst => 'Сначала подключите устройство';

  @override
  String get checkingForAppUpdates => 'Проверка обновлений приложения...';

  @override
  String appUpToDate(String version) {
    return 'Приложение обновлено (v$version)';
  }

  @override
  String get appUpdateAvailable => 'Доступно обновление';

  @override
  String currentVersionLabel(String version) {
    return 'Текущая: v$version';
  }

  @override
  String latestVersionLabel(String version) {
    return 'Новая: v$version';
  }

  @override
  String get changelogLabel => 'Список изменений:';

  @override
  String get later => 'Позже';

  @override
  String get downloadAndInstall => 'Скачать и установить';

  @override
  String updateCheckFailed(String error) {
    return 'Ошибка проверки обновления: $error';
  }

  @override
  String get downloadingApk => 'Загрузка APK...';

  @override
  String apkSavedPleaseInstall(String path) {
    return 'APK сохранён: $path\nУстановите вручную.';
  }

  @override
  String get checkAppUpdate => 'Проверить обновление';

  @override
  String get about => 'О программе';

  @override
  String get appName => 'EvilCrow RF V2';

  @override
  String get appTagline => 'Инструмент RF-безопасности Sub-GHz';

  @override
  String get connectionStatus => 'Состояние подключения';

  @override
  String get debugControls => 'Управление отладкой';

  @override
  String get cpuTempOffset => 'Смещение температуры CPU';

  @override
  String get cpuTempOffsetDesc =>
      'Добавляет смещение к внутреннему датчику температуры ESP32 (сохраняется на устройстве).';

  @override
  String get clearCachedDevice => 'Очистить кэш устройства';

  @override
  String get refreshFiles => 'Обновить файлы';

  @override
  String get activityLogs => 'Журнал активности';

  @override
  String get hideUnknown => 'Скрыть неизвестные';

  @override
  String get sdCard => 'SD-карта';

  @override
  String get internal => 'Внутренняя';

  @override
  String get internalLittleFs => 'Внутренняя (LittleFS)';

  @override
  String get directory => 'Каталог';

  @override
  String get flashLocalBinary => 'Прошить локальный файл';

  @override
  String get selectBinFileDesc =>
      'Выберите файл .bin прошивки для прямой загрузки через BLE OTA.';

  @override
  String get selectBin => 'Выбрать .bin';

  @override
  String get flash => 'Прошить';

  @override
  String fileLabel(String path) {
    return 'Файл: $path';
  }

  @override
  String get localFirmwareUploaded => 'Локальная прошивка загружена!';

  @override
  String changelogVersion(String version) {
    return 'Изменения — v$version';
  }

  @override
  String get startingOtaTransfer => 'Начало OTA передачи...';

  @override
  String get frequencyRequired => 'Частота обязательна';

  @override
  String get invalidFrequencyFormat => 'Неверный формат частоты';

  @override
  String get frequencyRangeError =>
      'Частота должна быть в диапазоне 300-348, 387-464 или 779-928 МГц';

  @override
  String get selectFrequency => 'Выберите частоту';

  @override
  String get invalidDataRateFormat => 'Неверный формат скорости';

  @override
  String dataRateRangeError(String min, String max) {
    return 'Скорость должна быть от $min до $max кБод';
  }

  @override
  String get invalidDeviationFormat => 'Неверный формат девиации';

  @override
  String deviationRangeError(String min, String max) {
    return 'Девиация должна быть от $min до $max кГц';
  }

  @override
  String get errors => 'Ошибки';

  @override
  String get noSignalDataToPreview => 'Нет данных для предпросмотра';

  @override
  String get signalPreview => 'Предпросмотр сигнала';

  @override
  String get dataLength => 'Длина данных';

  @override
  String get sampleData => 'Пример данных:';

  @override
  String get loadSignalFile => 'Загрузить файл сигнала';

  @override
  String get selectFile => 'Выбрать файл';

  @override
  String get formats => 'Форматы';

  @override
  String get supportedFormatsShort =>
      'Поддерживаемые форматы: .sub (FlipperZero), .json (TUT)';

  @override
  String get supportedFileFormats => 'Поддерживаемые форматы файлов';

  @override
  String get readyToTransmit => 'Готово к передаче';

  @override
  String percentComplete(int progress) {
    return '$progress% завершено';
  }

  @override
  String get validationErrors => 'Ошибки валидации';

  @override
  String get noTransmissionHistory => 'Нет истории передач';

  @override
  String get transmissionHistory => 'История передач';

  @override
  String get success => 'Успешно';

  @override
  String get goUp => 'Наверх';

  @override
  String get connectToDeviceToSeeFiles =>
      'Подключите устройство для просмотра файлов';

  @override
  String get noFilesAvailableForSelection => 'Нет файлов для выбора';

  @override
  String get deselectFile => 'Отменить выбор';

  @override
  String get selectFileTooltip => 'Выбрать файл';

  @override
  String get saveToSignals => 'Сохранить в сигналы';

  @override
  String get fullPath => 'Полный путь';

  @override
  String get downloadingFiles => 'Загрузка файлов...';

  @override
  String get close => 'Закрыть';

  @override
  String get root => 'Корень';

  @override
  String get noSubdirectories => 'Нет подкаталогов';

  @override
  String get storageLabel => 'Хранилище: ';

  @override
  String get errorLoadingDirectories => 'Ошибка загрузки каталогов';

  @override
  String get select => 'Выбрать';

  @override
  String get settingsNotAvailable => 'Настройки недоступны';

  @override
  String playingFile(String filename) {
    return 'Воспроизведение файла: $filename';
  }

  @override
  String failedToSaveSignal(String error) {
    return 'Не удалось сохранить сигнал: $error';
  }

  @override
  String failedToDeleteFile(String error) {
    return 'Не удалось удалить файл: $error';
  }

  @override
  String deletingFile(String name) {
    return 'Удаление файла: $name';
  }

  @override
  String get recordScreenHelpContent =>
      'Этот экран позволяет записывать RF-сигналы с помощью модулей CC1101.\n\n• Выберите вкладку модуля для настройки\n• Нажмите «Старт» для начала записи\n• Обнаруженные сигналы появляются в реальном времени\n• Сохраняйте записи с пользовательскими именами\n• Воспроизводите или передавайте сохранённые записи\n\nДля лучших результатов поместите антенну ближе к передатчику.';

  @override
  String frequencySearchStarted(int number) {
    return 'Поиск частоты начат для модуля $number';
  }

  @override
  String failedToStartFrequencySearch(String error) {
    return 'Не удалось начать поиск частоты: $error';
  }

  @override
  String failedToStopFrequencySearch(String error) {
    return 'Не удалось остановить поиск частоты: $error';
  }

  @override
  String get standingOnShoulders => 'Стоя на плечах гигантов';

  @override
  String get githubProfile => 'Профиль GitHub';

  @override
  String get donate => 'Пожертвовать';

  @override
  String get sdrMode => 'Режим SDR';

  @override
  String get sdrModeActiveSubtitle => 'Активен — операции SubGhz заблокированы';

  @override
  String get sdrModeInactiveSubtitle => 'Спектр CC1101 и приём через USB';

  @override
  String get sdrConnectViaUsb =>
      'Подключитесь через USB serial для потоковой передачи SDR.';

  @override
  String get connectedStatus => 'Подключено';

  @override
  String get disconnectedStatus => 'Отключено';

  @override
  String get testCommands => 'Тестовые команды:';

  @override
  String deviceLabel(String name) {
    return 'Устройство: $name';
  }

  @override
  String deviceIdLabel(String id) {
    return 'ID: $id';
  }

  @override
  String get stateIdle => 'Ожидание';

  @override
  String get stateDetecting => 'Обнаружение';

  @override
  String get stateRecording => 'Запись';

  @override
  String get stateTransmitting => 'Передача';

  @override
  String get stateUnknown => 'Неизвестно';

  @override
  String get nrf24Jamming => 'NRF24: Глушение';

  @override
  String get nrf24Scanning => 'NRF24: Сканирование';

  @override
  String get nrf24Attacking => 'NRF24: Атака';

  @override
  String get nrf24SpectrumActive => 'NRF24: Спектр';

  @override
  String get nrf24Idle => 'NRF24: Ожидание';

  @override
  String batteryTooltip(int percentage, String volts, String charging) {
    return 'Батарея: $percentage% ($volts В)$charging';
  }

  @override
  String get specialThanks => '★ Благодарности ★';

  @override
  String get frequencyLabel => 'Частота';

  @override
  String get modulationLabel => 'Модуляция';

  @override
  String get dataRateLabel => 'Скорость данных';

  @override
  String get deviationLabel => 'Девиация';

  @override
  String get dataLengthLabel => 'Длина данных';

  @override
  String get flipperSubGhzFormat => 'FlipperZero SubGhz (.sub)';

  @override
  String get flipperSubGhzDetails =>
      '• Формат необработанных сигналов\n• Используется Flipper Zero\n• Содержит частоту и параметры модуляции';

  @override
  String get tutJsonFormat => 'TUT JSON (.json)';

  @override
  String get tutJsonDetails =>
      '• Формат JSON с параметрами сигнала\n• Используется TUT (Test & Utility Tool)\n• Содержит частоту, скорость и необработанные данные';

  @override
  String sdCardPath(String path) {
    return 'SD-карта: $path';
  }

  @override
  String get rfScanner => 'RF сканер';

  @override
  String moreSamples(int count) {
    return '+$count ещё';
  }

  @override
  String sampleCount(int count) {
    return '$count сэмплов';
  }

  @override
  String transmitHistorySubtitle(
      String time, int moduleNumber, int repeatCount) {
    return '$time • Модуль $moduleNumber • $repeatCount повторов';
  }

  @override
  String downloadingFile(String name) {
    return 'Загрузка файла: $name';
  }

  @override
  String moduleStatus(int number, String mode) {
    return 'Модуль $number: $mode';
  }

  @override
  String get transmittingEllipsis => 'Передача...';

  @override
  String get chargingIndicator => ' ⚡ Зарядка';
}
