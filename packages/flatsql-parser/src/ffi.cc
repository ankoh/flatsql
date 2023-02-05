#include "flatsql/parser/parser_driver.h"
#include "flatsql/proto/proto_generated.h"
#include "flatbuffers/flatbuffers.h"

using namespace flatsql::parser;
namespace proto = flatsql::proto;

struct FFIResult {
    uint32_t status_code;
    uint32_t data_length;
    void* data_ptr;
    void* owner_ptr;
    void (*owner_deleter)(void*);
};

extern "C" FFIResult* flatsql_new_result() {
    auto result = new FFIResult();
    result->status_code = 0;
    result->data_length = 0;
    result->data_ptr = nullptr;
    result->owner_ptr = nullptr;
    result->owner_deleter = [](void* buffer) {};
    return result;
}

extern "C" char* flatsql_new_string(size_t length) {
    auto buffer = new char[length];
    memset(buffer, 0, length * sizeof(char));
    return buffer;
}

extern "C" void flatsql_delete_result(FFIResult* result) { delete result; }
extern "C" void flatsql_delete_string(char* buffer) { delete buffer; }

extern "C" void flatsql_parse(FFIResult* result, const uint8_t* text, size_t length) {
    static_assert(sizeof(uint8_t) == sizeof(char));

    // Parse the program
    auto program = ParserDriver::Parse(std::string_view{reinterpret_cast<const char*>(text), length});

    // Pack the flatbuffer program
    flatbuffers::FlatBufferBuilder fb;
    auto program_ofs = proto::Program::Pack(fb, program.get());
    fb.Finish(program_ofs);

    // Store the buffer
    auto detached = std::make_unique<flatbuffers::DetachedBuffer>(std::move(fb.Release()));
    result->status_code = 0;
    result->data_ptr = detached->data();
    result->data_length = detached->size();
    result->owner_ptr = detached.release();
    result->owner_deleter = [](void* buffer) { delete reinterpret_cast<flatbuffers::DetachedBuffer*>(buffer); };
}

#ifdef WASM
extern "C" int main() { return 0; }
#endif
