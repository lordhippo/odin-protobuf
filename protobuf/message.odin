package protobuf

import "core:fmt"
import "core:reflect"
import "core:strconv"

import "wire"

get_field_ptr :: proc($T: typeid, a: any, offset: uintptr) -> ^T {
	raw_ptr := rawptr(uintptr(a.data) + offset)
	return transmute(^T)raw_ptr
}

decode :: proc($T: typeid, buffer: []u8) -> (decoded: T, ok: bool) {
	raw_message := wire.decode(buffer) or_return

	type_names := reflect.struct_field_names(T)
	type_offsets := reflect.struct_field_offsets(T)
	type_tags := reflect.struct_field_tags(T)

	for field_tag, field_idx in type_tags {
		tag_id_str := reflect.struct_tag_lookup(field_tag, "id") or_return
		tag_id := u32(strconv.parse_uint(tag_id_str) or_return)

		tag_type_str := reflect.struct_tag_lookup(field_tag, "type") or_return
		tag_type_int := strconv.parse_uint(tag_type_str) or_return
		tag_type := wire.Builtin_Types(tag_type_int)

		fmt.printf(
			"field %v | id: %v | type: %v\n",
			type_names[field_idx],
			tag_id,
			tag_type,
		)

		field_offset := type_offsets[field_idx]
		field_ptr := rawptr(uintptr(&decoded) + field_offset)

		message_field := &raw_message.fields[tag_id]
		last_value := message_field.values[len(message_field.values) - 1]

		switch tag_type {
			// VARINT-backing
			case .t_int32:
				(transmute(^i32)field_ptr)^ = wire.cast_int32(
					last_value.(wire.Value_VARINT),
				)
			case .t_int64:
				(transmute(^i64)field_ptr)^ = wire.cast_int64(
					last_value.(wire.Value_VARINT),
				)
			case .t_uint32:
				(transmute(^u32)field_ptr)^ = wire.cast_uint32(
					last_value.(wire.Value_VARINT),
				)
			case .t_uint64:
				(transmute(^u64)field_ptr)^ = wire.cast_uint64(
					last_value.(wire.Value_VARINT),
				)
			case .t_bool:
				(transmute(^bool)field_ptr)^ = wire.cast_bool(
					last_value.(wire.Value_VARINT),
				)
			case .t_enum:
				(transmute(^i32)field_ptr)^ = wire.cast_enum(
					last_value.(wire.Value_VARINT),
				)
			case .t_sint32:
				(transmute(^i32)field_ptr)^ = wire.cast_sint32(
					last_value.(wire.Value_VARINT),
				)
			case .t_sint64:
				(transmute(^i64)field_ptr)^ = wire.cast_sint64(
					last_value.(wire.Value_VARINT),
				)
			// I32-backing
			case .t_sfixed32:
				(transmute(^i32)field_ptr)^ = wire.cast_sfixed32(
					last_value.(wire.Value_I32),
				)
			case .t_fixed32:
				(transmute(^u32)field_ptr)^ = wire.cast_fixed32(
					last_value.(wire.Value_I32),
				)
			case .t_float:
				(transmute(^f32)field_ptr)^ = wire.cast_float(
					last_value.(wire.Value_I32),
				)
			// I64-backing
			case .t_sfixed64:
				(transmute(^i64)field_ptr)^ = wire.cast_sfixed64(
					last_value.(wire.Value_I64),
				)
			case .t_fixed64:
				(transmute(^u64)field_ptr)^ = wire.cast_fixed64(
					last_value.(wire.Value_I64),
				)
			case .t_double:
				(transmute(^f64)field_ptr)^ = wire.cast_double(
					last_value.(wire.Value_I64),
				)
			// LEN-backing
			case .t_message:
				unimplemented()
			case .t_string:
				(transmute(^string)field_ptr)^ = wire.cast_string(
					last_value.(wire.Value_LEN),
				)
			case .t_bytes:
				(transmute(^([]u8))field_ptr)^ = wire.cast_bytes(
					last_value.(wire.Value_LEN),
				)
			case .t_packed:
				unimplemented()
		}

	}

	return decoded, true
}

encode :: proc(message: $T) -> (buffer: []u8, ok: bool) {
	unimplemented()
}
