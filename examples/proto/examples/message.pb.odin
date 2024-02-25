// Auto-generated by odin-protoc-plugin (https://github.com/lordhippo/odin-protoc-plugin)
// protoc version: 4.25.3
// Use with the runtime odin-protobuf library (https://github.com/lordhippo/odin-protobuf)

package proto_examples

Inner_Message :: struct {
  number : f32 `id:"1" type:"2"`,
  text : string `id:"2" type:"9"`,
}

Example_Message :: struct {
  number : i32 `id:"1" type:"5"`,
  text : string `id:"2" type:"9"`,
  inner : Inner_Message `id:"3" type:"11"`,
  arr_num : []i32 `id:"4" type:"5" packed:"true"`,
  arr_text : []string `id:"5" type:"9"`,
  arr_inner : []Inner_Message `id:"6" type:"11"`,
  my_enum : Example_Enum `id:"7" type:"14"`,
}

Example_Enum :: enum {
  None = 0,
  First = 1,
  Second = 2,
}
