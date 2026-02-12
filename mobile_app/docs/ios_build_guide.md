# 🍎 iOS Build Guide для Windows разработчиков

## 📋 Обязательные требования для iOS

- **macOS** (только на Mac можно компилировать iOS приложения)
- **Xcode** (последняя версия)
- **Flutter** (установленный на Mac)
- **Apple Developer Account** (для публикации)

## 🖥️ Варианты решения для Windows

### 1. **GitHub Actions (Бесплатно) - Рекомендуется**

#### Настройка:
1. Загрузите код в GitHub репозиторий
2. GitHub автоматически запустит сборку iOS при каждом push
3. Собранные файлы будут доступны в разделе Actions

#### Команды для запуска:
```bash
# Добавьте файлы в git
git add .
git commit -m "Add iOS build configuration"
git push origin main

# Проверьте статус сборки в GitHub Actions
```

### 2. **Codemagic (Платно, но удобно)**

#### Настройка:
1. Зарегистрируйтесь на [codemagic.io](https://codemagic.io)
2. Подключите ваш GitHub репозиторий
3. Настройте сертификаты Apple Developer
4. Запустите сборку

#### Преимущества:
- Автоматическая сборка при каждом push
- Поддержка code signing
- Публикация в TestFlight
- Интеграция с GitHub

### 3. **Виртуальная машина macOS**

#### Требования:
- VMware Workstation Pro или VirtualBox
- ISO образ macOS (легально получить сложно)
- Минимум 8GB RAM, 50GB свободного места

#### Настройка:
```bash
# На Mac VM установите:
# 1. Xcode из App Store
# 2. Flutter SDK
# 3. CocoaPods: sudo gem install cocoapods

# Затем выполните:
cd mobile_app
flutter pub get
flutter build ios
```

### 4. **Облачные Mac сервисы**

#### Доступные сервисы:
- **MacStadium** - $0.50/час
- **MacinCloud** - от $1/час
- **AWS EC2 Mac instances** - от $1.083/час

#### Пример для AWS:
```bash
# Подключитесь к Mac instance
ssh -i key.pem ec2-user@your-mac-instance

# Установите Flutter и Xcode
# Соберите приложение
flutter build ios
```

## 🚀 Пошаговая инструкция для GitHub Actions

### Шаг 1: Подготовка репозитория
```bash
# В папке mobile_app
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/yourusername/yourrepo.git
git push -u origin main
```

### Шаг 2: Проверка сборки
1. Перейдите в GitHub репозиторий
2. Откройте вкладку Actions
3. Дождитесь завершения сборки iOS

### Шаг 3: Скачивание артефактов
1. В Actions найдите завершенную сборку
2. Нажмите на сборку
3. Скачайте артефакты (iOS build)

## 📱 Сборка для разных целей

### Debug сборка (для тестирования):
```bash
flutter build ios --debug
```

### Release сборка (для публикации):
```bash
flutter build ios --release
```

### Archive (для App Store):
```bash
flutter build ios --release
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination generic/platform=iOS -archivePath build/Runner.xcarchive clean archive
```

## 🔐 Code Signing

### Для разработки:
```bash
# Автоматическое подписание
flutter build ios --debug
```

### Для публикации:
1. Получите Apple Developer Account ($99/год)
2. Создайте сертификаты в Apple Developer Console
3. Настройте provisioning profiles
4. Используйте Codemagic или GitHub Actions с сертификатами

## 📦 Результат сборки

После успешной сборки вы получите:
- **Debug**: `.app` файл для установки на устройство
- **Release**: `.ipa` файл для TestFlight/App Store
- **Archive**: `.xcarchive` для Xcode

## 🆘 Устранение неполадок

### Ошибка "No iOS development team specified":
```bash
# Откройте ios/Runner.xcodeproj в Xcode
# В Signing & Capabilities выберите Team
```

### Ошибка "Code signing is required":
```bash
# Используйте --no-codesign для тестирования
flutter build ios --no-codesign
```

### Ошибка "Provisioning profile not found":
```bash
# Настройте provisioning profiles в Apple Developer Console
# Или используйте автоматическое подписание в Xcode
```

## 💡 Рекомендации

1. **Начните с GitHub Actions** - это бесплатно и автоматически
2. **Для серьезной разработки** используйте Codemagic
3. **Для частых сборок** рассмотрите облачные Mac сервисы
4. **Всегда тестируйте** на реальных iOS устройствах

## 🔗 Полезные ссылки

- [Flutter iOS Deployment](https://flutter.dev/docs/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [GitHub Actions Flutter](https://github.com/marketplace/actions/flutter-action)
- [Codemagic Flutter](https://codemagic.io/flutter/)

