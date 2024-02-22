package examples

import "../protobuf/wire"

import "core:fmt"

Example_Message :: struct {
	unsigned_number: u32,
	str_text: string,
	signed_number: i32,
}

main :: proc() {
	buffer: []u8 = {
		0x08, 0x96, 0x01,
		0x18, 0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01,
		0x12, 0x07, 0x74, 0x65, 0x73, 0x74, 0x69, 0x6e, 0x67,
	}
	if message, decode_ok := wire.decode(buffer); decode_ok {
		message_struct: Example_Message = {
			unsigned_number = wire.cast_uint32(message.fields[1].value.(wire.Value_VARINT)),
			str_text = wire.cast_string(message.fields[2].value.(wire.Value_LEN)),
			signed_number = wire.cast_int32(message.fields[3].value.(wire.Value_VARINT)),
		}

		fmt.printf("Decoded message: %#v\n", message_struct)

		if encoded_buffer, encode_ok := wire.encode(message); encode_ok {
			fmt.printf("Encoded message: %x\n", encoded_buffer)
		} else {
			fmt.eprintf("Failed to encode message\n")
		}
	} else {
		fmt.eprintf("Failed to decode message\n")
	}
}
