#pragma once
 
static constexpr uint8_t FULL_RUNTIME_ID=0xf9;
static constexpr uint32_t SHARED_MODEL_BYTES=308496u, SHARED_MODEL_CRC=0xc9fb5f49u;
static constexpr uint32_t SHARED_PROGRAM_BYTES[3]={117888u,366720u,19456u};
static constexpr uint32_t SHARED_PROGRAM_CRC[3]={3237296641u,1988155149u,3748291448u};
#define SHARED_MODEL_SIZES_JSON "{\"weights\":[308496,3388694345],\"720\":[117888,3237296641],\"1080\":[366720,1988155149]}"
static constexpr uint32_t SHARED_COMMANDS[3]={921u,2865u,152u};
static constexpr uint32_t SHARED_MODEL_COMMANDS[3]={846u,2790u,77u};
