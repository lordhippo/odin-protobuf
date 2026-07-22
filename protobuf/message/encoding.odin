package protobuf_message

import "../builtins"
import "../wire"

import "base:runtime"

encode :: proc(message: any) -> (buffer: []u8, ok: bool) {
	return encode_with_allocator(message, context.allocator)
}

encode_with_allocator :: proc(
	message: any,
	allocator: runtime.Allocator,
) -> (
	buffer: []u8,
	ok: bool,
) {
	prev_allocator := context.allocator
	context.allocator = allocator
	defer context.allocator = prev_allocator

	wire_message: wire.Message = {
		fields = make_map(map[u32]wire.Field, allocator = context.allocator),
	}

	field_count := struct_field_count(message) or_return

	for field_idx in 0 ..< field_count {
		field_info := struct_field_info(message, field_idx) or_return
		wire_field: wire.Field

		omit: bool
		switch _ in field_info.type {
		case Field_Type_Scalar:
			wire_field = encode_field_scalar(field_info) or_return
			omit = scalar_is_default(wire_field)
		case Field_Type_Repeated:
			wire_field = encode_field_repeated(field_info) or_return
			omit = repeated_is_empty(field_info, wire_field)
		case Field_Type_Map:
			wire_field = encode_field_map(field_info) or_return
			omit = len(wire_field.values) == 0
		}

		if omit {
			continue
		}

		wire_message.fields[wire_field.tag.field_number] = wire_field
	}

	return wire.encode(wire_message)
}

@(private = "file")
scalar_is_default :: proc(f: wire.Field) -> bool {
	if len(f.values) == 0 {
		return true
	}

	#partial switch f.tag.type {
	case wire.Type.I64:
		return f.values[0].(wire.Value_I64) == 0
	case wire.Type.LEN:
		return len(f.values[0].(wire.Value_LEN)) == 0
	case wire.Type.I32:
		return f.values[0].(wire.Value_I32) == 0
	case wire.Type.VARINT:
		return f.values[0].(wire.Value_VARINT) == 0
	}

	return false
}

@(private = "file")
repeated_is_empty :: proc(field_info: Field_Info, f: wire.Field) -> bool {
	if len(f.values) == 0 {
		return true
	}
	if is_packed(field_info) {
		return len(f.values[0].(wire.Value_LEN)) == 0
	}
	return false
}

@(private = "file")
encode_field_scalar :: proc(field_info: Field_Info) -> (field: wire.Field, ok: bool) {
	field.tag = {
		field_number = field_info.proto_id,
		type         = builtins.wire_type(field_info.proto_type),
	}

	field.values = make_slice([]wire.Value, 1, context.allocator)
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

	field.values = make_slice([]wire.Value, slice_data.len, context.allocator)

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
		field.values = make_slice([]wire.Value, 1, context.allocator)
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
		allocator = context.allocator,
	)

	entry_fields := make_map_cap(
		map[u32]wire.Field,
		capacity = 2,
		allocator = context.allocator,
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
		wire_value = builtins.encode_int32((cast(^i32)field.data)^)
	case .t_int64:
		wire_value = builtins.encode_int64((cast(^i64)field.data)^)
	case .t_uint32:
		wire_value = builtins.encode_uint32((cast(^u32)field.data)^)
	case .t_uint64:
		wire_value = builtins.encode_uint64((cast(^u64)field.data)^)
	case .t_bool:
		wire_value = builtins.encode_bool((cast(^bool)field.data)^)
	case .t_enum:
		wire_value = builtins.encode_enum((cast(^builtins.Enum_Wire_Type)field.data)^)
	case .t_sint32:
		wire_value = builtins.encode_sint32((cast(^i32)field.data)^)
	case .t_sint64:
		wire_value = builtins.encode_sint64((cast(^i64)field.data)^)
	// I32-backing
	case .t_sfixed32:
		wire_value = builtins.encode_sfixed32((cast(^i32)field.data)^)
	case .t_fixed32:
		wire_value = builtins.encode_fixed32((cast(^u32)field.data)^)
	case .t_float:
		wire_value = builtins.encode_float((cast(^f32)field.data)^)
	// I64-backing
	case .t_sfixed64:
		wire_value = builtins.encode_sfixed64((cast(^i64)field.data)^)
	case .t_fixed64:
		wire_value = builtins.encode_fixed64((cast(^u64)field.data)^)
	case .t_double:
		wire_value = builtins.encode_double((cast(^f64)field.data)^)
	// LEN-backing
	case .t_message:
		field_encoded := encode({data = field.data, id = field.id}) or_return
		wire_value = builtins.encode_bytes(field_encoded)
	case .t_string:
		wire_value = builtins.encode_string((cast(^string)field.data)^)
	case .t_bytes:
		wire_value = builtins.encode_bytes((cast(^([]u8))field.data)^)
	case .t_group:
		unimplemented()
	}

	return wire_value, true
}
