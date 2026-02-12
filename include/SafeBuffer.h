#ifndef SafeBuffer_h
#define SafeBuffer_h

#include <cstddef>
#include <cstdlib>

/**
 * @brief RAII wrapper for dynamic buffers
 *
 * Automatically frees memory at scope exit.
 * Prevents memory leaks on exceptions or early returns.
 *
 * @tparam T Element type of the buffer (default uint8_t)
 *
 * @example
 * void processData(size_t dataSize) {
 *     SafeBuffer<uint8_t> buffer(dataSize);
 *     if (!buffer.isValid()) {
 *         // Out of memory
 *         return;
 *     }
 *
 *     // Use the buffer
 *     memcpy(buffer.get(), source, dataSize);
 *
 *     // Memory is freed automatically on exit
 * }
 */
template<typename T = uint8_t>
class SafeBuffer {
private:
    T* buffer;
    size_t size;
    
public:
    /**
     * @brief Constructor - allocates memory for the buffer
     * @param count Number of elements of type T
     */
    explicit SafeBuffer(size_t count) 
        : size(count), buffer(nullptr) {
        if (count > 0) {
            buffer = static_cast<T*>(malloc(count * sizeof(T)));
        }
    }
    
    /**
     * @brief Destructor - frees memory automatically
     */
    ~SafeBuffer() {
        if (buffer) {
            free(buffer);
            buffer = nullptr;
        }
    }
    
    // Getters
    
    /**
     * @brief Get pointer to buffer
     * @return Pointer to buffer or nullptr if allocation failed
     */
    T* get() { return buffer; }
    
    /**
     * @brief Get const pointer to buffer
     * @return Const pointer to buffer
     */
    const T* get() const { return buffer; }
    
    /**
     * @brief Get buffer size in elements
     * @return Size in elements of type T
     */
    size_t getSize() const { return size; }
    
    /**
     * @brief Get buffer size in bytes
     * @return Size in bytes
     */
    size_t getSizeBytes() const { return size * sizeof(T); }
    
    /**
     * @brief Check allocation success
     * @return true if buffer is allocated, false if out of memory
     */
    bool isValid() const { return buffer != nullptr; }
    
    // Access operators
    
    /**
     * @brief Index access operator
     * @param index Element index
     * @return Reference to element
     */
    T& operator[](size_t index) { 
        return buffer[index]; 
    }
    
    /**
     * @brief Const index access operator
     * @param index Element index
     * @return Const reference to element
     */
    const T& operator[](size_t index) const { 
        return buffer[index]; 
    }
    
    // Disable copying (move only)
    
    /**
     * @brief Deleted copy constructor
     *
     * Copying is disabled to prevent double free.
     * Use move semantics to transfer ownership.
     */
    SafeBuffer(const SafeBuffer&) = delete;
    
    /**
     * @brief Deleted copy assignment operator
     */
    SafeBuffer& operator=(const SafeBuffer&) = delete;
    
    // Move semantics
    
    /**
     * @brief Move constructor
     *
     * Transfers ownership of the buffer from other to this.
     * After the operation other becomes empty.
     *
     * @param other Buffer to move
     */
    SafeBuffer(SafeBuffer&& other) noexcept 
        : buffer(other.buffer), size(other.size) {
        other.buffer = nullptr;
        other.size = 0;
    }
    
    /**
     * @brief Move assignment operator
     *
     * Transfers ownership of the buffer from other to this.
     * Current buffer is freed, other becomes empty.
     *
     * @param other Buffer to move
     * @return Reference to this
     */
    SafeBuffer& operator=(SafeBuffer&& other) noexcept {
        if (this != &other) {
            // Free current buffer
            if (buffer) {
                free(buffer);
            }
            
            // Move from other
            buffer = other.buffer;
            size = other.size;
            
            // Clear other
            other.buffer = nullptr;
            other.size = 0;
        }
        return *this;
    }
    
    /**
    * @brief Manually free buffer before scope exit
    *
    * Useful if memory must be freed earlier.
    * After calling freeEarly() isValid() will return false.
     */
    void release() {
        if (buffer) {
            free(buffer);
            buffer = nullptr;
            size = 0;
        }
    }
};

/**
 * @brief Specialization for char* (convenient for string buffers)
 */
using CharBuffer = SafeBuffer<char>;

/**
 * @brief Specialization for uint8_t* (standard byte buffers)
 */
using ByteBuffer = SafeBuffer<uint8_t>;

#endif // SafeBuffer_h

















