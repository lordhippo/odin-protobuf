package examples

import "../protobuf"

import "core:fmt"

main :: proc() {
	buffer: []u8 = {0x08, 0x96, 0x01}
	if message, ok := protobuf.decode(buffer); ok {
		fmt.printf("Parsed message: %#v\n", message)
	}
}
