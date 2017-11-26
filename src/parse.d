import std.typecons;

import lex;

alias Token Atom;

struct SExp {
  Atom* atom;
  SExp*[] sexps;
}

Tuple!(Token*[], SExp*) parse(Token*[] tokens, SExp* sexp) {
  int i = 0;

  while (true) {
    if (i == tokens.length || tokens[i] is null) {
      break;
    }

    auto token = tokens[i];

    switch (token.type) {
    case TokenType.LeftParen:
      auto program = parse(tokens[i + 1 .. tokens.length]);
      sexp.sexps ~= program[1];
      tokens = program[0];
      i = -1;
      break;
    case TokenType.RightParen:
      return Tuple!(Token*[], SExp*)(tokens[i + 1 .. tokens.length], sexp);
      break;
    case TokenType.Quote:
      auto quoteSexp = new SExp;

      auto quote = new SExp;
      quote.atom = new Token(0, 0, "", "quote", TokenType.Quote, SchemeType.Symbol);

      auto program = parse(tokens[i + 1 .. tokens.length]);

      quoteSexp.sexps ~= quote;
      quoteSexp.sexps ~= program[1];
      sexp.sexps ~= quoteSexp;

      tokens = [new Token(0, 0, "", ")", TokenType.RightParen)];
      foreach (nextToken; program[0]) {
        tokens ~= nextToken;
      }
      i = -1;
      break;
    default:
      auto atom = new SExp;
      atom.atom = token;
      (*sexp).sexps ~= atom;
      break;
    }

    i += 1;
  }

  if (i > 0) {
    return Tuple!(Token*[], SExp*)(tokens[i + 1 .. tokens.length], sexp);
  }

  return Tuple!(Token*[], SExp*)([], sexp);
}

Tuple!(Token*[], SExp*) parse(Token*[] tokens) {
  return parse(tokens, new SExp);
}
