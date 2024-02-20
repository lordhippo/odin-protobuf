package protobuf

// This is an implementation of the protobuf wire format
// https://protobuf.dev/programming-guides/encoding/

// message    := (tag value)*
// 
// tag        := (field << 3) bit-or wire_type;
//                 encoded as uint32 varint
// value      := varint      for wire_type == VARINT,
//               i32         for wire_type == I32,
//               i64         for wire_type == I64,
//               len-prefix  for wire_type == LEN,
//               <empty>     for wire_type == SGROUP or EGROUP
// 
// varint     := int32 | int64 | uint32 | uint64 | bool | enum | sint32 | sint64;
//                 encoded as varints (sintN are ZigZag-encoded first)
// i32        := sfixed32 | fixed32 | float;
//                 encoded as 4-byte little-endian;
//                 memcpy of the equivalent C types (u?int32_t, float)
// i64        := sfixed64 | fixed64 | double;
//                 encoded as 8-byte little-endian;
//                 memcpy of the equivalent C types (u?int64_t, double)
// 
// len-prefix := size (message | string | bytes | packed);
//                 size encoded as int32 varint
// string     := valid UTF-8 string (e.g. ASCII);
//                 max 2GB of bytes
// bytes      := any sequence of 8-bit bytes;
//                 max 2GB of bytes
// packed     := varint* | i32* | i64*,
//                 consecutive values of the type specified in `.proto`

import "base:intrinsics"
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
	u64, // VARINT
	i32, // I32
	i64, // I64
	[dynamic]u8, // LEN
}

Field :: struct {
	tag:   Tag,
	value: Value,
}

Message :: struct {
	fields: map[u32]Field,
}

decode_varint :: proc($T: typeid, buffer: []u8, index: ^int) -> (T,	bool) {
	value, size, error := varint.decode_uleb128(buffer[index^:])
	index^ += size
	return T(value), error == .None
}

decode_fixed :: proc($T: typeid, buffer: []u8, index: ^int) -> (T, bool) {
	if index^ + size_of(T) >= len(buffer) {
		return 0, false
	}

	// TODO: handle endianness
	value := (^T)(&buffer[index^])^
	index^ += size_of(T)

	return value, true
}

decode_tag :: proc(buffer: []u8, index: ^int) -> (tag: Tag, ok: bool) {
	value := decode_varint(u32, buffer, index) or_return
	ok = true

	tag.type = Type(bits.bitfield_extract(value, 0, 3))
	tag.field_number = u32(bits.bitfield_extract(value, 3, 29))

	return tag, ok
}

decode_value :: proc(buffer: []u8, type: Type, index: ^int) -> (value: Value, ok: bool) {
	switch type {
		case .VARINT:
			value = decode_varint(u64, buffer, index) or_return
			ok = true
		case .I32:
			value = decode_fixed(i32, buffer, index) or_return
			ok = true
		case .I64:
			value = decode_fixed(i64, buffer, index) or_return
			ok = true
		case .LEN:
			len := decode_varint(int, buffer, index) or_return
			value = make([dynamic]u8, len)
			copy(value.([dynamic]u8)[:], buffer[index^:index^ + len])
			index^ += len
			ok = true
		case .SGROUP, .EGROUP:
			fmt.eprintf("%v field type is deprecated\n", type)
	}

	return value, ok
}

decode :: proc(buffer: []u8) -> (message: Message, ok: bool) {
	message.fields = make(map[u32]Field)

	for index := 0; index < len(buffer); {
		tag := decode_tag(buffer, &index) or_return

		// TODO: merge fields
		message.fields[tag.field_number] = {
			tag   = tag,
			value = decode_value(buffer, tag.type, &index) or_return,
		}
	}

	return message, true
}

encode :: proc(message: Message) -> (buffer: []u8, ok: bool) {
	return
}
