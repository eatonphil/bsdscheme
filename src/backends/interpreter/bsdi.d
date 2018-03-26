import std.stdio;
import std.string;

import expand : expand;
import parse;
import utility;
import value;

import base : include;
import eval : eval;
import runtime;

void info() {
  writeln("BSDScheme v0.0.0");
}

void repl() {
  string line;
  Context ctx = new Context;
  write("> ");
  while ((line = readln()) !is null) {
    line = line.strip();

    if (line.length) {
      Value value = car(read(line.dup));
      value = expand(value);
      eval(value, cast(void**)[ctx]);
    }

    write("> ");
  }
}

int main(string[] args) {
  if (args.length > 1) {
    Context ctx = new Context;
    auto source = makeStringValue(args[1]);
    auto includeArgs = makeListValue(source, nilValue);
    include(includeArgs, cast(void**)[ctx]);

    if (!valueIsNil(ctx.get("main", false))) {
      auto fn = valueToFunction(ctx.get("main"));
      fn[1](nilValue, cast(void**)[ctx]);
    }
  } else {
    info();
    repl();
  }

  return 0;
}
