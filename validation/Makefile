.PHONY: all compile test_go test_odin test_spec test

all: compile test

compile:
	rm -fr ./out;
	mkdir -p ./out/odin;
	mkdir -p ./out/go;
	protoc --proto_path=./pb \
		--go_out=paths=source_relative:./out/go \
		--odin_out=./out/odin \
		./pb/*.proto;

test_go: compile
	go mod tidy
	go run go_writer.go
	odin test odin_reader_test.odin -file
	rm payload.bin

test_odin: compile
	odin run odin_writer.odin -file
	go test -v
	rm payload_odin.bin

# Self-contained wire-semantics tests; no generated bindings or Go required.
test_spec:
	odin test odin_spec_test.odin -file

test: test_spec test_go test_odin
