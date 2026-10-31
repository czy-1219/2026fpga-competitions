#pragma once
#include <stddef.h>
#include <stdint.h>
#include "crc32_stream.h"

 


class JpegHttpGuard {
 public:
  explicit JpegHttpGuard(uint32_t payloadBytes, bool rawRgb565=false) : payload_(payloadBytes), raw_(rawRgb565) {}

  template<class Write>
  bool consume(const uint8_t* data, size_t count, Write write) {
    if (failed_ || payload_ < 2 || offset_ > payload_ + 4 ||
        count > payload_ + 4 - offset_) return failed_ = true, false;
    size_t body = offset_ < payload_ ? payload_ - offset_ : 0;
    if (body > count) body = count;
    if (!raw_ && body) {
      if (offset_ == 0 && data[0] != 0xff) failed_ = true;
      const size_t second = offset_ == 0 ? 1 : 0;
      if (offset_ <= 1 && body > second && data[second] != 0xd8) failed_ = true;
    }
    crc_ = ti60CrcUpdate(crc_, data, body);
    size_t send = body;
    if (body && offset_ + body == payload_) {
      tail_ = data[body - 1];
      --send;
    }
    if (failed_ || (send && !write(data, send))) return failed_ = true, false;
    sent_ += send;
    for (size_t i = body; i < count; ++i)
      receivedCrc_ |= uint32_t(data[i]) << (8 * (offset_ + i - payload_));
    offset_ += count;
    return true;
  }

  bool crcOk() const { return !failed_ && offset_ == payload_ + 4 && ~crc_ == receivedCrc_; }
  uint32_t sent() const { return sent_; }
  uint32_t verifiedCrc() const { return crcOk() ? ~crc_ : 0; }

  template<class Write>
  bool finish(Write write, bool includeCrcTrailer=false) {
    if (finished_ || !crcOk()) return false;
    finished_ = true;
    const uint32_t crc=verifiedCrc();
    const uint8_t finalBytes[5]={tail_,uint8_t(crc),uint8_t(crc>>8),uint8_t(crc>>16),uint8_t(crc>>24)};
    if (!write(finalBytes,includeCrcTrailer ? 5 : 1)) return false;
    ++sent_;
    if (sent_ != payload_) return false;
    return true;
  }

 private:
  uint32_t payload_, offset_ = 0, crc_ = 0xffffffffu, receivedCrc_ = 0, sent_ = 0;
  uint8_t tail_ = 0;
  bool failed_ = false, finished_ = false, raw_ = false;
};
