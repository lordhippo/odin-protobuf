package examples

import "../protobuf"
import "proto/examples"

import "core:fmt"

main :: proc() {
	message := examples.Example_Message {
		number = -2,
		text = "testing",
		inner = {number = 3.1415, text = "hippo"},
		arr_num = {4, 3},
		arr_text = {"Lord", "Hippo"},
		arr_inner = {{number = 9.8, text = "foo"}, {number = 11.11, text = "bar"}},
		my_enum = .First,
		test_map = {"first" = .First, "second" = .Second},
	}

	if encoded_buffer, encode_ok := protobuf.encode(message); encode_ok {
		fmt.printf("Encoded message: %x\n", encoded_buffer)
		if message, ok := protobuf.decode(examples.Example_Message, encoded_buffer); ok {
			fmt.printf("Decoded message: %#v\n", message)
		} else {
			fmt.eprintf("Failed to decode message\n")
		}
	} else {
		fmt.eprintf("Failed to encode message\n")
	}
}
