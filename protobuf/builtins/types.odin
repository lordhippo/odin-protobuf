package protobuf_builtins

// [---wire_type---]     ------ builtin_type ----->      [-----final_odin_type----]
// the builtin_type is important for encoding and decoding, as for example wire_type of VARINT 
// can be decoded to signed integers in multiple ways: 2's complement (intN) vs zig-zag (sintN)

Types :: enum uint {
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
