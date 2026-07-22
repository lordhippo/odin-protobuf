package validation

// Self-contained wire-semantics tests for the protobuf runtime. These use
// locally proto-tagged structs so they exercise encode/decode directly without
// depending on regenerated bindings. Run with:  odin test odin_spec_test.odin -file
//
// Field `type` numbers below match FieldDescriptorProto.Type:
//   int32=5 int64=3 uint32=13 uint64=4 bool=8 enum=14 sint32=17 sint64=18
//   sfixed32=15 fixed32=7 float=2 sfixed64=16 fixed64=6 double=1
//   message=11 string=9 bytes=12

import "../protobuf"

import "core:slice"
import "core:testing"

@(private = "file")
Scalars :: struct {
	i32f: i32 `id:"1" type:"5"`,
	i64f: i64 `id:"2" type:"3"`,
	u32f: u32 `id:"3" type:"13"`,
	u64f: u64 `id:"4" type:"4"`,
	s32f: i32 `id:"5" type:"17"`,
	s64f: i64 `id:"6" type:"18"`,
	fx32: u32 `id:"7" type:"7"`,
	fx64: u64 `id:"8" type:"6"`,
	sf32: i32 `id:"9" type:"15"`,
	sf64: i64 `id:"10" type:"16"`,
	flt:  f32 `id:"11" type:"2"`,
	dbl:  f64 `id:"12" type:"1"`,
	bln:  bool `id:"13" type:"8"`,
}

// Every scalar kind round-trips at its extremes: sign extension (int32/64),
// zigzag (sint32/64), fixed-width little-endian (fixed/sfixed/float/double).
@(test)
test_scalar_edges_roundtrip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src := Scalars {
		i32f = -2147483648, // min i32
		i64f = 9223372036854775807, // max i64
		u32f = 4294967295, // max u32
		u64f = 18446744073709551615, // max u64
		s32f = -2147483648,
		s64f = -9223372036854775808, // min i64
		fx32 = 0xDEADBEEF,
		fx64 = 0xCAFEBABEDEADBEEF,
		sf32 = -2147483648,
		sf64 = 9223372036854775807,
		flt  = -3.5e38,
		dbl  = 1.7e308,
		bln  = true,
	}

	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")

	got, dok := protobuf.decode(Scalars, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect_value(t, got.i32f, src.i32f)
	testing.expect_value(t, got.i64f, src.i64f)
	testing.expect_value(t, got.u32f, src.u32f)
	testing.expect_value(t, got.u64f, src.u64f)
	testing.expect_value(t, got.s32f, src.s32f)
	testing.expect_value(t, got.s64f, src.s64f)
	testing.expect_value(t, got.fx32, src.fx32)
	testing.expect_value(t, got.fx64, src.fx64)
	testing.expect_value(t, got.sf32, src.sf32)
	testing.expect_value(t, got.sf64, src.sf64)
	testing.expect_value(t, got.flt, src.flt)
	testing.expect_value(t, got.dbl, src.dbl)
	testing.expect_value(t, got.bln, src.bln)
}

// proto3 implicit presence: a message of all-default scalars encodes to nothing.
@(test)
test_zero_scalars_omitted :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src: Scalars
	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")
	testing.expect_value(t, len(bytes), 0)
}

// Absent fields decode back to their defaults without error.
@(test)
test_missing_fields_decode_default :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	got, ok := protobuf.decode(Scalars, []u8{})
	testing.expect(t, ok, "decode of empty buffer failed")
	testing.expect_value(t, got.i32f, 0)
	testing.expect_value(t, got.dbl, 0)
	testing.expect_value(t, got.bln, false)
}

@(private = "file")
Int32Msg :: struct {
	v: i32 `id:"1" type:"5"`,
}

// A negative int32 is sign-extended to 64 bits -> 10-byte varint.
@(test)
test_negative_int32_ten_byte_varint :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src := Int32Msg {
		v = -1,
	}
	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")
	expected := []u8{0x08, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01}
	testing.expect(t, slice.equal(bytes, expected), "negative int32 must be a 10-byte varint")

	got, dok := protobuf.decode(Int32Msg, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect_value(t, got.v, -1)
}

@(private = "file")
SintMsg :: struct {
	v: i32 `id:"1" type:"17"`,
}

// sint32 uses zigzag: -1 -> 1, encoding in a single byte.
@(test)
test_sint_zigzag_wire :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src := SintMsg {
		v = -1,
	}
	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")
	testing.expect(t, slice.equal(bytes, []u8{0x08, 0x01}), "sint32 -1 must zigzag to 1")

	got, dok := protobuf.decode(SintMsg, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect_value(t, got.v, -1)
}

@(private = "file")
RepNonPacked :: struct {
	vals: []i32 `id:"1" type:"5"`,
}

@(private = "file")
RepPacked :: struct {
	vals: []i32 `id:"1" type:"5" packed:"true"`,
}

// Regression: a non-packed repeated field whose first element is 0 must keep
// every element. (Previously zero-value suppression dropped the whole field.)
@(test)
test_repeated_leading_zero_nonpacked :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src := RepNonPacked {
		vals = []i32{0, 1, 2},
	}
	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")
	testing.expect(
		t,
		slice.equal(bytes, []u8{0x08, 0x00, 0x08, 0x01, 0x08, 0x02}),
		"leading-zero element must not be dropped",
	)

	got, dok := protobuf.decode(RepNonPacked, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect(t, slice.equal(got.vals, []i32{0, 1, 2}), "round-trip mismatch")
}

// Packed repeated fields keep interior/leading zeros as well.
@(test)
test_repeated_zeros_packed :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src := RepPacked {
		vals = []i32{0, 0, 7},
	}
	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")
	testing.expect(
		t,
		slice.equal(bytes, []u8{0x0a, 0x03, 0x00, 0x00, 0x07}),
		"packed zeros must be preserved",
	)

	got, dok := protobuf.decode(RepPacked, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect(t, slice.equal(got.vals, []i32{0, 0, 7}), "round-trip mismatch")
}

// An empty repeated field is not serialized at all.
@(test)
test_empty_repeated_omitted :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	np: RepNonPacked
	b1, _ := protobuf.encode(np)
	testing.expect_value(t, len(b1), 0)

	pk: RepPacked
	b2, _ := protobuf.encode(pk)
	testing.expect_value(t, len(b2), 0)
}

@(private = "file")
StrBytes :: struct {
	s:  string `id:"1" type:"9"`,
	by: []u8 `id:"2" type:"12"`,
}

// Singular string/bytes are "last one wins", not concatenated, when a field
// appears multiple times on the wire (verified against the Go reference impl).
@(test)
test_string_bytes_last_wins :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// field 1 = "AA", field 1 = "BBB", field 2 = {1}, field 2 = {2,3}
	//odinfmt: disable
	wire := [?]u8{
		0x0a, 0x02, 'A', 'A',
		0x0a, 0x03, 'B', 'B', 'B',
		0x12, 0x01, 0x01,
		0x12, 0x02, 0x02, 0x03,
	}
	//odinfmt: enable
	got, ok := protobuf.decode(StrBytes, wire[:])
	testing.expect(t, ok, "decode failed")
	testing.expect_value(t, got.s, "BBB")
	testing.expect(t, slice.equal(got.by, []u8{2, 3}), "bytes must take the last value")
}

@(private = "file")
Inner :: struct {
	a: i32 `id:"1" type:"5"`,
	b: i32 `id:"2" type:"5"`,
}

@(private = "file")
Outer :: struct {
	inner: Inner `id:"1" type:"11"`,
}

// A singular message field repeated on the wire is merged, not replaced.
@(test)
test_message_merge :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// field 1 = { a = 1 }, then field 1 = { b = 2 }  (must merge)
	//odinfmt: disable
	wire := [?]u8{
		0x0a, 0x02, 0x08, 0x01,
		0x0a, 0x02, 0x10, 0x02,
	}
	//odinfmt: enable
	got, ok := protobuf.decode(Outer, wire[:])
	testing.expect(t, ok, "decode failed")
	testing.expect_value(t, got.inner.a, 1)
	testing.expect_value(t, got.inner.b, 2)
}

@(private = "file")
Known :: struct {
	x: i32 `id:"1" type:"5"`,
}

// Unknown scalar/LEN fields are silently ignored (forward compatibility).
@(test)
test_unknown_fields_skipped :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// field 1 = 5; unknown field 3 varint = 99; unknown field 4 LEN = "junk"
	//odinfmt: disable
	wire := [?]u8{
		0x08, 0x05,
		0x18, 0x63,
		0x22, 0x04, 'j', 'u', 'n', 'k',
	}
	//odinfmt: enable
	got, ok := protobuf.decode(Known, wire[:])
	testing.expect(t, ok, "decode must skip unknown fields")
	testing.expect_value(t, got.x, 5)
}

// Deprecated groups are unsupported: encountering a group marker rejects the
// whole message rather than silently mis-parsing it.
@(test)
test_group_rejected :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// field 1 = 5; SGROUP f3 { varint f1=1 } EGROUP f3
	//odinfmt: disable
	wire := [?]u8{
		0x08, 0x05,
		0x1b,       // SGROUP field 3
		0x08, 0x01,
		0x1c,       // EGROUP field 3
	}
	//odinfmt: enable
	_, ok := protobuf.decode(Known, wire[:])
	testing.expect(t, !ok, "a group field must cause decode to fail")
}

// Decoding must reject a truncated LEN (length runs past the buffer).
@(test)
test_truncated_len_fails :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	// field 2 (LEN) claims 5 bytes but only 2 follow
	wire := [?]u8{0x12, 0x05, 0x01, 0x02}
	_, ok := protobuf.decode(StrBytes, wire[:])
	testing.expect(t, !ok, "truncated LEN must fail decode")
}

// A zero field number is invalid on the wire and must be rejected.
@(test)
test_zero_field_number_rejected :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	wire := [?]u8{0x00, 0x01} // tag with field number 0
	_, ok := protobuf.decode(Known, wire[:])
	testing.expect(t, !ok, "field number 0 must be rejected")
}

@(private = "file")
NegEnum :: enum i32 {
	A   = 0,
	NEG = -1,
}

@(private = "file")
EnumMsg :: struct {
	e: NegEnum `id:"1" type:"14"`,
}

// Enums are int32 on the wire. The plugin backs them with i32 so a negative
// value round-trips; an 8-byte default `int` backing would lose the high bytes.
@(test)
test_negative_enum_roundtrip :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src := EnumMsg {
		e = .NEG,
	}
	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")
	// -1 is sign-extended like int32 -> 10-byte varint after the field-1 tag
	testing.expect(
		t,
		slice.equal(
			bytes,
			[]u8{0x08, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01},
		),
		"negative enum must encode as a 10-byte varint",
	)

	got, dok := protobuf.decode(EnumMsg, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect_value(t, got.e, NegEnum.NEG)
}

@(private = "file")
MapMsg :: struct {
	m: map[i32]string `id:"1" type:"11" key_type:"5" value_type:"9"`,
}

// Map round-trip, including an entry with a default key and value.
@(test)
test_map_roundtrip_with_defaults :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	defer free_all(context.temp_allocator)

	src: MapMsg
	src.m = make(map[i32]string)
	src.m[1] = "one"
	src.m[0] = ""

	bytes, ok := protobuf.encode(src)
	testing.expect(t, ok, "encode failed")

	got, dok := protobuf.decode(MapMsg, bytes)
	testing.expect(t, dok, "decode failed")
	testing.expect_value(t, len(got.m), 2)
	testing.expect_value(t, got.m[1], "one")

	v, has_zero := got.m[0]
	testing.expect(t, has_zero, "default-key entry must survive round-trip")
	testing.expect_value(t, v, "")
}
