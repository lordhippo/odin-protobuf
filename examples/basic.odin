package examples

import protobuf "../protobuf/message"

import "core:fmt"

Inner_Message :: struct {
	number: f32 `id:"1" type:"3"`,
	text:   string `id:"2" type:"16"`,
}

Example_Message :: struct {
	number: i32 `id:"1" type:"1"`,
	text:   string `id:"2" type:"16"`,
	inner:  Inner_Message `id:"3" type:"15"`,
}

main :: proc() {
	{
		message := Example_Message {
			number = -2,
			text = "testing",
			inner = {number = 3.1415, text = "hippo"},
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
