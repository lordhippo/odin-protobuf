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

Field_Type_Map :: struct {}

Field_Type :: union {
	Field_Type_Scalar,
	Field_Type_Repeated,
	Field_Type_Map,
}

Field_Info :: struct {
	proto_id:   u32,
	proto_type: builtins.Type,
	type:       Field_Type,
	ptr:        rawptr,
}

struct_field_info :: proc(
	message: any,
	field_idx: int,
) -> (
	field_info: Field_Info,
	ok: bool,
) {
	field_rtti := reflect.struct_field_at(message.id, field_idx)

	id_str := reflect.struct_tag_lookup(field_rtti.tag, "id") or_return
	field_info.proto_id = u32(strconv.parse_uint(id_str) or_return)

	tag_type_str := reflect.struct_tag_lookup(field_rtti.tag, "type") or_return
	tag_type_int := strconv.parse_uint(tag_type_str) or_return
	field_info.proto_type = builtins.Type(tag_type_int)

	field_info.ptr = rawptr(uintptr(message.data) + field_rtti.offset)

	if variant_slice, slice_ok := field_rtti.type.variant.(runtime.Type_Info_Slice);
	   slice_ok {
		packed_str := reflect.struct_tag_lookup(field_rtti.tag, "packed") or_else "false"

		field_info.type = Field_Type_Repeated {
			elem_size  = variant_slice.elem.size,
			elem_align = variant_slice.elem.align,
			elem_type  = variant_slice.elem.id,
			is_packed  = strconv.parse_bool(packed_str) or_return,
		}
	} else if _, map_ok := field_rtti.type.variant.(runtime.Type_Info_Map); map_ok {
		field_info.type = Field_Type_Map{}
		unimplemented()
	} else {
		field_info.type = Field_Type_Scalar {
			type = field_rtti.type.id,
		}
	}

	return field_info, true
}

struct_field_count :: proc(message: any) -> (count: int, ok: bool) {
	ti := runtime.type_info_base(type_info_of(message.id))
	s := ti.variant.(runtime.Type_Info_Struct) or_return
	return len(s.names), true
}
