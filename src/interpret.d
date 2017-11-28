import std.functional;
import std.file;
import std.stdio;

import lex : lex, Token;
import parse : parse;
import runtime;
import utility;
import value;

int interpretFile(string filename) {
  auto source = cast(char[])read(filename);
  auto tokens = lex(source.dup);

  auto ctx = new Context;
  auto buffer = tokens.buffer;
  while (buffer.length > 0) {
    Token*[] filteredBuffer;
    foreach (token; buffer) {
      if (token !is null) {
        filteredBuffer ~= token;
      }
    }

    auto parsed = parse(filteredBuffer);
    Value begin = makeSymbolValue("begin");
    Value topLevelItem = makeListValue(begin, parsed[1]);
    eval(topLevelItem, ctx);
    buffer = parsed[0];
  }

  return 0;
}
