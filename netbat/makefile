PROTO_TARGET	:= protobuf/netbat.pb.rb

.PHONY: all
all: $(PROTO_TARGET)

$(PROTO_TARGET): protobuf/netbat.proto
	ruby-protoc $<

.PHONY: clean
clean:
	rm -f $(PROTO_TARGET)