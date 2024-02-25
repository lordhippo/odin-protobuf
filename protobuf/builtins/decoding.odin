package protobuf_builtins

import "../wire"

// VARINT-backing

decode_int32 :: proc(value: wire.Value_VARINT) -> i32 {
	// TODO: verify if 32-bits int also occupy 64 bits when negative
	return i32(decode_int64(value))
}

decode_int64 :: proc(value: wire.Value_VARINT) -> i64 {
	return transmute(i64)value
}

decode_uint32 :: proc(value: wire.Value_VARINT) -> u32 {
	return u32(value)
}

decode_uint64 :: proc(value: wire.Value_VARINT) -> u64 {
	return u64(value)
}

decode_bool :: proc(value: wire.Value_VARINT) -> bool {
	// Bools are encoded as if they were int32s
	value_i32 := decode_int32(value)
	assert(
		value_i32 == 0x00 || value_i32 == 0x01,
		"Bools should always encode as either `00` or `01`",
	)
	return bool(value_i32)
}

decode_enum :: proc(value: wire.Value_VARINT) -> Enum_Wire_Type {
	return Enum_Wire_Type(decode_int32(value))
}

decode_sint32 :: proc(value: wire.Value_VARINT) -> i32 {
	abs_value := i32(value >> 1)
	return abs_value if (value & 1) == 0 else -abs_value
}

decode_sint64 :: proc(value: wire.Value_VARINT) -> i64 {
	abs_value := i64(value >> 1)
	return abs_value if (value & 1) == 0 else -abs_value
}

// I32-backing

decode_sfixed32 :: proc(value: wire.Value_I32) -> i32 {
	return i32(value)
}

decode_fixed32 :: proc(value: wire.Value_I32) -> u32 {
	return transmute(u32)value
}

decode_float :: proc(value: wire.Value_I32) -> f32 {
	return transmute(f32)value
}

// I64-backing

decode_sfixed64 :: proc(value: wire.Value_I64) -> i64 {
	return i64(value)
}

decode_fixed64 :: proc(value: wire.Value_I64) -> u64 {
	return transmute(u64)value
}

decode_double :: proc(value: wire.Value_I64) -> f64 {
	return transmute(f64)value
}

// LEN-backing

decode_message :: proc(value: wire.Value_LEN) -> (wire.Message, bool) {
	return wire.decode(decode_bytes(value))
}

decode_string :: proc(value: wire.Value_LEN) -> string {
	return string(value)
}

decode_bytes :: proc(value: wire.Value_LEN) -> []u8 {
	return ([]u8)(value)
}

decode_packed :: proc(value: wire.Value_LEN) -> []wire.Value {
	unimplemented()
}
