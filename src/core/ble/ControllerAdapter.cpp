#include "ControllerAdapter.h"

// Initialize the static member
QueueHandle_t ControllerAdapter::xTaskQueue = nullptr;

void ControllerAdapter::initializeQueue()
{
    if (xTaskQueue == nullptr) {
        xTaskQueue = xQueueCreate(20, sizeof(QueueItem*)); // Increased from 5 to 20
    }
}