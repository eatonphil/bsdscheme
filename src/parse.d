import std.typecons;
import std.conv;
import std.stdio;

import ast;
import lex : lex, Token, TokenType, SchemeType;
import utility;

Tuple!(Token*[], AST) parse(Token*[] tokens) {
  AST list;
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
      list = appendList(list, makeListAst(tmp, nil));
      i = -1;
      tokens = program[0];
      break;
    case TokenType.RightParen:
      return Tuple!(Token*[], AST)(tokens[i + 1 .. tokens.length], list);
      break;
    case TokenType.Quote:
      AST quote = makeSymbolAst("quote");

      auto program = parse(tokens[i + 1 .. tokens.length]);
      auto quoted = makeListAst(quote, program[1]);
      list = appendList(list, makeListAst(quoted, nil));

      tokens = [new Token(0, 0, "", ")", TokenType.RightParen)];
      foreach (nextToken; program[0]) {
        tokens ~= nextToken;
      }

      i = -1;
      break;
    default:
      AST atom;
      switch (token.schemeType) {
      case SchemeType.Bool:
        atom = makeBoolAst(token.value == "#t");
        break;
      case SchemeType.Integer:
        atom = makeIntegerAst(to!int(token.value));
        break;
      case SchemeType.String:
        atom = makeStringAst(token.value);
        break;
      case SchemeType.Char:
        atom = makeCharAst(token.value[0]);
        break;
      default:
        atom = makeSymbolAst(token.value);
        break;
      }
      list = appendList(list, makeListAst(atom, nil));
    }

    i += 1;
  }

  if (i > 0) {
    return Tuple!(Token*[], AST)(tokens[i + 1 .. tokens.length], list);
  }

  return Tuple!(Token*[], AST)([], list);
}

AST read(char[] source) {
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
