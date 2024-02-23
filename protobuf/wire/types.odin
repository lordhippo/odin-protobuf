package protobuf_wire

import "base:intrinsics"

// [---wire_type---]     ------ builtin_type ----->      [-----final_odin_type----]
// the builtin_type is important for encoding and decoding, as for example wire_type of VARINT 
// can be decoded to signed integers in multiple ways: 2's complement (intN) vs zig-zag (sintN)

Builtin_Types :: enum uint {
	// VARINT-backing
	t_int32    = 1,
	t_int64    = 2,
	t_uint32   = 3,
	t_uint64   = 4,
	t_bool     = 5,
	t_enum     = 6,
	t_sint32   = 7,
	t_sint64   = 8,
	// I32-backing
	t_sfixed32 = 9,
	t_fixed32  = 10,
	t_float    = 11,
	// I64-backing
	t_sfixed64 = 12,
	t_fixed64  = 13,
	t_double   = 14,
	// LEN-backing
	t_message  = 15,
	t_string   = 16,
	t_bytes    = 17,
	t_packed   = 18,
}

// VARINT-backing

cast_int32 :: proc(value: Value_VARINT) -> i32 {
	// TODO: verify if 32-bits int also occupy 64 bits when negative
	return i32(cast_int64(value))
}

cast_int64 :: proc(value: Value_VARINT) -> i64 {
	return transmute(i64)value
}

cast_uint32 :: proc(value: Value_VARINT) -> u32 {
	return u32(value)
}

cast_uint64 :: proc(value: Value_VARINT) -> u64 {
	return u64(value)
}

cast_bool :: proc(value: Value_VARINT) -> bool {
	// Bools are encoded as if they were int32s
	value_i32 := cast_int32(value)
	assert(
		value_i32 == 0x00 || value_i32 == 0x01,
		"Bools should always encode as either `00` or `01`",
	)
	return bool(value_i32)
}

cast_enum :: cast_int32

cast_sint32 :: proc(value: Value_VARINT) -> i32 {
	abs_value := i32(value >> 1)
	return abs_value if (value & 1) == 0 else -abs_value
}

cast_sint64 :: proc(value: Value_VARINT) -> i64 {
	abs_value := i64(value >> 1)
	return abs_value if (value & 1) == 0 else -abs_value
}

// I32-backing

cast_sfixed32 :: proc(value: Value_I32) -> i32 {
	return i32(value)
}

cast_fixed32 :: proc(value: Value_I32) -> u32 {
	return transmute(u32)value
}

cast_float :: proc(value: Value_I32) -> f32 {
	return transmute(f32)value
}

// I64-backing

cast_sfixed64 :: proc(value: Value_I64) -> i64 {
	return i64(value)
}

cast_fixed64 :: proc(value: Value_I64) -> u64 {
	return transmute(u64)value
}

cast_double :: proc(value: Value_I64) -> f64 {
	return transmute(f64)value
}

// LEN-backing

cast_message :: proc(value: Value_LEN) -> (Message, bool) {
	return decode(cast_bytes(value))
}

cast_string :: proc(value: Value_LEN) -> string {
	return string(value)
}

cast_bytes :: proc(value: Value_LEN) -> []u8 {
	return ([]u8)(value)
}

cast_packed :: proc(value: Value_LEN) -> []Value {
	unimplemented()
}
