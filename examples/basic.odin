package examples

import protobuf "../protobuf/message"

import "core:fmt"

Example_Enum :: enum i32 {
	None,
	First,
	Second,
}

Inner_Message :: struct {
	number: f32 `id:"1" type:"3"`,
	text:   string `id:"2" type:"16"`,
}

Example_Message :: struct {
	number:    i32 `id:"1" type:"1"`,
	text:      string `id:"2" type:"16"`,
	inner:     Inner_Message `id:"3" type:"15"`,
	arr:       []i32 `id:"4" type:"1"`,
	arr_str:   []string `id:"5" type:"16"`,
	arr_inner: []Inner_Message `id:"6" type:"15"`,
	my_enum:   Example_Enum `id:"7" type:"6"`,
}

main :: proc() {
	{
		message := Example_Message {
			number = -2,
			text = "testing",
			inner = {number = 3.1415, text = "hippo"},
			arr = {4, 3},
			arr_str = {"Lord", "Hippo"},
			arr_inner = {{number = 9.8, text = "foo"}, {number = 11.11, text = "bar"}},
			my_enum = .First,
		}

		if encoded_buffer, encode_ok := protobuf.encode(message); encode_ok {
			fmt.printf("Encoded message: %x\n", encoded_buffer)
			if message, ok := protobuf.decode(Example_Message, encoded_buffer); ok {
				fmt.printf("Decoded message: %#v\n", message)
			} else {
				fmt.eprintf("Failed to decode message\n")
			}
		} else {
			fmt.eprintf("Failed to encode message\n")
		}
	}
}
