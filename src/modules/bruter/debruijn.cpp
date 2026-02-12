#include "debruijn.h"
#include "../../include/config.h"
#include <esp_log.h>
#include <Arduino.h>  // For ESP.getFreeHeap()

static const char* TAG = "DeBruijn";

namespace bruter {

bool canGenerateDeBruijn(int n) {
    if (n < 1 || n > DEBRUIJN_MAX_BITS) return false;

    uint32_t totalUnique = 1U << n;
    // Sequence: n + 2^n - 1 bytes
    // Bitmap: (2^n / 8) + 1 bytes
    uint32_t seqBytes    = n + totalUnique;  // Slight overestimate is OK
    uint32_t bitmapBytes = (totalUnique / 8) + 1;
    uint32_t needed      = seqBytes + bitmapBytes + 10240;  // 10KB safety margin

    uint32_t freeHeap = ESP.getFreeHeap();
    ESP_LOGI(TAG, "Heap check: need %u bytes, have %u bytes free", needed, freeHeap);
    return freeHeap >= needed;
}

uint8_t* generateDeBruijn(int n, uint32_t& outLength) {
    outLength = 0;

    if (n < 1 || n > DEBRUIJN_MAX_BITS) {
        ESP_LOGE(TAG, "n=%d out of range [1..%d], aborting", n, DEBRUIJN_MAX_BITS);
        return nullptr;
    }

    if (!canGenerateDeBruijn(n)) {
        ESP_LOGE(TAG, "Insufficient heap for B(2,%d)", n);
        return nullptr;
    }

    uint32_t totalUnique = 1U << n;  // 2^n
    uint32_t seqLen = n + totalUnique - 1;

    // Allocate sequence buffer
    uint8_t* sequence = (uint8_t*)malloc(seqLen);
    if (!sequence) {
        ESP_LOGE(TAG, "Failed to allocate %u bytes for sequence", seqLen);
        return nullptr;
    }

    // Bitmap for visited tracking: 1 bit per possible n-bit value
    size_t bitmapBytes = (totalUnique / 8) + 1;
    uint8_t* visited = (uint8_t*)calloc(bitmapBytes, 1);
    if (!visited) {
        ESP_LOGE(TAG, "Failed to allocate %u bytes for visited bitmap", (uint32_t)bitmapBytes);
        free(sequence);
        return nullptr;
    }

    // Preamble: n zeros to fill the initial sliding window
    for (int i = 0; i < n; i++) {
        sequence[i] = 0;
    }

    uint32_t mask = totalUnique - 1;
    uint32_t val = 0;
    visited[0] |= 1;  // Mark 0...0 as visited

    uint32_t idx = n;  // Start writing after preamble

    // Greedy "prefer ones" algorithm
    for (uint32_t i = 0; i < totalUnique - 1; i++) {
        uint32_t nextOne  = ((val << 1) & mask) | 1;
        uint32_t nextZero = ((val << 1) & mask);

        bool oneVisited = (visited[nextOne / 8] >> (nextOne % 8)) & 1;

        if (!oneVisited) {
            val = nextOne;
            visited[nextOne / 8] |= (1 << (nextOne % 8));
            sequence[idx++] = 1;
        } else {
            val = nextZero;
            visited[nextZero / 8] |= (1 << (nextZero % 8));
            sequence[idx++] = 0;
        }
    }

    free(visited);

    outLength = seqLen;
    ESP_LOGI(TAG, "Generated B(2,%d): %u bits, %u unique windows",
             n, (unsigned)seqLen, (unsigned)totalUnique);
    return sequence;
}

} // namespace bruter
