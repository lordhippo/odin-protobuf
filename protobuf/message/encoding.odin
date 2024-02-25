package protobuf_message

import "../builtins"
import "../wire"

encode :: proc(message: any) -> (buffer: []u8, ok: bool) {
	wire_message: wire.Message
	wire_message.fields = make_map(
		map[u32]wire.Field,
		allocator = context.temp_allocator,
	)

	field_count := struct_field_count(message) or_return

	for field_idx in 0 ..< field_count {
		field_info := struct_field_info(message, field_idx) or_return

		base_ptr: uintptr
		elem_size: uintptr
		elem_count: uintptr = 1
		elem_typeid: typeid

		switch type_variant in field_info.type {
			case Field_Type_Scalar:
				base_ptr = uintptr(field_info.data.(Field_Data_Scalar))
				elem_typeid = type_variant.type
			case Field_Type_Repeated:
				slice := field_info.data.(Field_Data_Repeated)

				base_ptr = uintptr(slice.data)
				elem_count = uintptr(slice.len)

				elem_size = uintptr(type_variant.elem_size)
				elem_typeid = type_variant.elem_type
			case Field_Type_Map:
				unimplemented()
		}

		wire_values := make_slice([]wire.Value, int(elem_count), context.temp_allocator)

		for elem_idx in 0 ..< elem_count {
			current_ptr := rawptr(base_ptr + elem_idx * elem_size)
			wire_values[elem_idx] = encode_field(
				{data = current_ptr, id = elem_typeid},
				field_info.proto_type,
			) or_return
		}

		wire_tag: wire.Tag = {
			field_number = field_info.proto_id,
			type         = builtins.wire_type(field_info.proto_type),
		}

		// Compact values into one LEN-type value
		if is_packed(field_info) {
			packed_val := wire.encode_packed(wire_values) or_return
			wire_values = {packed_val}

			wire_tag.type = .LEN
		}

		wire_message.fields[field_info.proto_id] = {
			tag    = wire_tag,
			values = wire_values,
		}
	}

	return wire.encode(wire_message)
}

@(private = "file")
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
				(transmute(^builtins.Enum_Wire_Type)field.data)^,
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
		case .t_group:
			unimplemented()
	}

	return wire_value, true
}
