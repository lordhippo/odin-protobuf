package protobuf_builtins

import "../wire"

// VARINT-backing

decode_int32 :: proc(value: wire.Value_VARINT) -> i32 {
	return i32(decode_int64(value))
}

decode_int64 :: proc(value: wire.Value_VARINT) -> i64 {
	return cast(i64)value
}

decode_uint32 :: proc(value: wire.Value_VARINT) -> u32 {
	return u32(value)
}

decode_uint64 :: proc(value: wire.Value_VARINT) -> u64 {
	return u64(value)
}

decode_bool :: proc(value: wire.Value_VARINT) -> bool {
	// Protobuf parsers must accept any non-zero value as true
	return value != 0
}

decode_enum :: proc(value: wire.Value_VARINT) -> Enum_Wire_Type {
	return Enum_Wire_Type(decode_int32(value))
}

decode_sint32 :: proc(value: wire.Value_VARINT) -> i32 {
	value_u32 := u32(value)
	return cast(i32)((value_u32 >> 1) ~ u32(-i32(value_u32 & 1)))
}

decode_sint64 :: proc(value: wire.Value_VARINT) -> i64 {
	value_u64 := u64(value)
	return cast(i64)((value_u64 >> 1) ~ u64(-i64(value_u64 & 1)))
}

// I32-backing

decode_sfixed32 :: proc(value: wire.Value_I32) -> i32 {
	return i32(value)
}

decode_fixed32 :: proc(value: wire.Value_I32) -> u32 {
	return cast(u32)value
}

decode_float :: proc(value: wire.Value_I32) -> f32 {
	return transmute(f32)value
}

// I64-backing

decode_sfixed64 :: proc(value: wire.Value_I64) -> i64 {
	return i64(value)
}

decode_fixed64 :: proc(value: wire.Value_I64) -> u64 {
	return cast(u64)value
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
