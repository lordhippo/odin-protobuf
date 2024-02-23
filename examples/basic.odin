package examples

import "../protobuf"

import "core:fmt"

Example_Message :: struct {
	unsigned_number: u32 `id:"1" type:"3"`,
	str_text:        string `id:"2" type:"16"`,
	signed_number:   i32 `id:"3" type:"1"`,
}

main :: proc() {
	buffer: []u8 = {
		0x08, 0x96, 0x01,
		0x18, 0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01,
		0x12, 0x07, 0x74, 0x65, 0x73, 0x74, 0x69, 0x6e, 0x67,
	}

	if message, ok := protobuf.decode(Example_Message, buffer); ok {
		fmt.printf("Decoded message: %#v\n", message)

		if encoded_buffer, encode_ok := protobuf.encode(message); encode_ok {
			fmt.printf("Encoded message: %x\n", encoded_buffer)
		} else {
			fmt.eprintf("Failed to encode message\n")
		}
	} else {
		fmt.eprintf("Failed to decode message\n")
	}
}
