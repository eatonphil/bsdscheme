import std.typecons;
import std.conv;
import std.stdio;

import value;
import lex : lex, Token, TokenType, SchemeType;
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
    case TokenType.Dot:
      auto nextToken = tokens[i + 1];
      bool cdrIsList = nextToken.type == TokenType.LeftParen;

      auto program = parse(tokens[i + 1 .. tokens.length]);
      auto pTuple = valueToList(program[1]);
      auto tuple = valueToList(list);

      if (cdrIsList) {
        list = appendList(list, pTuple[0]);
      } else {
        list = makeListValue(tuple[0], pTuple[0]);
      }

      return Tuple!(Token*[], Value)(program[0], list);
      break;
    case TokenType.Special:
      Value symbol = makeSymbolValue(token.value);

      auto program = parse(tokens[i + 1 .. tokens.length]);
      auto special = makeListValue(symbol, program[1]);
      list = appendList(list, makeListValue(special, nilValue));

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
        atom = token.value == "#t" ? trueValue : falseValue;
        break;
      case SchemeType.Integer:
        atom = makeIntegerValue(to!int(token.value));
        break;
      case SchemeType.String:
        atom = makeStringValue(token.value);
        break;
      case SchemeType.Char:
        atom = makeCharValue(token.value[0]);
        break;
      default:
        atom = makeSymbolValue(token.value);
        break;
      }
      list = appendList(list, makeListValue(atom, nilValue));
    }

    i += 1;
  }

 ret:

  if (i > 0) {
    return Tuple!(Token*[], Value)(tokens[i + 1 .. tokens.length], list);
  }

  return Tuple!(Token*[], Value)([], list);
}

Value read(char[] source) {
  auto tokens = lex(source);
  auto buffer = tokens.buffer;
  Token*[] filteredBuffer;
  foreach (token; buffer) {
    if (token !is null) {
      filteredBuffer ~= token;
    }
  }
  return parse(filteredBuffer)[1];
}
