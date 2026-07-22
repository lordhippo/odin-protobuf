# Protobuf Compatibility Checklist

This library implements support for the protocol buffers wire format natively in Odin. Below is an audit against modern standard protobuf requirements (proto2/proto3):

### Compliant Features
- [x] **Varint Encoding**: Correctly handles two's-complement negative integers (`int32`, `int64`) and bools.
- [x] **ZigZag Encoding**: Applies fast bitwise zigzag decoding and encoding for `sint32` and `sint64`.
- [x] **Length-Delimited Bounds Safety**: Verifies boundaries when parsing strings, bytes, or packed repeated fields to prevent out-of-bounds panics on malformed wire payloads.
- [x] **Last-One-Wins / Merge Semantics**:
  - Repeated occurrences of a singular scalar, `string`, or `bytes` field resolve to the last value seen (matching the reference implementation).
  - Sub-messages are merged appropriately when declared on the wire more than once.
- [x] **Repeated Fields Additivity**: Repeated fields accumulate elements across multiple values or packed blocks in the same message payload.
- [x] **Tag Validation**: Actively rejects and drops tags that are `0` or within the reserved range `19000-19999`.
- [x] **Unknown Fields**: Automatically ignores unrecognized fields during decoding, allowing forward compatibility with newer schemas.
- [x] **Allocator Ownership**: Exposes `encode_with_allocator` and `decode_with_allocator` to hand over complete memory lifecycle control to the caller (e.g. using Arena allocators).

### Known Limitations / Non-Compliant Areas
- [ ] **Deterministic Map Ordering**: Map encoding order is currently determined by the Odin runtime map hashing and is non-deterministic. Protobuf implementations often sort map keys to guarantee deterministic output across payloads.
- [ ] **Oneofs (Unions)**: Not natively supported by the generator and unmarshaler yet.
- [ ] **Default Values / Field Presence (`has_` tracking)**: Currently, fields are mapped directly to standard Odin types. Zero-values on the wire overwrite existing values, and explicit field presence for optional scalars is not fully implemented.
- [ ] **Unknown Fields Retention**: While unknown fields are safely ignored when decoding, they are not stored on the decoded message, which means they are lost if the message is re-encoded.
- [ ] **Groups**: Deprecated `group` elements (`wire_type=3` and `4`) log a warning but do not actively skip their nested contents yet, which could theoretically break parsing on extremely old legacy payloads.
