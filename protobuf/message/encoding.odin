package protobuf_message

import "../builtins"
import "../wire"

import "base:runtime"

encode :: proc(message: any) -> (buffer: []u8, ok: bool) {
	wire_message: wire.Message = {
		fields = make_map(map[u32]wire.Field, allocator = context.temp_allocator),
	}

	field_count := struct_field_count(message) or_return

	for field_idx in 0 ..< field_count {
		field_info := struct_field_info(message, field_idx) or_return

		wire_field: wire.Field

		switch _ in field_info.type {
			case Field_Type_Scalar:
				wire_field = encode_field_scalar(field_info) or_return
			case Field_Type_Repeated:
				wire_field = encode_field_repeated(field_info) or_return
			case Field_Type_Map:
				wire_field = encode_field_map(field_info) or_return
		}

		wire_message.fields[wire_field.tag.field_number] = wire_field
	}

	return wire.encode(wire_message)
}

@(private = "file")
encode_field_scalar :: proc(field_info: Field_Info) -> (field: wire.Field, ok: bool) {
	field.tag = {
		field_number = field_info.proto_id,
		type         = builtins.wire_type(field_info.proto_type),
	}

	field.values = make_slice([]wire.Value, 1, context.temp_allocator)
	field.values[0] = encode_field_value(
		 {
			data = rawptr(field_info.data.(Field_Data_Scalar)),
			id = field_info.type.(Field_Type_Scalar).type,
		},
		field_info.proto_type,
	) or_return

	return field, true
}

@(private = "file")
encode_field_repeated :: proc(field_info: Field_Info) -> (field: wire.Field, ok: bool) {
	field.tag.field_number = field_info.proto_id
	if is_packed(field_info) {
		field.tag.type = .LEN
	} else {
		field.tag.type = builtins.wire_type(field_info.proto_type)
	}

	slice_data := field_info.data.(Field_Data_Repeated)
	slice_info := field_info.type.(Field_Type_Repeated)

	field.values = make_slice([]wire.Value, slice_data.len, context.temp_allocator)

	for elem_idx in 0 ..< slice_data.len {
		offset := uintptr(elem_idx * slice_info.elem_size)
		current_ptr := rawptr(uintptr(slice_data.data) + offset)
		field.values[elem_idx] = encode_field_value(
			{data = current_ptr, id = slice_info.elem_type},
			field_info.proto_type,
		) or_return
	}

	// Compact values into one LEN-type value
	if is_packed(field_info) {
		packed_val := wire.encode_packed(field.values) or_return
		field.values = make_slice([]wire.Value, 1, context.temp_allocator)
		field.values[0] = packed_val
	}

	return field, true
}

@(private = "file")
encode_field_map :: proc(field_info: Field_Info) -> (field: wire.Field, ok: bool) {
	field.tag = {
		field_number = field_info.proto_id,
		type         = builtins.wire_type(field_info.proto_type),
	}

	map_type := field_info.type.(Field_Type_Map)

	key_field_info: Field_Info = {
		proto_id   = map_type.key.proto_id,
		proto_type = map_type.key.proto_type,
		type       = map_type.key.type,
	}

	value_field_info: Field_Info = {
		proto_id   = map_type.value.proto_id,
		proto_type = map_type.value.proto_type,
		type       = map_type.value.type,
	}

	map_data := field_info.data.(Field_Data_Map)

	ks, vs, hashes, _, _ := runtime.map_kvh_data_dynamic(map_data^, map_type.map_info)

	entry_count := int(runtime.map_cap(map_data^))
	values := make_dynamic_array_len_cap(
		[dynamic]wire.Value,
		len = 0,
		cap = entry_count,
		allocator = context.temp_allocator,
	)

	entry_fields := make_map(
		map[u32]wire.Field,
		capacity = 2,
		allocator = context.temp_allocator,
	)

	for entry_idx := 0; entry_idx < entry_count; entry_idx += 1 {
		hash := hashes[entry_idx]
		if !runtime.map_hash_is_valid(hash) {
			continue
		}

		clear_map(&entry_fields)
		entry_wire: wire.Message = {
			fields = entry_fields,
		}

		key_ptr := runtime.map_cell_index_dynamic(
			ks,
			map_type.map_info.ks,
			uintptr(entry_idx),
		)
		value_ptr := runtime.map_cell_index_dynamic(
			vs,
			map_type.map_info.vs,
			uintptr(entry_idx),
		)

		key_field_info.data = Field_Data_Scalar(key_ptr)
		value_field_info.data = Field_Data_Scalar(value_ptr)

		entry_wire.fields[key_field_info.proto_id] = encode_field_scalar(
			key_field_info,
		) or_return
		entry_wire.fields[value_field_info.proto_id] = encode_field_scalar(
			value_field_info,
		) or_return

		entry_encoded := wire.encode(entry_wire) or_return
		append(&values, builtins.encode_bytes(entry_encoded))
	}

	field.values = values[:]

	return field, true
}

@(private = "file")
encode_field_value :: proc(
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
