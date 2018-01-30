import std.stdio;
import std.string;

import parse;
import utility;
import value;

import runtime;

void info() {
  writeln("BSDScheme v0.0.0");
}

void repl() {
  string line;
  auto ctx = new Context;
  write("> ");
  while ((line = readln()) !is null) {
    line = line.strip();

    if (line.length) {
      Value value = car(read(line.dup));
      eval(value, ctx);
    }

    write("> ");
  }
}

int main(string[] args) {
  if (args.length > 1) {
    auto ctx = new Context;
    auto include = makeSymbolValue("include");
    auto source = makeStringValue(args[1]);
    auto includeArgs = makeListValue(source, nilValue);
    auto topLevelItem = makeListValue(include, includeArgs);
    eval(topLevelItem, ctx);
  } else {
    info();
    repl();
  }

  return 0;
}
