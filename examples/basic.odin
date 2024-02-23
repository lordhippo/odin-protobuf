package examples

import "../protobuf"

import "core:fmt"

Example_Message :: struct {
	unsigned_number: u32 `id:"1" type:"3"`,
	str_text:        string `id:"2" type:"16"`,
	signed_number:   i32 `id:"3" type:"1"`,
}

main :: proc() {
	{
		message := Example_Message {
			unsigned_number = 150,
			str_text        = "testing",
			signed_number   = -2,
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
