package protobuf_wire

import "core:encoding/varint"
import "core:fmt"
import "core:math/bits"

@(private = "file")
decode_varint :: proc(buffer: []u8, index: ^int) -> (Value_VARINT, bool) {
	value, size, error := varint.decode_uleb128(buffer[index^:])
	index^ += size

	if error != .None {
		fmt.eprintf("Failed to decode varint: %v\n", error)
	}

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
	if index^ + size_of(T) > len(buffer) {
		fmt.eprintf("Failed to decode fixed: buffer too small\n")
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
