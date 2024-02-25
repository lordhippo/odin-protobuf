# odin-protobuf

**WIP**

[Protobuf](https://github.com/protocolbuffers/protobuf) support for Odin. To generate Odin files from proto definitions, use the [odin-protoc-plugin](https://github.com/lordhippo/odin-protoc-plugin).

## Usage
Example usage of the library can be found in the examples folder.

For this proto file
```proto
message SearchRequest {
  string query = 1;
  int32 page_number = 2;
  int32 results_per_page = 3;
}
```

You can generate the following Odin code using the [odin-protoc-plugin](https://github.com/lordhippo/odin-protoc-plugin)
```odin
SearchRequest :: struct {
  query : string `id:"1" type:"9"`,
  page_number : i32 `id:"2" type:"5"`,
  results_per_page : i32 `id:"3" type:"5"`,
}
```

You can then use this library to encode:

```odin
message := proto.SearchRequest {
	query            = "test",
	page_number      = 43,
	results_per_page = 20,
}

if encoded_buffer, ok := protobuf.encode(message); ok {
	// success
} else {
	// error
}
```

and decode:

```odin
if message, ok := protobuf.decode(proto.SearchRequest, buffer); ok {
	// success
} else {
	// error
}
```

## Missing features
- [Merging](https://github.com/lordhippo/odin-protobuf/issues/8)
- [LEN-type field concatenation](https://github.com/lordhippo/odin-protobuf/issues/2)
- [Oneofs (unions)](https://github.com/lordhippo/odin-protobuf/issues/6)
