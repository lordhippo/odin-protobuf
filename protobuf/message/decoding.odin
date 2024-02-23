package protobuf_message

import "base:runtime"
import "core:reflect"
import "core:strconv"

import "../builtins"
import "../wire"

new_id :: proc(id: typeid) -> (rawptr, bool) {
	size := reflect.size_of_typeid(id)
	align := reflect.align_of_typeid(id)

	ptr, alloc_error := runtime.mem_alloc_bytes(size, align)
	return raw_data(ptr), alloc_error == .None
}

decode :: proc(message_tid: typeid, buffer: []u8) -> (message: any, ok: bool) {
	message = {
		data = (new_id(message_tid) or_return),
		id   = message_tid,
	}

	return message, decode_fill(message, buffer)
}

decode_fill :: proc(message: any, buffer: []u8) -> (ok: bool) {
	wire_message := wire.decode(buffer) or_return

	type_offsets := reflect.struct_field_offsets(message.id)
	type_types := reflect.struct_field_types(message.id)
	type_tags := reflect.struct_field_tags(message.id)

	for field_tag, field_idx in type_tags {
		tag_id_str := reflect.struct_tag_lookup(field_tag, "id") or_return
		tag_id := u32(strconv.parse_uint(tag_id_str) or_return)

		tag_type_str := reflect.struct_tag_lookup(field_tag, "type") or_return
		tag_type_int := strconv.parse_uint(tag_type_str) or_return
		tag_type := builtins.Type(tag_type_int)

		field_offset := type_offsets[field_idx]
		field_ptr := rawptr(uintptr(message.data) + field_offset)

		field_type := type_types[field_idx]

		for value in wire_message.fields[tag_id].values {
			// TODO: in case of array fields, append instead
			decode_fill_field(
				{data = field_ptr, id = field_type.id},
				value,
				tag_type,
			) or_return
		}
	}

	return true
}

decode_fill_field :: proc(field: any, value: wire.Value, type: builtins.Type) -> bool {
	switch type {
		// VARINT-backing
		case .t_int32:
			(transmute(^i32)field.data)^ = builtins.decode_int32(
				value.(wire.Value_VARINT),
			)
		case .t_int64:
			(transmute(^i64)field.data)^ = builtins.decode_int64(
				value.(wire.Value_VARINT),
			)
		case .t_uint32:
			(transmute(^u32)field.data)^ = builtins.decode_uint32(
				value.(wire.Value_VARINT),
			)
		case .t_uint64:
			(transmute(^u64)field.data)^ = builtins.decode_uint64(
				value.(wire.Value_VARINT),
			)
		case .t_bool:
			(transmute(^bool)field.data)^ = builtins.decode_bool(
				value.(wire.Value_VARINT),
			)
		case .t_enum:
			(transmute(^wire.Enum_Wire_Type)field.data)^ = builtins.decode_enum(
				value.(wire.Value_VARINT),
			)
		case .t_sint32:
			(transmute(^i32)field.data)^ = builtins.decode_sint32(
				value.(wire.Value_VARINT),
			)
		case .t_sint64:
			(transmute(^i64)field.data)^ = builtins.decode_sint64(
				value.(wire.Value_VARINT),
			)
		// I32-backing
		case .t_sfixed32:
			(transmute(^i32)field.data)^ = builtins.decode_sfixed32(
				value.(wire.Value_I32),
			)
		case .t_fixed32:
			(transmute(^u32)field.data)^ = builtins.decode_fixed32(
				value.(wire.Value_I32),
			)
		case .t_float:
			(transmute(^f32)field.data)^ = builtins.decode_float(value.(wire.Value_I32))
		// I64-backing
		case .t_sfixed64:
			(transmute(^i64)field.data)^ = builtins.decode_sfixed64(
				value.(wire.Value_I64),
			)
		case .t_fixed64:
			(transmute(^u64)field.data)^ = builtins.decode_fixed64(
				value.(wire.Value_I64),
			)
		case .t_double:
			(transmute(^f64)field.data)^ = builtins.decode_double(value.(wire.Value_I64))
		// LEN-backing
		case .t_message:
			field_bytes := builtins.decode_bytes(value.(wire.Value_LEN))
			decode_fill(field, field_bytes) or_return
		case .t_string:
			// TODO: handle concatenation
			(transmute(^string)field.data)^ = builtins.decode_string(
				value.(wire.Value_LEN),
			)
		case .t_bytes:
			// TODO: handle concatenation
			(transmute(^([]u8))field.data)^ = builtins.decode_bytes(
				value.(wire.Value_LEN),
			)
		case .t_packed:
			unimplemented()
	}

	return true
}
