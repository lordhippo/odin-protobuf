package examples

import protobuf "../protobuf/message"

import "core:fmt"

main :: proc() {
	{
		message := Example_Message {
			number = -2,
			text = "testing",
			inner = {number = 3.1415, text = "hippo"},
			arr_num = {4, 3},
			arr_text = {"Lord", "Hippo"},
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
