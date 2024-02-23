package protobuf_message

import "core:reflect"
import "core:strconv"

import "../builtins"
import "../wire"

encode :: proc(message: any) -> (buffer: []u8, ok: bool) {
	wire_message: wire.Message
	wire_message.fields = make(map[u32]wire.Field)

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

		wire_tag: wire.Tag = {
			field_number = tag_id,
		}
		wire_values := make([dynamic]wire.Value, context.temp_allocator)

		switch tag_type {
			// VARINT-backing
			case .t_int32:
				append(&wire_values, builtins.encode_int32((transmute(^i32)field_ptr)^))
				wire_tag.type = .VARINT
			case .t_int64:
				append(&wire_values, builtins.encode_int64((transmute(^i64)field_ptr)^))
				wire_tag.type = .VARINT
			case .t_uint32:
				append(&wire_values, builtins.encode_uint32((transmute(^u32)field_ptr)^))
				wire_tag.type = .VARINT
			case .t_uint64:
				append(&wire_values, builtins.encode_uint64((transmute(^u64)field_ptr)^))
				wire_tag.type = .VARINT
			case .t_bool:
				append(&wire_values, builtins.encode_bool((transmute(^bool)field_ptr)^))
				wire_tag.type = .VARINT
			case .t_enum:
				append(
					&wire_values,
					builtins.encode_enum((transmute(^wire.Enum_Wire_Type)field_ptr)^),
				)
				wire_tag.type = .VARINT
			case .t_sint32:
				append(&wire_values, builtins.encode_sint32((transmute(^i32)field_ptr)^))
				wire_tag.type = .VARINT
			case .t_sint64:
				append(&wire_values, builtins.encode_sint64((transmute(^i64)field_ptr)^))
				wire_tag.type = .VARINT
			// I32-backing
			case .t_sfixed32:
				append(
					&wire_values,
					builtins.encode_sfixed32((transmute(^i32)field_ptr)^),
				)
				wire_tag.type = .I32
			case .t_fixed32:
				append(
					&wire_values,
					builtins.encode_fixed32((transmute(^u32)field_ptr)^),
				)
				wire_tag.type = .I32
			case .t_float:
				append(&wire_values, builtins.encode_float((transmute(^f32)field_ptr)^))
				wire_tag.type = .I32
			// I64-backing
			case .t_sfixed64:
				append(
					&wire_values,
					builtins.encode_sfixed64((transmute(^i64)field_ptr)^),
				)
				wire_tag.type = .I64
			case .t_fixed64:
				append(
					&wire_values,
					builtins.encode_fixed64((transmute(^u64)field_ptr)^),
				)
				wire_tag.type = .I64
			case .t_double:
				append(&wire_values, builtins.encode_double((transmute(^f64)field_ptr)^))
				wire_tag.type = .I64
			// LEN-backing
			case .t_message:
				field_encoded := encode({data = field_ptr, id = field_type.id}) or_return
				append(&wire_values, builtins.encode_bytes(field_encoded))
				wire_tag.type = .LEN
			case .t_string:
				append(
					&wire_values,
					builtins.encode_string((transmute(^string)field_ptr)^),
				)
				wire_tag.type = .LEN
			case .t_bytes:
				append(
					&wire_values,
					builtins.encode_bytes((transmute(^([]u8))field_ptr)^),
				)
				wire_tag.type = .LEN
			case .t_packed:
				wire_tag.type = .LEN
				unimplemented()
		}

		wire_message.fields[tag_id] = {
			tag    = wire_tag,
			values = wire_values,
		}
	}

	return wire.encode(wire_message)
}
