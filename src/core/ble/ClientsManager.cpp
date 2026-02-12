#include "ClientsManager.h"

ClientsManager& ClientsManager::getInstance() {
    static ClientsManager instance;
    return instance;
}

ClientsManager::ClientsManager() : clientsNotificationQueue(nullptr) {}


ClientsManager::~ClientsManager() {
    if (clientsNotificationQueue != nullptr) {
        vQueueDelete(clientsNotificationQueue);
    }
}

void ClientsManager::initializeQueue(size_t queueSize) {
    if (clientsNotificationQueue == nullptr) {
        clientsNotificationQueue = xQueueCreate(queueSize, sizeof(Notification));
    }
}

void ClientsManager::addAdapter(ControllerAdapter* adapter)
{
    adapters[adapter->getName().c_str()] = adapter;
}

void ClientsManager::removeAdapter(const std::string& name)
{
    adapters.erase(name);
}

size_t ClientsManager::getConnectedCount() const
{
    size_t count = 0;
    for (const auto& pair : adapters) {
        if (pair.second->isConnected()) {
            count++;
        }
    }
    return count;
}

void ClientsManager::notifyAll(NotificationType type, const std::string& message)
{
    String typeName = NotificationTypeToString(type);
    for (const auto& pair : adapters) {
        pair.second->notify(typeName, message);
    }
}

void ClientsManager::notifyAllBinary(NotificationType type, const uint8_t* data, size_t length)
{
    // Convert binary data to std::string (preserving null bytes)
    std::string message(reinterpret_cast<const char*>(data), length);
    String typeName = NotificationTypeToString(type);
    for (const auto& pair : adapters) {
        pair.second->notify(typeName, message);
    }
}

void ClientsManager::notifyByName(const std::string& name, NotificationType type, const std::string& message)
{
    String typeName = NotificationTypeToString(type);
    if (adapters.find(name) != adapters.end()) {
        adapters[name]->notify(typeName, message);
    }
}

bool ClientsManager::enqueueMessage(NotificationType type, const std::string& message)
{
    if (clientsNotificationQueue == nullptr) {
        return false;
    }

    Notification notification;
    notification.type = type;
    
    // Check if this is a binary message (first byte >= 0x80)
    if (!message.empty() && (uint8_t)(unsigned char)message[0] >= 0x80) {
        // Binary message - copy to static buffer
        notification.isBinary = true;
        notification.messageLength = message.length();
        if (notification.messageLength > sizeof(notification.binaryData)) {
            notification.messageLength = sizeof(notification.binaryData);
        }
        memcpy(notification.binaryData, message.data(), notification.messageLength);
    } else {
        // Text message - copy to static buffer (NO HEAP ALLOCATION!)
        notification.isBinary = false;
        notification.messageLength = message.length();
        if (notification.messageLength >= sizeof(notification.textBuffer)) {
            notification.messageLength = sizeof(notification.textBuffer) - 1;
        }
        memcpy(notification.textBuffer, message.c_str(), notification.messageLength);
        notification.textBuffer[notification.messageLength] = '\0';
    }
    
    if (xQueueSend(clientsNotificationQueue, &notification, portMAX_DELAY) != pdPASS) {
        return false;
    }

    return true;
}

void ClientsManager::processMessageQueue(void *taskParameters) {
    Notification notification;

    while (true) {
        if (xQueueReceive(ClientsManager::getInstance().clientsNotificationQueue, &notification, portMAX_DELAY)) {
            if (notification.isBinary) {
                // Binary message - use static buffer
                ClientsManager::getInstance().notifyAllBinary(
                    notification.type, 
                    notification.binaryData, 
                    notification.messageLength
                );
            } else {
                // Text message - use static buffer (no std::string allocation!)
                ClientsManager::getInstance().notifyAll(notification.type, std::string(notification.textBuffer));
            }
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}