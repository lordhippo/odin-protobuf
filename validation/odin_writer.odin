package validation

import "../protobuf"
import "out/odin"
import "core:os"
import "core:fmt"

main :: proc() {
    msg: odin.TestAllTypes
    msg.scalars.v_double = 3.14
    msg.scalars.v_float = 2.71
    msg.scalars.v_int32 = -123
    msg.scalars.v_int64 = -456789
    msg.scalars.v_uint32 = 123
    msg.scalars.v_uint64 = 456789
    msg.scalars.v_sint32 = -789
    msg.scalars.v_sint64 = -987654321
    msg.scalars.v_fixed32 = 111
    msg.scalars.v_fixed64 = 222
    msg.scalars.v_sfixed32 = -111
    msg.scalars.v_sfixed64 = -222
    msg.scalars.v_bool = true
    msg.scalars.v_string = "hello world"
    msg.scalars.v_bytes = []u8{1, 2, 3, 4}

    msg.repeateds.r_int32 = []i32{1, 2, 3, 4, 5}
    msg.repeateds.r_int64 = []i64{-1, -2, -3, -4, -5}
    msg.repeateds.r_string = []string{"a", "b", "c"}
    msg.repeateds.r_bytes = [][]u8{{1}, {2}, {3}}
    msg.repeateds.r_nested = []odin.NestedMessage{
        {id = 1, name = "one", flag = true},
        {id = 2, name = "two", flag = false},
    }
    msg.repeateds.r_enum = []odin.Status{.ACTIVE, .INACTIVE}

    m1 := make(map[string]string)
    m1["key1"] = "value1"
    m1["key2"] = "value2"
    msg.maps.m_string_string = m1

    m2 := make(map[i32]string)
    m2[1] = "one"
    m2[2] = "two"
    msg.maps.m_int32_string = m2

    m3 := make(map[string]odin.NestedMessage)
    m3["nested1"] = {id = 10, name = "ten", flag = true}
    msg.maps.m_string_nested = m3

    m4 := make(map[u32]odin.Status)
    m4[1] = .DELETED
    msg.maps.m_uint32_enum = m4

    msg.nested.id = 99
    msg.nested.name = "top nested"
    msg.nested.flag = true

    msg.status = .ACTIVE

    bytes, ok := protobuf.encode(msg)
    if !ok {
        fmt.eprintf("Failed to encode\n")
        return
    }

	err := os.write_entire_file("payload_odin.bin", bytes)
	if err != os.ERROR_NONE {
		fmt.eprintf("Failed to write payload_odin.bin\n")
		return
	}
}
