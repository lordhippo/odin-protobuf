package protobuf_message

import "base:runtime"
import "core:reflect"

import "../builtins"
import "../wire"

decode :: proc(message_tid: typeid, buffer: []u8) -> (message: any, ok: bool) {
	message = new_scalar(message_tid) or_return
	return message, decode_fill(message, buffer)
}

@(private = "file")
decode_fill :: proc(message: any, buffer: []u8) -> (ok: bool) {
	wire_message := wire.decode(buffer) or_return

	field_count := struct_field_count(message) or_return

	for field_idx in 0 ..< field_count {
		field_info := struct_field_info(message, field_idx) or_return

		values := wire_message.fields[field_info.proto_id].values

		base_ptr: uintptr
		elem_stride: uintptr
		elem_typeid: typeid

		switch type_variant in field_info.type {
			case Field_Type_Scalar:
				base_ptr = uintptr(field_info.ptr)
				elem_typeid = type_variant.type

			case Field_Type_Repeated:
				slice := new_repeated(type_variant, len(values)) or_return
				(transmute(^runtime.Raw_Slice)(field_info.ptr))^ = slice

				base_ptr = uintptr(slice.data)
				elem_stride = uintptr(type_variant.elem_size)
				elem_typeid = type_variant.elem_type

			case Field_Type_Map:
				unimplemented()
		}

		for value, value_idx in values {
			current_ptr := rawptr(base_ptr + uintptr(value_idx) * elem_stride)

			decode_fill_field(
				{data = current_ptr, id = elem_typeid},
				value,
				field_info.proto_type,
			) or_return
		}
	}

	return true
}

@(private = "file")
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
			(transmute(^builtins.Enum_Wire_Type)field.data)^ = builtins.decode_enum(
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
		case .t_group:
			unimplemented()
	}

	return true
}

@(private = "file")
new_scalar :: proc(id: typeid) -> (any, bool) {
	size := reflect.size_of_typeid(id)
	align := reflect.align_of_typeid(id)

	ptr, alloc_error := runtime.mem_alloc_bytes(size, align)
	return {data = raw_data(ptr), id = id}, alloc_error == .None
}

@(private = "file")
new_repeated :: proc(
	slice_info: Field_Type_Repeated,
	count: int,
) -> (
	runtime.Raw_Slice,
	bool,
) {
	ptr, alloc_error := runtime.mem_alloc_bytes(
		slice_info.elem_size * count,
		slice_info.elem_align,
	)
	return {data = raw_data(ptr), len = count}, alloc_error == .None
}
