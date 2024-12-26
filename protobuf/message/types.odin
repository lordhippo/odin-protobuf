package protobuf_message

import "base:runtime"
import "core:reflect"
import "core:strconv"

import "../builtins"

Field_Type_Scalar :: struct {
	type: typeid,
}

Field_Type_Repeated :: struct {
	elem_size:  int,
	elem_align: int,
	elem_type:  typeid,
	is_packed:  bool,
}

Field_Type_Map_Field :: struct {
	proto_id:   u32,
	proto_type: builtins.Type,
	type:       Field_Type_Scalar,
}

Field_Type_Map :: struct {
	key:      Field_Type_Map_Field,
	value:    Field_Type_Map_Field,
	map_info: ^runtime.Map_Info,
}

Field_Type :: union {
	Field_Type_Scalar,
	Field_Type_Repeated,
	Field_Type_Map,
}

Field_Data_Scalar :: distinct rawptr

Field_Data_Repeated :: distinct ^runtime.Raw_Slice

Field_Data_Map :: distinct ^runtime.Raw_Map

Field_Data :: union {
	Field_Data_Scalar,
	Field_Data_Repeated,
	Field_Data_Map,
}

Field_Info :: struct {
	proto_id:   u32,
	proto_type: builtins.Type,
	type:       Field_Type,
	data:       Field_Data,
}

@(private = "file")
field_tag_lookup_type :: proc(
	field: reflect.Struct_Field,
	tag: string,
) -> (
	type: builtins.Type,
	ok: bool,
) {
	tag_str := reflect.struct_tag_lookup(field.tag, tag) or_return
	tag_int := strconv.parse_uint(tag_str) or_return
	return builtins.Type(tag_int), true
}

@(private = "file")
field_tag_lookup_id :: proc(field: reflect.Struct_Field, tag: string) -> (id: u32, ok: bool) {
	id_str := reflect.struct_tag_lookup(field.tag, tag) or_return
	id_uint := strconv.parse_uint(id_str) or_return
	return u32(id_uint), true
}

@(private = "file")
field_tag_lookup_bool :: proc(
	field: reflect.Struct_Field,
	tag: string,
) -> (
	result: bool,
	ok: bool,
) {
	bool_str := reflect.struct_tag_lookup(field.tag, tag) or_return
	return strconv.parse_bool(bool_str)
}

@(private = "package")
struct_field_info :: proc(
	message: any,
	field_idx: int,
) -> (
	field_info: Field_Info,
	ok: bool,
) {
	field_rtti := reflect.struct_field_at(message.id, field_idx)

	field_info.proto_id = field_tag_lookup_id(field_rtti, "id") or_return
	field_info.proto_type = field_tag_lookup_type(field_rtti, "type") or_return

	field_ptr := rawptr(uintptr(message.data) + field_rtti.offset)

	#partial switch type_variant in field_rtti.type.variant {
		case runtime.Type_Info_Slice:
			field_info.type = Field_Type_Repeated {
				elem_size  = type_variant.elem.size,
				elem_align = type_variant.elem.align,
				elem_type  = type_variant.elem.id,
				is_packed  = field_tag_lookup_bool(field_rtti, "packed") or_else false,
			}

			field_info.data = transmute(Field_Data_Repeated)(field_ptr)

		case runtime.Type_Info_Map:
			field_info.type = Field_Type_Map {
				key =  {
					proto_id = 1,
					proto_type = field_tag_lookup_type(field_rtti, "key_type") or_return,
					type = {type = type_variant.key.id},
				},
				value =  {
					proto_id = 2,
					proto_type = field_tag_lookup_type(field_rtti, "value_type") or_return,
					type = {type = type_variant.value.id},
				},
				map_info = type_variant.map_info,
			}

			field_info.data = transmute(Field_Data_Map)(field_ptr)

		case:
			field_info.type = Field_Type_Scalar {
				type = field_rtti.type.id,
			}

			field_info.data = Field_Data_Scalar(field_ptr)
	}

	return field_info, true
}

@(private = "package")
is_packed :: proc(field_info: Field_Info) -> bool {
	if repeated, repeated_ok := field_info.type.(Field_Type_Repeated);
	   repeated_ok && repeated.is_packed {
		return true
	}
	return false
}

@(private = "package")
struct_field_count :: proc(message: any) -> (count: int, ok: bool) {
	ti := runtime.type_info_base(type_info_of(message.id))
	s := ti.variant.(runtime.Type_Info_Struct) or_return
	return int(s.field_count), true
}

@(private = "package")
new_scalar :: proc(id: typeid, allocator := context.allocator) -> (any, bool) {
	size := reflect.size_of_typeid(id)
	align := reflect.align_of_typeid(id)

	ptr, alloc_error := runtime.mem_alloc_bytes(size, align, allocator)
	return {data = raw_data(ptr), id = id}, alloc_error == .None
}

@(private = "package")
new_repeated :: proc(
	slice_info: Field_Type_Repeated,
	count: int,
	allocator := context.allocator,
) -> (
	runtime.Raw_Slice,
	bool,
) {
	ptr, alloc_error := runtime.mem_alloc_bytes(
		slice_info.elem_size * count,
		slice_info.elem_align,
		allocator,
	)
	return {data = raw_data(ptr), len = count}, alloc_error == .None
}
