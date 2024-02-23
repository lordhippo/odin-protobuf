package protobuf_message

import "base:runtime"
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
			type         = builtins.wire_type(tag_type),
		}
		wire_values := make([dynamic]wire.Value, context.temp_allocator)

		base_ptr: uintptr
		elem_size: uintptr
		elem_count: uintptr = 1
		elem_typeid: typeid

		if variant, v_ok := field_type.variant.(runtime.Type_Info_Slice); v_ok {
			slice := (transmute(^runtime.Raw_Slice)(field_ptr))

			base_ptr = uintptr(slice.data)
			elem_size = uintptr(variant.elem.size)
			elem_count = uintptr(slice.len)

			elem_typeid = variant.elem.id
		} else {
			base_ptr = uintptr(field_ptr)
			elem_typeid = field_type.id
		}

		// avoid multiple reallocs
		reserve_dynamic_array(&wire_values, int(elem_count))

		for elem_idx in 0 ..< elem_count {
			current_ptr := rawptr(base_ptr + elem_idx * elem_size)
			wire_value := encode_field(
				{data = current_ptr, id = elem_typeid},
				tag_type,
			) or_return

			append(&wire_values, wire_value)
		}

		wire_message.fields[tag_id] = {
			tag    = wire_tag,
			values = wire_values,
		}
	}

	return wire.encode(wire_message)
}

encode_field :: proc(
	field: any,
	type: builtins.Type,
) -> (
	wire_value: wire.Value,
	ok: bool,
) {
	switch type {
		// VARINT-backing
		case .t_int32:
			wire_value = builtins.encode_int32((transmute(^i32)field.data)^)
		case .t_int64:
			wire_value = builtins.encode_int64((transmute(^i64)field.data)^)
		case .t_uint32:
			wire_value = builtins.encode_uint32((transmute(^u32)field.data)^)
		case .t_uint64:
			wire_value = builtins.encode_uint64((transmute(^u64)field.data)^)
		case .t_bool:
			wire_value = builtins.encode_bool((transmute(^bool)field.data)^)
		case .t_enum:
			wire_value = builtins.encode_enum(
				(transmute(^wire.Enum_Wire_Type)field.data)^,
			)
		case .t_sint32:
			wire_value = builtins.encode_sint32((transmute(^i32)field.data)^)
		case .t_sint64:
			wire_value = builtins.encode_sint64((transmute(^i64)field.data)^)
		// I32-backing
		case .t_sfixed32:
			wire_value = builtins.encode_sfixed32((transmute(^i32)field.data)^)
		case .t_fixed32:
			wire_value = builtins.encode_fixed32((transmute(^u32)field.data)^)
		case .t_float:
			wire_value = builtins.encode_float((transmute(^f32)field.data)^)
		// I64-backing
		case .t_sfixed64:
			wire_value = builtins.encode_sfixed64((transmute(^i64)field.data)^)
		case .t_fixed64:
			wire_value = builtins.encode_fixed64((transmute(^u64)field.data)^)
		case .t_double:
			wire_value = builtins.encode_double((transmute(^f64)field.data)^)
		// LEN-backing
		case .t_message:
			field_encoded := encode({data = field.data, id = field.id}) or_return
			wire_value = builtins.encode_bytes(field_encoded)
		case .t_string:
			wire_value = builtins.encode_string((transmute(^string)field.data)^)
		case .t_bytes:
			wire_value = builtins.encode_bytes((transmute(^([]u8))field.data)^)
		case .t_packed:
			unimplemented()
	}

	return wire_value, true
}
