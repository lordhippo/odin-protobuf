package protobuf_message

import "base:runtime"
import "core:reflect"
import "core:strconv"

import "../builtins"
import "../wire"

decode :: proc(message_tid: typeid, buffer: []u8) -> (message: any, ok: bool) {
	message_size := reflect.size_of_typeid(message_tid)
	message_align := reflect.align_of_typeid(message_tid)

	message_ptr, alloc_error := runtime.mem_alloc_bytes(message_size, message_align)
	if alloc_error != .None {
		return message, false
	}

	message = {
		data = raw_data(message_ptr),
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
		tag_type := builtins.Types(tag_type_int)

		field_offset := type_offsets[field_idx]
		field_ptr := rawptr(uintptr(message.data) + field_offset)

		field_type := type_types[field_idx]

		message_field := &wire_message.fields[tag_id]
		last_value := message_field.values[len(message_field.values) - 1]

		switch tag_type {
			// VARINT-backing
			case .t_int32:
				(transmute(^i32)field_ptr)^ = builtins.decode_int32(
					last_value.(wire.Value_VARINT),
				)
			case .t_int64:
				(transmute(^i64)field_ptr)^ = builtins.decode_int64(
					last_value.(wire.Value_VARINT),
				)
			case .t_uint32:
				(transmute(^u32)field_ptr)^ = builtins.decode_uint32(
					last_value.(wire.Value_VARINT),
				)
			case .t_uint64:
				(transmute(^u64)field_ptr)^ = builtins.decode_uint64(
					last_value.(wire.Value_VARINT),
				)
			case .t_bool:
				(transmute(^bool)field_ptr)^ = builtins.decode_bool(
					last_value.(wire.Value_VARINT),
				)
			case .t_enum:
				(transmute(^wire.Enum_Wire_Type)field_ptr)^ = builtins.decode_enum(
					last_value.(wire.Value_VARINT),
				)
			case .t_sint32:
				(transmute(^i32)field_ptr)^ = builtins.decode_sint32(
					last_value.(wire.Value_VARINT),
				)
			case .t_sint64:
				(transmute(^i64)field_ptr)^ = builtins.decode_sint64(
					last_value.(wire.Value_VARINT),
				)
			// I32-backing
			case .t_sfixed32:
				(transmute(^i32)field_ptr)^ = builtins.decode_sfixed32(
					last_value.(wire.Value_I32),
				)
			case .t_fixed32:
				(transmute(^u32)field_ptr)^ = builtins.decode_fixed32(
					last_value.(wire.Value_I32),
				)
			case .t_float:
				(transmute(^f32)field_ptr)^ = builtins.decode_float(
					last_value.(wire.Value_I32),
				)
			// I64-backing
			case .t_sfixed64:
				(transmute(^i64)field_ptr)^ = builtins.decode_sfixed64(
					last_value.(wire.Value_I64),
				)
			case .t_fixed64:
				(transmute(^u64)field_ptr)^ = builtins.decode_fixed64(
					last_value.(wire.Value_I64),
				)
			case .t_double:
				(transmute(^f64)field_ptr)^ = builtins.decode_double(
					last_value.(wire.Value_I64),
				)
			// LEN-backing
			case .t_message:
				field_bytes := builtins.decode_bytes(last_value.(wire.Value_LEN))
				decode_fill(
					{data = field_ptr, id = field_type.id},
					field_bytes,
				) or_return
			case .t_string:
				(transmute(^string)field_ptr)^ = builtins.decode_string(
					last_value.(wire.Value_LEN),
				)
			case .t_bytes:
				(transmute(^([]u8))field_ptr)^ = builtins.decode_bytes(
					last_value.(wire.Value_LEN),
				)
			case .t_packed:
				unimplemented()
		}

	}

	return true
}
