package protobuf_builtins

import "../wire"

// VARINT-backing

encode_int32 :: proc(value: i32) -> wire.Value_VARINT {
	// TODO: verify if 32-bits int also occupy 64 bits when negative
	return encode_int64(i64(value))
}

encode_int64 :: proc(value: i64) -> wire.Value_VARINT {
	return transmute(wire.Value_VARINT)value
}

encode_uint32 :: proc(value: u32) -> wire.Value_VARINT {
	return wire.Value_VARINT(value)
}

encode_uint64 :: proc(value: u64) -> wire.Value_VARINT {
	return wire.Value_VARINT(value)
}

encode_bool :: proc(value: bool) -> wire.Value_VARINT {
	// Bools are encoded as if they were int32s
	value_i32: i32 = 0x01 if value else 0x00
	return encode_int32(value_i32)
}

encode_enum :: proc(value: Enum_Wire_Type) -> wire.Value_VARINT {
	return encode_int32(i32(value))
}

encode_sint32 :: proc(value: i32) -> wire.Value_VARINT {
	value_u32 := transmute(u32)value
	value_zigzag := (value_u32 << 1) ~ (value_u32 >> 31)
	return encode_uint32(value_zigzag)
}

encode_sint64 :: proc(value: i64) -> wire.Value_VARINT {
	value_u64 := transmute(u64)value
	value_zigzag := (value_u64 << 1) ~ (value_u64 >> 63)
	return encode_uint64(value_zigzag)
}

// I32-backing

encode_sfixed32 :: proc(value: i32) -> wire.Value_I32 {
	return wire.Value_I32(value)
}

encode_fixed32 :: proc(value: u32) -> wire.Value_I32 {
	return transmute(wire.Value_I32)value
}

encode_float :: proc(value: f32) -> wire.Value_I32 {
	return transmute(wire.Value_I32)value
}

// I64-backing

encode_sfixed64 :: proc(value: i64) -> wire.Value_I64 {
	return wire.Value_I64(value)
}

encode_fixed64 :: proc(value: u64) -> wire.Value_I64 {
	return transmute(wire.Value_I64)value
}

encode_double :: proc(value: f64) -> wire.Value_I64 {
	return transmute(wire.Value_I64)value
}

// LEN-backing

encode_message :: proc(value: wire.Message) -> (encoded: wire.Value_LEN, ok: bool) {
	value_bytes := wire.encode(value) or_return
	return encode_bytes(value_bytes), true
}

encode_string :: proc(value: string) -> wire.Value_LEN {
	return encode_bytes(transmute([]u8)value)
}

encode_bytes :: proc(value: []u8) -> wire.Value_LEN {
	return wire.Value_LEN(value)
}

encode_packed :: proc(value: []wire.Value) -> wire.Value_LEN {
	unimplemented()
}
