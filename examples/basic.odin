package examples

import "../protobuf"
import "proto/examples"

import "core:fmt"

main :: proc() {
	arr_num_data := [?]i32{4, 3}
	arr_text_data := [?]string{"Lord", "Hippo"}
	arr_inner_data := [?]examples.Inner_Message{
		{number = 9.8, text = "foo"}, 
		{number = 11.11, text = "bar"},
	}

	test_map := make(map[string]examples.Example_Enum)
	defer delete(test_map)
	test_map["first"] = .First
	test_map["second"] = .Second

	message := examples.Example_Message {
		number = -2,
		text = "testing",
		inner = examples.Inner_Message{number = 3.1415, text = "hippo"},
		arr_num = arr_num_data[:],
		arr_text = arr_text_data[:],
		arr_inner = arr_inner_data[:],
		my_enum = .First,
		test_map = test_map,
	}

	if encoded_buffer, encode_ok := protobuf.encode(message); encode_ok {
		fmt.printf("Encoded message: %x\n", encoded_buffer)
		if decoded_message, ok := protobuf.decode(examples.Example_Message, encoded_buffer); ok {
			fmt.printf("Decoded message: %#v\n", decoded_message)
		} else {
			fmt.eprintf("Failed to decode message\n")
		}
	} else {
		fmt.eprintf("Failed to encode message\n")
	}
}