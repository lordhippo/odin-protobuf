package protobuf_builtins

import "../wire"

// [---wire_type---]     ------ builtin_type ----->      [-----final_odin_type----]
// the builtin_type is important for encoding and decoding, as for example wire_type of VARINT 
// can be decoded to signed integers in multiple ways: 2's complement (intN) vs zig-zag (sintN)

// Values correspond to FieldDescriptorProto.Type entries
Type :: enum uint {
	// VARINT-backing
	t_int32    = 5,
	t_int64    = 3,
	t_uint32   = 13,
	t_uint64   = 4,
	t_bool     = 8,
	t_enum     = 14,
	t_sint32   = 17,
	t_sint64   = 18,
	// I32-backing
	t_sfixed32 = 15,
	t_fixed32  = 7,
	t_float    = 2,
	// I64-backing
	t_sfixed64 = 16,
	t_fixed64  = 6,
	t_double   = 1,
	// LEN-backing
	t_message  = 11,
	t_string   = 9,
	t_bytes    = 12,
	// GROUP
	t_group = 10,
}

wire_type :: proc(type: Type) -> wire.Type {
	switch type {
		case .t_int32, .t_int64, .t_uint32, .t_uint64, .t_bool, .t_enum, .t_sint32, .t_sint64:
			return .VARINT
		case .t_sfixed32, .t_fixed32, .t_float:
			return .I32
		case .t_sfixed64, .t_fixed64, .t_double:
			return .I64
		case .t_message, .t_string, .t_bytes:
			return .LEN
		case .t_group:
			return .EGROUP
	}

	return nil
}
