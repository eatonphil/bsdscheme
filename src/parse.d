import std.typecons;
import std.conv;
import std.stdio;

import lex;
import value;
import utility;

Tuple!(Token*[], Value) parse(Token*[] tokens) {
  Value list;
  int i = 0;

  while (true) {
    if (i == tokens.length || tokens[i] is null) {
      break;
    }

    auto token = tokens[i];

    switch (token.type) {
    case TokenType.LeftParen:
      auto program = parse(tokens[i + 1 .. tokens.length]);
      auto tmp = program[1];
      list = appendList(list, makeListValue(tmp, nilValue));
      i = -1;
      tokens = program[0];
      break;
    case TokenType.RightParen:
      return Tuple!(Token*[], Value)(tokens[i + 1 .. tokens.length], list);
      break;
    case TokenType.Quote:
      Value quote = makeSymbolValue("quote");

      auto program = parse(tokens[i + 1 .. tokens.length]);
      auto quoted = makeListValue(quote, program[1]);
      list = appendList(list, makeListValue(quoted, nilValue));

      tokens = [new Token(0, 0, "", ")", TokenType.RightParen)];
      foreach (nextToken; program[0]) {
        tokens ~= nextToken;
      }

      i = -1;
      break;
    default:
      Value atom;
      switch (token.schemeType) {
      case SchemeType.Bool:
        atom = makeBoolValue(token.value == "#t");
        break;
      case SchemeType.Integer:
        atom = makeIntegerValue(to!int(token.value));
        break;
      default:
        atom = makeSymbolValue(token.value);
        break;
      }
      list = appendList(list, makeListValue(atom, nilValue));
    }

    i += 1;
  }

  if (i > 0) {
    return Tuple!(Token*[], Value)(tokens[i + 1 .. tokens.length], list);
  }

  return Tuple!(Token*[], Value)([], list);
}
