#ifndef Tasks_h
#define Tasks_h

#include <functional>
#include "compatibility.h"
#include <vector>
#include "Arduino.h"
#include "modules/CC1101_driver/CC1101_Module.h"

namespace Device {

enum class TaskType {
    Transmission,
    Record,
    DetectSignal,
    FilesManager,
    FileUpload,
    GetState,
    Idle,
    Jam
};

struct TaskBase {
    TaskType type;
    TaskBase(TaskType t) : type(t) {}
};

// ====================================
// Task Transmission
// ====================================
enum class TransmissionType
{
    Raw,
    File,
    Binary
};

struct TransmissionConfig
{
    std::unique_ptr<float> frequency;
    std::unique_ptr<int> modulation;
    std::unique_ptr<float> deviation;
    std::unique_ptr<std::string> preset;

    TransmissionConfig() = default;
    TransmissionConfig(std::unique_ptr<float> freq, std::unique_ptr<int> mod, std::unique_ptr<float> dev, std::unique_ptr<std::string> pre)
        : frequency(std::move(freq)), modulation(std::move(mod)), deviation(std::move(dev)), preset(std::move(pre))
    {
    }
};

struct TaskTransmission: public TaskBase
{
    TransmissionType transmissionType;
    std::unique_ptr<std::string> filename;
    int module = 0;
    std::unique_ptr<int> repeat;
    std::unique_ptr<std::string> data;
    TransmissionConfig config;
    int pathType = 0; // path type

    TaskTransmission(TransmissionType t) : TaskBase(TaskType::Transmission), transmissionType(t), config(), pathType(0) {
    }

    // Delete copy constructor and assignment operator to prevent accidental copying
    TaskTransmission(const TaskTransmission&) = delete;
    TaskTransmission& operator=(const TaskTransmission&) = delete;

    // Provide move constructor and move assignment operator
    TaskTransmission(TaskTransmission&& other) noexcept = default;
    TaskTransmission& operator=(TaskTransmission&& other) noexcept = default;
};

class TaskTransmissionBuilder
{
  private:
    TaskTransmission task;

  public:
    TaskTransmissionBuilder(TransmissionType t) : task(t) {}

    TaskTransmissionBuilder& setFilename(std::string fname)
    {
        task.filename = std::make_unique<std::string>(fname);
        return *this;
    }

    TaskTransmissionBuilder& setModule(int mod)
    {
        task.module = mod;
        return *this;
    }

    TaskTransmissionBuilder& setRepeat(int rep)
    {
        task.repeat = std::make_unique<int>(rep);
        return *this;
    }

    TaskTransmissionBuilder& setFrequency(float freq)
    {
        task.config.frequency = std::make_unique<float>(freq);
        return *this;
    }

    TaskTransmissionBuilder& setModulation(int mod)
    {
        task.config.modulation = std::make_unique<int>(mod);
        return *this;
    }

    TaskTransmissionBuilder& setDeviation(float dev)
    {
        task.config.deviation = std::make_unique<float>(dev);
        return *this;
    }

    TaskTransmissionBuilder& setPreset(std::string pre)
    {
        task.config.preset = std::make_unique<std::string>(std::move(pre));
        return *this;
    }

    TaskTransmissionBuilder& setData(std::string data)
    {
        task.data = std::make_unique<std::string>(std::move(data));
        return *this;
    }

    TaskTransmissionBuilder& setPathType(int pt)
    {
        task.pathType = pt;
        return *this;
    }

    TaskTransmission build()
    {
        return std::move(task);
    }
};

// ====================================
// Task Record
// ====================================
struct RecordConfig
{
    float frequency;
    std::unique_ptr<int> modulation;
    std::unique_ptr<float> deviation;
    std::unique_ptr<float> rxBandwidth;
    std::unique_ptr<float> dataRate;
    std::unique_ptr<std::string> preset;

    RecordConfig() = default;
};

struct TaskRecord: public TaskBase
{
    std::unique_ptr<int> module;
    RecordConfig config;

    TaskRecord(float freq) : TaskBase(TaskType::Record), config()
    {
        config.frequency = freq;
    }

    // Delete copy constructor and assignment operator to prevent accidental copying
    TaskRecord(const TaskRecord&) = delete;
    TaskRecord& operator=(const TaskRecord&) = delete;

    // Provide move constructor and move assignment operator
    TaskRecord(TaskRecord&& other) noexcept = default;
    TaskRecord& operator=(TaskRecord&& other) noexcept = default;
};

class TaskRecordBuilder
{
  private:
    TaskRecord task;

  public:
    TaskRecordBuilder(float frequency) : task(frequency) {}

    TaskRecordBuilder& setModulation(int mod)
    {
        task.config.modulation = std::make_unique<int>(mod);
        return *this;
    }

    TaskRecordBuilder& setDeviation(float dev)
    {
        task.config.deviation = std::make_unique<float>(dev);
        return *this;
    }

    TaskRecordBuilder& setRxBandwidth(float rxBW)
    {
        task.config.rxBandwidth = std::make_unique<float>(rxBW);
        return *this;
    }

    TaskRecordBuilder& setDataRate(float dRate)
    {
        task.config.dataRate = std::make_unique<float>(dRate);
        return *this;
    }

    TaskRecordBuilder& setPreset(std::string pre)
    {
        task.config.preset = std::make_unique<std::string>(pre);
        return *this;
    }

    TaskRecordBuilder& setModule(int mod)
    {
        task.module = std::make_unique<int>(mod);
        return *this;
    }

    TaskRecord build()
    {
        return std::move(task);
    }
};

// ====================================
// Task FilesManager
// ====================================
enum class TaskFilesManagerAction
{
    Unknown,
    List,
    Load,
    CreateDirectory,
    Delete,
    Rename
};

struct TaskFilesManager: public TaskBase
{
    TaskFilesManagerAction actionType;
    std::string path;
    std::string pathTo;
    uint8_t pathType = 0;  // 0=/DATA/RECORDS, 1=/DATA/SIGNALS, 2=/DATA/PRESETS, 3=/DATA/TEMP, etc.

    TaskFilesManager(TaskFilesManagerAction t, std::string p = "", std::string pt = "")
        : TaskBase(TaskType::FilesManager), actionType(t), path(p), pathTo(pt) {}

    // Delete copy constructor and assignment operator to prevent accidental copying
    TaskFilesManager(const TaskFilesManager&) = delete;
    TaskFilesManager& operator=(const TaskFilesManager&) = delete;

    // Provide move constructor and move assignment operator
    TaskFilesManager(TaskFilesManager&& other) noexcept = default;
    TaskFilesManager& operator=(TaskFilesManager&& other) noexcept = default;
};

// ====================================
// Task FileUpload
// ====================================

enum class FileUploadType
{
    File,
    Firmware
};

struct TaskFileUpload: public TaskBase
{
    std::string filename;
    FileUploadType uploadType;
    size_t index;
    std::vector<uint8_t> data;
    size_t len;
    bool final;

    TaskFileUpload(std::string filename, FileUploadType uploadType, size_t index = 0, uint8_t* data = nullptr, size_t len = 0, bool final = false)
        : TaskBase(TaskType::FileUpload), filename(filename), uploadType(uploadType), index(index), data(data, data + len), len(len), final(final) {}
};

// ====================================
// Task DetectSignal
// ====================================

struct TaskDetectSignal: public TaskBase
{
  public:
    std::unique_ptr<int> module;
    std::unique_ptr<int> minRssi;
    std::unique_ptr<bool> background;

    TaskDetectSignal() : TaskBase(TaskType::DetectSignal) {};

    // Delete copy constructor and assignment operator to prevent accidental copying
    TaskDetectSignal(const TaskDetectSignal&) = delete;
    TaskDetectSignal& operator=(const TaskDetectSignal&) = delete;

    // Provide move constructor and move assignment operator
    TaskDetectSignal(TaskDetectSignal&& other) noexcept = default;
    TaskDetectSignal& operator=(TaskDetectSignal&& other) noexcept = default;
};

class TaskDetectSignalBuilder
{
  private:
    TaskDetectSignal task;

  public:
    // Default constructor
    TaskDetectSignalBuilder() = default;

    TaskDetectSignalBuilder& setModule(int module)
    {
        task.module = std::make_unique<int>(module);
        return *this;
    }

    TaskDetectSignalBuilder& setMinRssi(int minRssi)
    {
        task.minRssi = std::make_unique<int>(minRssi);
        return *this;
    }

    TaskDetectSignalBuilder& setIsBackground(bool isBackground)
    {
        task.background = std::make_unique<bool>(isBackground);
        return *this;
    }

    TaskDetectSignal build()
    {
        return std::move(task);
    }
};

// ====================================
// Task GetState
// ====================================

struct TaskGetState: public TaskBase
{
  public:
    bool full;

    TaskGetState(bool full) : TaskBase(TaskType::GetState), full(full) {}
};

// ====================================
// Task Idle
// ====================================

struct TaskIdle: public TaskBase
{
  public:
    int module;

    TaskIdle(int module) : TaskBase(TaskType::Idle), module(module) {}
};

// ====================================
// Task Jam
// ====================================

enum class JamPatternType {
    Random,      // Random noise
    Alternating, // Alternating pattern (0xAA, 0x55)
    Continuous,  // Continuous transmission (0xFF)
    Custom       // Custom pattern
};

struct TaskJam: public TaskBase
{
  public:
    int module;
    float frequency;
    int power;           // Transmitter power (0-7)
    JamPatternType patternType;
    std::unique_ptr<std::vector<uint8_t>> customPattern; // For custom pattern
    uint32_t maxDurationMs;  // Maximum operating time in ms (0 = unlimited)
    uint32_t cooldownMs;     // Cooldown pause time after overheating in ms

    TaskJam() : TaskBase(TaskType::Jam), 
                module(0), 
                frequency(433.92f),
                power(7),
                patternType(JamPatternType::Random),
                maxDurationMs(60000),  // 60 seconds default
                cooldownMs(5000) {}    // 5 seconds pause

    // Delete copy constructor and assignment operator
    TaskJam(const TaskJam&) = delete;
    TaskJam& operator=(const TaskJam&) = delete;

    // Move constructor and move assignment operator
    TaskJam(TaskJam&& other) noexcept = default;
    TaskJam& operator=(TaskJam&& other) noexcept = default;
};

class TaskJamBuilder
{
  private:
    TaskJam task;

  public:
    TaskJamBuilder() = default;

    TaskJamBuilder& setModule(int mod)
    {
        task.module = mod;
        return *this;
    }

    TaskJamBuilder& setFrequency(float freq)
    {
        task.frequency = freq;
        return *this;
    }

    TaskJamBuilder& setPower(int pwr)
    {
        task.power = pwr;
        return *this;
    }

    TaskJamBuilder& setPatternType(JamPatternType pattern)
    {
        task.patternType = pattern;
        return *this;
    }

    TaskJamBuilder& setCustomPattern(const std::vector<uint8_t>& pattern)
    {
        task.customPattern = std::make_unique<std::vector<uint8_t>>(pattern);
        return *this;
    }

    TaskJamBuilder& setMaxDuration(uint32_t durationMs)
    {
        task.maxDurationMs = durationMs;
        return *this;
    }

    TaskJamBuilder& setCooldown(uint32_t cooldownMs)
    {
        task.cooldownMs = cooldownMs;
        return *this;
    }

    TaskJam build()
    {
        return std::move(task);
    }
};

} // namespace Device

struct QueueItem {
    Device::TaskType type;
    union {
        Device::TaskTransmission transmissionTask;
        Device::TaskRecord recordTask;
        Device::TaskDetectSignal detectSignalTask;
        Device::TaskFilesManager filesManagerTask;
        Device::TaskFileUpload fileUploadTask;
        Device::TaskGetState getStateTask;
        Device::TaskIdle idleTask;
        Device::TaskJam jamTask;
    };

    // Default constructor
    QueueItem() : type(Device::TaskType::Idle) {
        new (&idleTask) Device::TaskIdle(0);
    }

    // Constructors for each task type
    QueueItem(Device::TaskTransmission&& task) : type(Device::TaskType::Transmission), transmissionTask(std::move(task)) {}
    QueueItem(Device::TaskRecord&& task) : type(Device::TaskType::Record), recordTask(std::move(task)) {}
    QueueItem(Device::TaskDetectSignal&& task) : type(Device::TaskType::DetectSignal), detectSignalTask(std::move(task)) {}
    QueueItem(Device::TaskFilesManager&& task) : type(Device::TaskType::FilesManager), filesManagerTask(std::move(task)) {}
    QueueItem(Device::TaskFileUpload&& task) : type(Device::TaskType::FileUpload), fileUploadTask(std::move(task)) {}
    QueueItem(Device::TaskGetState&& task) : type(Device::TaskType::GetState), getStateTask(std::move(task)) {}
    QueueItem(Device::TaskIdle&& task) : type(Device::TaskType::Idle), idleTask(std::move(task)) {}
    QueueItem(Device::TaskJam&& task) : type(Device::TaskType::Jam), jamTask(std::move(task)) {}

    // Destructor
    ~QueueItem() {
        switch (type) {
            case Device::TaskType::Transmission:
                transmissionTask.~TaskTransmission();
                break;
            case Device::TaskType::Record:
                recordTask.~TaskRecord();
                break;
            case Device::TaskType::DetectSignal:
                detectSignalTask.~TaskDetectSignal();
                break;
            case Device::TaskType::FilesManager:
                filesManagerTask.~TaskFilesManager();
                break;
            case Device::TaskType::FileUpload:
                fileUploadTask.~TaskFileUpload();
                break;
            case Device::TaskType::GetState:
                getStateTask.~TaskGetState();
                break;
            case Device::TaskType::Idle:
                idleTask.~TaskIdle();
                break;
            case Device::TaskType::Jam:
                jamTask.~TaskJam();
                break;
            default:
                break;
        }
    }

    // Disable copy constructor and copy assignment operator
    QueueItem(const QueueItem&) = delete;
    QueueItem& operator=(const QueueItem&) = delete;

    // Move constructor
    QueueItem(QueueItem&& other) noexcept : type(other.type) {
        switch (type) {
            case Device::TaskType::Transmission:
                new (&transmissionTask) Device::TaskTransmission(std::move(other.transmissionTask));
                break;
            case Device::TaskType::Record:
                new (&recordTask) Device::TaskRecord(std::move(other.recordTask));
                break;
            case Device::TaskType::DetectSignal:
                new (&detectSignalTask) Device::TaskDetectSignal(std::move(other.detectSignalTask));
                break;
            case Device::TaskType::FilesManager:
                new (&filesManagerTask) Device::TaskFilesManager(std::move(other.filesManagerTask));
                break;
            case Device::TaskType::FileUpload:
                new (&fileUploadTask) Device::TaskFileUpload(std::move(other.fileUploadTask));
                break;
            case Device::TaskType::GetState:
                new (&getStateTask) Device::TaskGetState(std::move(other.getStateTask));
                break;
            case Device::TaskType::Idle:
                new (&idleTask) Device::TaskIdle(std::move(other.idleTask));
                break;
            case Device::TaskType::Jam:
                new (&jamTask) Device::TaskJam(std::move(other.jamTask));
                break;
            default:
                break;
        }
    }

    // Move assignment operator
    QueueItem& operator=(QueueItem&& other) noexcept {
        if (this != &other) {
            this->~QueueItem();
            type = other.type;
            switch (type) {
                case Device::TaskType::Transmission:
                    new (&transmissionTask) Device::TaskTransmission(std::move(other.transmissionTask));
                    break;
                case Device::TaskType::Record:
                    new (&recordTask) Device::TaskRecord(std::move(other.recordTask));
                    break;
                case Device::TaskType::DetectSignal:
                    new (&detectSignalTask) Device::TaskDetectSignal(std::move(other.detectSignalTask));
                    break;
                case Device::TaskType::FilesManager:
                    new (&filesManagerTask) Device::TaskFilesManager(std::move(other.filesManagerTask));
                    break;
                case Device::TaskType::FileUpload:
                    new (&fileUploadTask) Device::TaskFileUpload(std::move(other.fileUploadTask));
                    break;
                case Device::TaskType::GetState:
                    new (&getStateTask) Device::TaskGetState(std::move(other.getStateTask));
                    break;
                case Device::TaskType::Idle:
                    new (&idleTask) Device::TaskIdle(std::move(other.idleTask));
                    break;
                case Device::TaskType::Jam:
                    new (&jamTask) Device::TaskJam(std::move(other.jamTask));
                    break;
                default:
                    break;
            }
        }
        return *this;
    }
};

#endif  // Tasks_h
