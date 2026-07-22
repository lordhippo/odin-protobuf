package main

import (
    "os"
    "testing"

    "google.golang.org/protobuf/proto"
    pb "lordhippo/odin-protobuf/validation/out/go"
)

func TestOdinPayload(t *testing.T) {
    b, err := os.ReadFile("payload_odin.bin")
    if err != nil {
        t.Fatalf("failed to read file: %v", err)
    }

    var msg pb.TestAllTypes
    if err := proto.Unmarshal(b, &msg); err != nil {
        t.Fatalf("failed to unmarshal: %v", err)
    }

    if msg.Scalars.VDouble != 3.14 { t.Errorf("v_double mismatch") }
    if msg.Scalars.VFloat != 2.71 { t.Errorf("v_float mismatch") }
    if msg.Scalars.VInt32 != -123 { t.Errorf("v_int32 mismatch: %d", msg.Scalars.VInt32) }
    if msg.Scalars.VInt64 != -456789 { t.Errorf("v_int64 mismatch: %d", msg.Scalars.VInt64) }
    if msg.Scalars.VUint32 != 123 { t.Errorf("v_uint32 mismatch: %d", msg.Scalars.VUint32) }
    if msg.Scalars.VUint64 != 456789 { t.Errorf("v_uint64 mismatch: %d", msg.Scalars.VUint64) }
    if msg.Scalars.VSint32 != -789 { t.Errorf("v_sint32 mismatch: %d", msg.Scalars.VSint32) }
    if msg.Scalars.VSint64 != -987654321 { t.Errorf("v_sint64 mismatch: %d", msg.Scalars.VSint64) }
    if msg.Scalars.VFixed32 != 111 { t.Errorf("v_fixed32 mismatch: %d", msg.Scalars.VFixed32) }
    if msg.Scalars.VFixed64 != 222 { t.Errorf("v_fixed64 mismatch: %d", msg.Scalars.VFixed64) }
    if msg.Scalars.VSfixed32 != -111 { t.Errorf("v_sfixed32 mismatch: %d", msg.Scalars.VSfixed32) }
    if msg.Scalars.VSfixed64 != -222 { t.Errorf("v_sfixed64 mismatch: %d", msg.Scalars.VSfixed64) }
    if msg.Scalars.VBool != true { t.Errorf("v_bool mismatch") }
    if msg.Scalars.VString != "hello world" { t.Errorf("v_string mismatch") }
    if len(msg.Scalars.VBytes) != 4 || msg.Scalars.VBytes[0] != 1 || msg.Scalars.VBytes[3] != 4 { t.Errorf("v_bytes mismatch") }

    if len(msg.Repeateds.RInt32) != 5 || msg.Repeateds.RInt32[0] != 1 || msg.Repeateds.RInt32[4] != 5 { t.Errorf("r_int32 mismatch") }
    if len(msg.Repeateds.RInt64) != 5 || msg.Repeateds.RInt64[0] != -1 || msg.Repeateds.RInt64[4] != -5 { t.Errorf("r_int64 mismatch") }
    if len(msg.Repeateds.RString) != 3 || msg.Repeateds.RString[0] != "a" { t.Errorf("r_string mismatch") }
    if len(msg.Repeateds.RBytes) != 3 || msg.Repeateds.RBytes[0][0] != 1 { t.Errorf("r_bytes mismatch") }
    if len(msg.Repeateds.RNested) != 2 || msg.Repeateds.RNested[0].Name != "one" || msg.Repeateds.RNested[1].Flag != false { t.Errorf("r_nested mismatch") }
    if len(msg.Repeateds.REnum) != 2 || msg.Repeateds.REnum[0] != pb.Status_ACTIVE || msg.Repeateds.REnum[1] != pb.Status_INACTIVE { t.Errorf("r_enum mismatch") }
    
    if msg.Maps.MStringString["key1"] != "value1" { t.Errorf("m_string_string mismatch") }
    if msg.Maps.MInt32String[1] != "one" { t.Errorf("m_int32_string mismatch") }
    if msg.Maps.MStringNested["nested1"].Name != "ten" || msg.Maps.MStringNested["nested1"].Flag != true { t.Errorf("m_string_nested mismatch") }
    if msg.Maps.MUint32Enum[1] != pb.Status_DELETED { t.Errorf("m_uint32_enum mismatch") }
    
    if msg.Nested.Id != 99 || msg.Nested.Name != "top nested" || msg.Nested.Flag != true { t.Errorf("nested mismatch") }
    if msg.Status != pb.Status_ACTIVE { t.Errorf("status mismatch") }
}
