import std.functional;
import std.file;
import std.stdio;

import parse;
import ast;

import runtime;
import value;

int main(string[] args) {
  char[] source = cast(char[])read(args[1]);
  auto parsed = parse.read(source);
  Value begin = makeSymbolAst("begin");
  Value topLevelItem = makeListAst(begin, parsed);
  auto ctx = new Context;
  eval(topLevelItem, ctx);
  return 0;
}
