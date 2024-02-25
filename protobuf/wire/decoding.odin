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
		case .None:
			fmt.eprintf("can't decode value when no type is provided")
			return value, false
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

decode_packed :: proc(value: Value_LEN, elem_type: Type) -> (result: []Value, ok: bool) {
	if elem_type != .VARINT && elem_type != .I32 && elem_type != .I64 {
		fmt.eprintf(
			"%v is not a valid type for packed field. packed fields should only contain primitive types\n",
			elem_type,
		)
		return result, false
	}

	buffer := ([]u8)(value)
	elems := make([dynamic]Value, context.temp_allocator)
	for index := 0; index < len(value); {
		elem := decode_value(buffer, elem_type, &index) or_return
		append(&elems, elem)
	}

	return elems[:], true
}

decode :: proc(buffer: []u8) -> (message: Message, ok: bool) {
	message.fields = make(map[u32]Field)

	value_map := make_map(map[u32]([dynamic]Value), allocator = context.temp_allocator)

	for index := 0; index < len(buffer); {
		tag := decode_tag(buffer, &index) or_return
		value := decode_value(buffer, tag.type, &index) or_return

		if tag.field_number not_in value_map {
			value_map[tag.field_number] = make(
				[dynamic]Value,
				allocator = context.temp_allocator,
			)

			message.fields[tag.field_number] = {
				tag = tag,
			}
		}

		append_elem(&value_map[tag.field_number], value)
	}

	for id, value in value_map {
		field := &message.fields[id]
		field^ = Field {
			tag    = field.tag,
			values = value[:],
		}
	}

	return message, true
}
