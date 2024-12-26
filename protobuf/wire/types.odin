package protobuf_wire

Type :: enum u32 {
	VARINT = 0, // int32, int64, uint32, uint64, sint32, sint64, bool, enum
	I64    = 1, // fixed64, sfixed64, double
	LEN    = 2, // string, bytes, embedded messages, packed repeated fields
	SGROUP = 3, // group start (deprecated)
	EGROUP = 4, // group end (deprecated)
	I32    = 5, // fixed32, sfixed32, float
}

Tag :: struct {
	type:         Type,
	field_number: u32,
}

Value_VARINT :: distinct u64
Value_I32 :: distinct i32
Value_I64 :: distinct i64
Value_LEN :: distinct []u8

Value :: union {
	Value_VARINT, // VARINT
	Value_I32, // I32
	Value_I64, // I64
	Value_LEN, // LEN
}

Field :: struct {
	tag:    Tag,
	// - non-repeated fields:
	//     - scalar types: last one wins
	//     - string / byte[]: concatenate
	//     - message: merge (concatenate at this level)
	// - repeated fields: array
	values: []Value,
}

Message :: struct {
	fields: map[u32]Field,
}
