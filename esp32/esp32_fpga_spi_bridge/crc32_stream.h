#pragma once
#include <stddef.h>
#include <stdint.h>

 

inline uint32_t ti60CrcUpdate(uint32_t crc, const uint8_t* data, size_t n) {
  static const uint32_t table[16] = {
    0x00000000u,0x1db71064u,0x3b6e20c8u,0x26d930acu,
    0x76dc4190u,0x6b6b51f4u,0x4db26158u,0x5005713cu,
    0xedb88320u,0xf00f9344u,0xd6d6a3e8u,0xcb61b38cu,
    0x9b64c2b0u,0x86d3d2d4u,0xa00ae278u,0xbdbdf21cu
  };
  while (n--) {
    crc ^= *data++;
    crc = (crc >> 4) ^ table[crc & 15];
    crc = (crc >> 4) ^ table[crc & 15];
  }
  return crc;
}
inline uint32_t ti60Crc32(const uint8_t* data, size_t n) {
  return ~ti60CrcUpdate(0xffffffffu, data, n);
}
