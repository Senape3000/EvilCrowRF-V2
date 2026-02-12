#pragma once

#include <cstdint>
#include <cstdlib>

namespace bruter {

/**
 * Generate a De Bruijn sequence B(2, n) using the greedy "prefer ones" algorithm.
 *
 * Returns a dynamically allocated array of 0/1 bytes representing the bit sequence.
 * The caller is responsible for freeing the returned pointer with free().
 *
 * Sequence length = n + 2^n - 1 bits (every n-bit window appears exactly once).
 *
 * Hard limit: n <= 16 (65KB sequence + 8KB bitmap on ESP32).
 * Returns nullptr if n is out of range or memory allocation fails.
 *
 * @param n          Number of bits per code (1..16)
 * @param outLength  Output: length of the returned array in bytes
 * @return           Pointer to allocated sequence (caller must free()), or nullptr on error
 */
uint8_t* generateDeBruijn(int n, uint32_t& outLength);

/**
 * Check if there is enough heap to generate a De Bruijn sequence of given n.
 * Includes a 10KB safety margin.
 *
 * @param n  Number of bits
 * @return   true if heap is sufficient
 */
bool canGenerateDeBruijn(int n);

} // namespace bruter
