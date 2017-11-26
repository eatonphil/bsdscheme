.PHONY: all clean

all: bin/bsdscheme

bin/bsdscheme: src/bsdscheme.d src/lex.d src/parse.d src/value.d src/runtime.d src/interpret.d src/utility.d
	mkdir -p bin
	ldc2 -of $@ $^

clean:
	rm -rf bin
