package validation

import "../protobuf"
import "out/odin"

import "core:os"
import "core:mem"
import "core:testing"

@(test)
test_decode_all_types :: proc(t: ^testing.T) {
	file_allocator := context.allocator
	bytes, _ := os.read_entire_file_from_path("payload.bin", file_allocator)
	if len(bytes) == 0 {
		testing.fail_now(t, "failed to read payload.bin")
	}
	defer delete(bytes, file_allocator)

	arena: mem.Arena
	backing := make([]u8, 1 * mem.Megabyte)
	mem.arena_init(&arena, backing)
	defer delete(backing)
	allocator := mem.arena_allocator(&arena)

    msg, dec_ok := protobuf.decode_with_allocator(odin.TestAllTypes, bytes, allocator)
    testing.expect(t, dec_ok, "failed to decode TestAllTypes")
    
    // Scalars
    testing.expect_value(t, msg.scalars.v_double, 3.14)

    // Note: f32 precision checks can be tricky, but exact assignment usually works in these simple proto values
    testing.expect_value(t, msg.scalars.v_float, 2.71)
    testing.expect_value(t, msg.scalars.v_int32, -123)
    testing.expect_value(t, msg.scalars.v_int64, -456789)
    testing.expect_value(t, msg.scalars.v_uint32, 123)
    testing.expect_value(t, msg.scalars.v_uint64, 456789)
    testing.expect_value(t, msg.scalars.v_sint32, -789)
    testing.expect_value(t, msg.scalars.v_sint64, -987654321)
    testing.expect_value(t, msg.scalars.v_fixed32, 111)
    testing.expect_value(t, msg.scalars.v_fixed64, 222)
    testing.expect_value(t, msg.scalars.v_sfixed32, -111)
    testing.expect_value(t, msg.scalars.v_sfixed64, -222)
    testing.expect_value(t, msg.scalars.v_bool, true)
    testing.expect_value(t, msg.scalars.v_string, "hello world")
    
    testing.expect(t, len(msg.scalars.v_bytes) == 4, "v_bytes len")
    if len(msg.scalars.v_bytes) == 4 {
        testing.expect_value(t, msg.scalars.v_bytes[0], 1)
        testing.expect_value(t, msg.scalars.v_bytes[3], 4)
    }

    // Repeateds
    testing.expect(t, len(msg.repeateds.r_int32) == 5, "r_int32 len")
    if len(msg.repeateds.r_int32) == 5 {
        testing.expect_value(t, msg.repeateds.r_int32[0], 1)
        testing.expect_value(t, msg.repeateds.r_int32[4], 5)
    }

    testing.expect(t, len(msg.repeateds.r_nested) == 2, "r_nested len")
    if len(msg.repeateds.r_nested) == 2 {
        testing.expect_value(t, msg.repeateds.r_nested[0].name, "one")
        testing.expect_value(t, msg.repeateds.r_nested[1].flag, false)
    }
    
    // Maps
    testing.expect_value(t, msg.maps.m_string_string["key1"], "value1")
    testing.expect_value(t, msg.maps.m_uint32_enum[1], odin.Status.DELETED)
    
    // Top-level
    testing.expect_value(t, msg.nested.id, 99)
    testing.expect_value(t, msg.nested.name, "top nested")
    testing.expect_value(t, msg.nested.flag, true)
    testing.expect_value(t, msg.status, odin.Status.ACTIVE)
}
