#ifndef ClientsManager_h
#define ClientsManager_h

#include <map>
#include <string>
#include <queue>

#include "ControllerAdapter.h"

enum class NotificationType
{
    SignalDetected,
    SignalRecorded,
    SignalRecordError,
    SignalSent,
    SignalSendingError,
    State,
    ModeSwitch,
    FileSystem,
    FileUpload,
    FrequencySearchStarted,
    FrequencySearchError,
    BruterProgress,
    BruterComplete,
    SettingsSync,
    VersionInfo,
    NrfEvent,
    OtaEvent,
    SdrEvent,
    DeviceInfo,
    Unknown
};

inline const String NotificationTypeToString(NotificationType v)
{
    switch (v) {
        case NotificationType::SignalDetected:
            return "SignalDetected";
        case NotificationType::SignalRecorded:
            return "SignalRecorded";
        case NotificationType::SignalRecordError:
            return "SignalRecordError";
        case NotificationType::SignalSent:
            return "SignalSent";
        case NotificationType::SignalSendingError:
            return "SignalSendingError";
        case NotificationType::ModeSwitch:
            return "ModeSwitch";
        case NotificationType::FileSystem:
            return "FileSystem";
        case NotificationType::FileUpload:
            return "FileUpload";
        case NotificationType::State:
            return "State";
        case NotificationType::FrequencySearchStarted:
            return "FrequencySearchStarted";
        case NotificationType::FrequencySearchError:
            return "FrequencySearchError";
        case NotificationType::BruterProgress:
            return "BruterProgress";
        case NotificationType::BruterComplete:
            return "BruterComplete";
        case NotificationType::SettingsSync:
            return "SettingsSync";
        case NotificationType::VersionInfo:
            return "VersionInfo";
        case NotificationType::NrfEvent:
            return "NrfEvent";
        case NotificationType::OtaEvent:
            return "OtaEvent";
        case NotificationType::SdrEvent:
            return "SdrEvent";
        case NotificationType::DeviceInfo:
            return "DeviceInfo";
        default:
            return "Unknown";
    }
}

struct Notification
{
    NotificationType type;
    char textBuffer[256];  // Static buffer for text messages (keep small - files sent directly)
    uint8_t binaryData[128];  // Static buffer for binary messages
    size_t messageLength;
    bool isBinary;

    Notification() : type(NotificationType::Unknown), messageLength(0), isBinary(false) {
        textBuffer[0] = '\0';
        memset(binaryData, 0, sizeof(binaryData));
    }
    
    // Get message as std::string (only when needed for backward compatibility)
    std::string getMessage() const {
        if (isBinary) {
            return std::string(reinterpret_cast<const char*>(binaryData), messageLength);
        } else {
            return std::string(textBuffer);
        }
    }
};

class ClientsManager
{
  public:
    static ClientsManager& getInstance();

    void addAdapter(ControllerAdapter* adapter);
    void removeAdapter(const std::string& name);
    void notifyAll(NotificationType type, const std::string& message);
    void notifyAllBinary(NotificationType type, const uint8_t* data, size_t length);
    void notifyByName(const std::string& name, NotificationType type, const std::string& message);
    void initializeQueue(size_t queueSize);

    bool enqueueMessage(NotificationType, const std::string& message);
    static void processMessageQueue(void *taskParameters);

    // Get count of connected clients across all adapters
    size_t getConnectedCount() const;

  private:
    ClientsManager();
    ~ClientsManager();
    ClientsManager(const ClientsManager&) = delete;
    ClientsManager& operator=(const ClientsManager&) = delete;
    QueueHandle_t clientsNotificationQueue;
    std::map<std::string, ControllerAdapter*> adapters;
};

#endif  // Clients_h