package protobuf_wire

import "core:encoding/varint"
import "core:fmt"
import "core:math/bits"

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
