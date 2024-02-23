// This is an implementation of the protobuf wire format
// https://protobuf.dev/programming-guides/encoding/

// message    := (tag value)*
// 
// tag        := (field << 3) bit-or wire_type;
//                 encoded as uint32 varint
// value      := varint      for wire_type == VARINT,
//               i32         for wire_type == I32,
//               i64         for wire_type == I64,
//               len-prefix  for wire_type == LEN,
//               <empty>     for wire_type == SGROUP or EGROUP
// 
// varint     := int32 | int64 | uint32 | uint64 | bool | enum | sint32 | sint64;
//                 encoded as varints (sintN are ZigZag-encoded first)
// i32        := sfixed32 | fixed32 | float;
//                 encoded as 4-byte little-endian;
//                 memcpy of the equivalent C types (u?int32_t, float)
// i64        := sfixed64 | fixed64 | double;
//                 encoded as 8-byte little-endian;
//                 memcpy of the equivalent C types (u?int64_t, double)
// 
// len-prefix := size (message | string | bytes | packed);
//                 size encoded as int32 varint
// string     := valid UTF-8 string (e.g. ASCII);
//                 max 2GB of bytes
// bytes      := any sequence of 8-bit bytes;
//                 max 2GB of bytes
// packed     := varint* | i32* | i64*,
//                 consecutive values of the type specified in `.proto`

package protobuf_wire
