package protobuf

import "message"

// Encodes/Decodes using the provided allocator
encode_with_allocator :: message.encode_with_allocator
decode_with_allocator :: message.decode_with_allocator

encode :: message.encode
decode :: message.decode
