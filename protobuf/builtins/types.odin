package protobuf_builtins

import "../wire"

// [---wire_type---]     ------ builtin_type ----->      [-----final_odin_type----]
// the builtin_type is important for encoding and decoding, as for example wire_type of VARINT 
// can be decoded to signed integers in multiple ways: 2's complement (intN) vs zig-zag (sintN)

Type :: enum uint {
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

wire_type :: proc(type: Type) -> wire.Type {
	switch type {
		case .t_int32, .t_int64, .t_uint32, .t_uint64, .t_bool, .t_enum, .t_sint32, .t_sint64:
			return .VARINT
		case .t_sfixed32, .t_fixed32, .t_float:
			return .I32
		case .t_sfixed64, .t_fixed64, .t_double:
			return .I64
		case .t_message, .t_string, .t_bytes, .t_packed:
			return .LEN
	}

	return nil
}
