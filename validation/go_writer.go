package main

import (
	"log"
	"os"

	"google.golang.org/protobuf/proto"

	pb "lordhippo/odin-protobuf/validation/out/go"
)

func main() {
	msg := &pb.TestAllTypes{
		Scalars: &pb.TestScalars{
			VDouble:   3.14,
			VFloat:    2.71,
			VInt32:    -123,
			VInt64:    -456789,
			VUint32:   123,
			VUint64:   456789,
			VSint32:   -789,
			VSint64:   -987654321,
			VFixed32:  111,
			VFixed64:  222,
			VSfixed32: -111,
			VSfixed64: -222,
			VBool:     true,
			VString:   "hello world",
			VBytes:    []byte{1, 2, 3, 4},
		},
		Repeateds: &pb.TestRepeated{
			RInt32:  []int32{1, 2, 3, 4, 5},
			RInt64:  []int64{-1, -2, -3, -4, -5},
			RString: []string{"a", "b", "c"},
			RBytes:  [][]byte{{1}, {2}, {3}},
			RNested: []*pb.NestedMessage{
				{Id: 1, Name: "one", Flag: true},
				{Id: 2, Name: "two", Flag: false},
			},
			REnum: []pb.Status{pb.Status_ACTIVE, pb.Status_INACTIVE},
		},
		Maps: &pb.TestMaps{
			MStringString: map[string]string{"key1": "value1", "key2": "value2"},
			MInt32String:  map[int32]string{1: "one", 2: "two"},
			MStringNested: map[string]*pb.NestedMessage{
				"nested1": {Id: 10, Name: "ten", Flag: true},
			},
			MUint32Enum: map[uint32]pb.Status{
				1: pb.Status_DELETED,
			},
		},
		Nested: &pb.NestedMessage{
			Id:   99,
			Name: "top nested",
			Flag: true,
		},
		Status: pb.Status_ACTIVE,
	}

	b, err := proto.Marshal(msg)
	if err != nil {
		log.Fatalf("failed to marshal: %v", err)
	}

	if err := os.WriteFile("payload.bin", b, 0644); err != nil {
		log.Fatalf("failed to write file: %v", err)
	}
}
