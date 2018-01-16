.PHONY: all install uninstall clean

all: bin/bsdi bin/bsdc

bin/bsdi: src/backends/interpreter/*.d src/*.d
	ldc -of $@ $^

bin/bsdc: src/backends/llvm/*.d src/*.d
	ldc -of $@ $^

install:
	ln -s $(CURDIR)/bin/bsdi /usr/local/bin/bsdi
	ln -s $(CURDIR)/bin/bsdc /usr/local/bin/bsdc

uninstall:
	rm /usr/local/bin/bsdi
	rm /usr/local/bin/bsdc

clean:
	rm -rf bin
