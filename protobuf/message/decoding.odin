package protobuf_message

import "../builtins"
import "../wire"

import "base:runtime"

decode :: proc($T: typeid, buffer: []u8) -> (message: ^T, ok: bool) {
	return decode_with_allocator(T, buffer, context.allocator)
}

decode_with_allocator :: proc(
	$T: typeid,
	buffer: []u8,
	allocator: runtime.Allocator,
) -> (
	message: ^T,
	ok: bool,
) {
	prev_allocator := context.allocator
	context.allocator = allocator
	defer context.allocator = prev_allocator

	msg, success := new_scalar(typeid_of(T))
	if !success {
		return nil, false
	}

	filled := decode_fill(msg, buffer)
	return cast(^T)msg.data, filled
}

@(private = "file")
decode_fill :: proc(message: any, buffer: []u8) -> (ok: bool) {
	wire_message := wire.decode(buffer) or_return
	field_count := struct_field_count(message) or_return

	for field_idx in 0 ..< field_count {
		field_info := struct_field_info(message, field_idx) or_return
		wire_field := wire_message.fields[field_info.proto_id]

		switch type_variant in field_info.type {
		case Field_Type_Scalar:
			decode_field_scalar(field_info, wire_field) or_return
		case Field_Type_Repeated:
			decode_field_repeated(field_info, wire_field) or_return
		case Field_Type_Map:
			decode_field_map(field_info, wire_field) or_return
		}
	}

	return true
}

@(private = "file")
decode_field_scalar :: proc(field_info: Field_Info, wire_field: wire.Field) -> bool {
	field: any = {
		data = field_info.data.(Field_Data_Scalar),
		id   = field_info.type.(Field_Type_Scalar).type,
	}

	for value in wire_field.values {
		decode_fill_field(field, value, field_info.proto_type) or_return
	}

	return true
}

@(private = "file")
decode_field_repeated :: proc(field_info: Field_Info, wire_field: wire.Field) -> bool {
	values: [dynamic]wire.Value
	values.allocator = context.allocator
	defer delete(values)

	// Expand LEN-type value into an array of values
	if is_packed(field_info) {
		wire_type := builtins.wire_type(field_info.proto_type)
		for wire_value in wire_field.values {
			packed_values := wire.decode_packed(
				wire_value.(wire.Value_LEN),
				wire_type,
			) or_return
			append(&values, ..packed_values)
			delete(packed_values)
		}
	} else {
		append(&values, ..wire_field.values)
	}

	if len(values) == 0 {
		return true
	}

	slice_info := field_info.type.(Field_Type_Repeated)

	slice_data := field_info.data.(Field_Data_Repeated)

	old_len := slice_data^.len
	new_len := old_len + len(values)

	new_slice := new_repeated(slice_info, new_len) or_return

	if old_len > 0 {
		runtime.mem_copy(new_slice.data, slice_data^.data, old_len * slice_info.elem_size)
	}

	slice_data^ = new_slice

	for value, value_idx in values {
		offset := uintptr((old_len + value_idx) * slice_info.elem_size)
		current_ptr := rawptr(uintptr(slice_data^.data) + offset)

		decode_fill_field(
			{data = current_ptr, id = slice_info.elem_type},
			value,
			field_info.proto_type,
		) or_return
	}

	return true
}

@(private = "file")
decode_field_map :: proc(field_info: Field_Info, wire_field: wire.Field) -> (ok: bool) {
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
	map_data.allocator = context.allocator

	if alloc_result := runtime.map_reserve_dynamic(
		(^runtime.Raw_Map)(map_data),
		map_type.map_info,
		uintptr(len(wire_field.values)),
	); alloc_result != nil {
		return
	}

	for value in wire_field.values {
		tmp_key_data := new_scalar(
			key_field_info.type.(Field_Type_Scalar).type,
			context.allocator,
		) or_return
		defer free(tmp_key_data.data, context.allocator)

		tmp_value_data := new_scalar(
			value_field_info.type.(Field_Type_Scalar).type,
			context.allocator,
		) or_return
		defer free(tmp_value_data.data, context.allocator)

		entry_bytes := builtins.decode_bytes(value.(wire.Value_LEN))
		entry_message := wire.decode(entry_bytes) or_return

		key_field := entry_message.fields[key_field_info.proto_id]
		value_field := entry_message.fields[value_field_info.proto_id]

		key_field_info.data = Field_Data_Scalar(tmp_key_data.data)
		value_field_info.data = Field_Data_Scalar(tmp_value_data.data)

		decode_field_scalar(key_field_info, key_field) or_return
		decode_field_scalar(value_field_info, value_field) or_return

		if entry := runtime.__dynamic_map_set_without_hash(
			(^runtime.Raw_Map)(map_data),
			map_type.map_info,
			tmp_key_data.data,
			tmp_value_data.data,
		); entry == nil {
			return
		}
	}

	return true
}

@(private = "file")
decode_fill_field :: proc(field: any, value: wire.Value, type: builtins.Type) -> bool {
	switch type {
	// VARINT-backing
	case .t_int32:
		(cast(^i32)field.data)^ = builtins.decode_int32(value.(wire.Value_VARINT))
	case .t_int64:
		(cast(^i64)field.data)^ = builtins.decode_int64(value.(wire.Value_VARINT))
	case .t_uint32:
		(cast(^u32)field.data)^ = builtins.decode_uint32(value.(wire.Value_VARINT))
	case .t_uint64:
		(cast(^u64)field.data)^ = builtins.decode_uint64(value.(wire.Value_VARINT))
	case .t_bool:
		(cast(^bool)field.data)^ = builtins.decode_bool(value.(wire.Value_VARINT))
	case .t_enum:
		(cast(^builtins.Enum_Wire_Type)field.data)^ = builtins.decode_enum(
			value.(wire.Value_VARINT),
		)
	case .t_sint32:
		(cast(^i32)field.data)^ = builtins.decode_sint32(value.(wire.Value_VARINT))
	case .t_sint64:
		(cast(^i64)field.data)^ = builtins.decode_sint64(value.(wire.Value_VARINT))
	// I32-backing
	case .t_sfixed32:
		(cast(^i32)field.data)^ = builtins.decode_sfixed32(value.(wire.Value_I32))
	case .t_fixed32:
		(cast(^u32)field.data)^ = builtins.decode_fixed32(value.(wire.Value_I32))
	case .t_float:
		(cast(^f32)field.data)^ = builtins.decode_float(value.(wire.Value_I32))
	// I64-backing
	case .t_sfixed64:
		(cast(^i64)field.data)^ = builtins.decode_sfixed64(value.(wire.Value_I64))
	case .t_fixed64:
		(cast(^u64)field.data)^ = builtins.decode_fixed64(value.(wire.Value_I64))
	case .t_double:
		(cast(^f64)field.data)^ = builtins.decode_double(value.(wire.Value_I64))
	// LEN-backing
	case .t_message:
		field_bytes := builtins.decode_bytes(value.(wire.Value_LEN))
		decode_fill(field, field_bytes) or_return
	case .t_string:
		(cast(^string)field.data)^ = builtins.decode_string(value.(wire.Value_LEN))
	case .t_bytes:
		(cast(^([]u8))field.data)^ = builtins.decode_bytes(value.(wire.Value_LEN))
	case .t_group:
		unimplemented()
	}

	return true
}
