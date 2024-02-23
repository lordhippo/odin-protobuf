package protobuf_wire

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
	values: [dynamic]Value,
}

Message :: struct {
	fields: map[u32]Field,
}

@(private = "file")
decode_varint :: proc(buffer: []u8, index: ^int) -> (Value_VARINT, bool) {
	value, size, error := varint.decode_uleb128(buffer[index^:])
	index^ += size
	return Value_VARINT(value), error == .None
}

@(private = "file")
decode_fixed :: proc(
	$T: typeid,
	buffer: []u8,
	index: ^int,
) -> (
	T,
	bool,
) where T == Value_I32 ||
	T == Value_I64 {
	if index^ + size_of(T) >= len(buffer) {
		return 0, false
	}

	// TODO: handle endianness
	value := (^T)(&buffer[index^])^
	index^ += size_of(T)

	return value, true
}

@(private = "file")
decode_tag :: proc(buffer: []u8, index: ^int) -> (tag: Tag, ok: bool) {
	value_varint := decode_varint(buffer, index) or_return
	value := u32(value_varint)

	tag.type = Type(bits.bitfield_extract(value, 0, 3))
	tag.field_number = u32(bits.bitfield_extract(value, 3, 29))

	return tag, true
}

@(private = "file")
decode_value :: proc(buffer: []u8, type: Type, index: ^int) -> (value: Value, ok: bool) {
	switch type {
		case .VARINT:
			value = decode_varint(buffer, index) or_return
			ok = true
		case .I32:
			value = decode_fixed(Value_I32, buffer, index) or_return
			ok = true
		case .I64:
			value = decode_fixed(Value_I64, buffer, index) or_return
			ok = true
		case .LEN:
			len_varint := decode_varint(buffer, index) or_return
			len := int(len_varint)
			value = make(Value_LEN, len)
			copy(([]u8)(value.(Value_LEN)), buffer[index^:index^ + len])
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
		value := decode_value(buffer, tag.type, &index) or_return

		if tag.field_number not_in message.fields {
			message.fields[tag.field_number] = {
				tag    = tag,
				values = make([dynamic]Value),
			}
		}

		field := &message.fields[tag.field_number]
		append(&field.values, value)
	}

	return message, true
}

@(private = "file")
encode_varint :: proc(value: $T, buffer: ^[dynamic]u8) -> bool {
	current_len := len(buffer)
	reserved_len := current_len + varint.LEB128_MAX_BYTES

	non_zero_resize(buffer, reserved_len)

	if encode_size, encode_err := varint.encode_uleb128(
		buffer[current_len:reserved_len],
		u128(value),
	); encode_err == .None {
		non_zero_resize(buffer, current_len + encode_size)
		return true
	} else {
		fmt.eprintf("Failed to encode varint (%v): %v\n", value, encode_err)
		return false
	}
}

@(private = "file")
encode_fixed :: proc(value: $T, buffer: ^[dynamic]u8) -> bool {
	if error := non_zero_resize(buffer, len(buffer) + size_of(T)); error == .None {
		value_ref: ^T = transmute(^T)&buffer[len(buffer) - size_of(T)]
		value_ref^ = value
		return true
	} else {
		return false
	}
}

@(private = "file")
encode_tag :: proc(tag: Tag, buffer: ^[dynamic]u8) -> bool {
	tag_value: u32
	tag_value = bits.bitfield_insert(tag_value, u32(tag.type), 0, 3)
	tag_value = bits.bitfield_insert(tag_value, tag.field_number, 3, 29)

	return encode_varint(tag_value, buffer)
}

@(private = "file")
encode_value :: proc(value: Value, buffer: ^[dynamic]u8) -> bool {
	switch v in value {
		case Value_VARINT:
			encode_varint(v, buffer) or_return
		case Value_I32:
			encode_fixed(v, buffer) or_return
		case Value_I64:
			encode_fixed(v, buffer) or_return
		case Value_LEN:
			encode_varint(u32(len(v)), buffer) or_return
			non_zero_resize(buffer, len(buffer) + len(v))
			copy(buffer[len(buffer) - len(v):], ([]u8)(v))
	}
	return true
}

encode :: proc(message: Message) -> (buffer: [dynamic]u8, ok: bool) {
	buffer = make([dynamic]u8)

	for _, field in message.fields {
		for value in field.values {
			encode_tag(field.tag, &buffer) or_return
			encode_value(value, &buffer) or_return
		}
	}

	return buffer, true
}
