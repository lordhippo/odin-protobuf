package examples

// This is currently hand-written.
// But it has the format that the protoc plugin will eventually generate.

Example_Enum :: enum i32 {
	None   = 0,
	First  = 1,
	Second = 2,
}

Inner_Message :: struct {
	number: f32 `id:"1" type:"3"`,
	text:   string `id:"2" type:"16"`,
}

Example_Message :: struct {
	number:    i32 `id:"1" type:"1"`,
	text:      string `id:"2" type:"16"`,
	inner:     Inner_Message `id:"3" type:"15"`,
	arr_num:   []i32 `id:"4" type:"1"`,
	arr_text:  []string `id:"5" type:"16"`,
	arr_inner: []Inner_Message `id:"6" type:"15"`,
	my_enum:   Example_Enum `id:"7" type:"6"`,
}
