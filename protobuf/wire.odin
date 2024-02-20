package protobuf

// This is an implementation of the protobuf wire format
// https://protobuf.dev/programming-guides/encoding/

import "core:encoding/varint"
import "core:fmt"
import "core:math/bits"

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

Value :: union {
	u128, // VARINT
	i32, // I32
	i64, // I64
	[dynamic]u8, // LEN
}

Field :: struct {
	tag:   Tag,
	value: Value,
}

Message :: struct {
	fields: [dynamic]Field,
}

decode_varint :: proc(buffer: []u8, index: ^int) -> (u128, bool) {
	value, size, error := varint.decode_uleb128(buffer[index^:])
	index^ += size
	return value, error == .None
}

decode_tag :: proc(buffer: []u8, index: ^int) -> (tag: Tag, ok: bool) {
	value := decode_varint(buffer, index) or_return
	ok = true

	tag.type = Type(bits.bitfield_extract(value, 0, 3))
	tag.field_number = u32(bits.bitfield_extract(value, 3, 29))

	return tag, ok
}

decode_value :: proc(buffer: []u8, type: Type, index: ^int) -> (value: Value, ok: bool) {
	switch type {
		case .VARINT:
			value = decode_varint(buffer, index) or_return
			ok = true
		case .I32:
		case .I64:
		case .LEN:
		case .SGROUP, .EGROUP:
			fmt.eprintf("%v field type is deprecated\n", type)
	}

	return value, ok
}

decode :: proc(buffer: []u8) -> (message: Message, ok: bool) {
	for index := 0; index < len(buffer); {
		append_nothing(&message.fields)
		field := &message.fields[len(message.fields) - 1]

		field.tag = decode_tag(buffer, &index) or_return
		field.value = decode_value(buffer, field.tag.type, &index) or_return
	}

	ok = true

	return message, ok
}

encode :: proc(message: Message) -> (buffer: []u8, ok: bool) {
	return
}
