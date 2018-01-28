import std.stdio;

import parse;
import ast;

import runtime;
import value;

void info() {
  writeln("BSDScheme v0.0.0");
}

void repl() {
  string line;
  auto ctx = new Context;
  write("> ");
  while ((line = readln()) !is null) {
    AST ast = car(read(line.dup));
    eval(ast, ctx);
    write("> ");
  }
}

int main(string[] args) {
  if (args.length > 1) {
    auto ctx = new Context;
    auto include = makeSymbolAst("include");
    auto source = makeStringAst(args[1]);
    auto includeArgs = makeListAst(source, nilValue);
    auto topLevelItem = makeListAst(include, includeArgs);
    eval(topLevelItem, ctx);
  } else {
    info();
    repl();
  }

  return 0;
}
