import std.conv;
import std.string;
import std.stdio;

import buffer;

enum TokenType {
  LeftParen,
  RightParen,
  Special,
  Atom,
  Dot,
}

enum SchemeType {
  String,
  Char,
  Symbol,
  Integer,
  Bool,
}

struct Token {
  int line;
  int lineOffset;
  string filename;
  string value;
  TokenType type;
  SchemeType schemeType;
}

alias Buffer!(char) StringBuffer;

Token* lexLeftParen(StringBuffer input, int line, int column) {
  char c = input.current();
  if (c == '(' || c == '[') {
    return new Token(line, column, "", to!string(c), TokenType.LeftParen);
  }

  return null;
}

Token* lexRightParen(StringBuffer input, int line, int column) {
  char c = input.current();
  if (c == ')' || c == ']') {
    return new Token(line, column, "", to!string(c), TokenType.RightParen);
  }

  return null;
}

Token* lexQuote(StringBuffer input, int line, int column) {
  if (input.current() == '\'') {
    return new Token(line, column, "", "quote", TokenType.Special, SchemeType.Symbol);
  }

  return null;
}

Token* lexBool(StringBuffer input, int line, ref int column) {
  if (input.current() == '#') {
    input.next();

    column++;
    auto c = input.current();
    if (c == 't' || c == 'f') {
      column++;
      input.next();
      return new Token(line, column, "", format("#%c", c), TokenType.Atom, SchemeType.Bool);
    }

    column--;
    input.previous();
  }

  return null;
}

Token* lexChar(StringBuffer input, int line, ref int column) {
  if (input.current() == '#') {
    input.next();
    column++;

    if (input.current() == '\\') {
      column++;
      input.next();

      char[1] s = [input.current()];
      return new Token(line, column, "", s.dup, TokenType.Atom, SchemeType.Char);
    }

    column--;
    input.previous();
  }

  return null;
}

Token* lexSymbol(StringBuffer input, int line, ref int column) {
  char[] symbol;

 loop: do {
    auto c = input.current();

    switch (c) {
    case '(':
    case ')':
    case '#':
    case '\'':
    case ' ':
    case '\n':
    case '\t':
    case '"':
    case '[':
    case ']':
      break loop;
      break;
    default:
      column++;
      symbol ~= c;
    }
  } while (input.next());

  if (symbol.length) {
    column--;
    input.previous();

    auto schemeType = SchemeType.Symbol;
    if (isNumeric(symbol)) {
      schemeType = SchemeType.Integer;
    }

    return new Token(line, column, "", symbol.dup, TokenType.Atom, schemeType);
  }

  return null;
}

Token* lexString(StringBuffer input, int line, ref int column) {
  char[] s;

  if (input.current() != '"') {
    return null;
  }

  column++;
  input.next();

  do {
    auto c = input.current();

    if (c == '"') {
      break;
    }

    column++;
    s ~= c;
  } while (input.next());

  if (s.length) {
    auto schemeType = SchemeType.String;
    return new Token(line, column, "", s.dup, TokenType.Atom, schemeType);
  }

  return null;
}

Token* lexVector(StringBuffer input, int line, int column) {
  if (input.current() == '#') {
    input.next();
    char c = input.current();
    input.previous();

    if (c == '(') {
      return new Token(line, column, "", "vector", TokenType.Special, SchemeType.Symbol);
    }
  }

  return null;
}

Token* lexDot(StringBuffer input, int line, int column) {
  if (input.current() == '.') {
    input.next();
    if (input.current() == '.') {
      input.previous();
      return null;
    }

    // Match single dot only.
    return new Token(line, column, "", ".", TokenType.Dot, SchemeType.Symbol);
  }

  return null;
}

Token* lexComment(StringBuffer input, int line, ref int column) {
  if (input.current() == ';') {
    do {
      column++;
      if (input.current() == '\n') {
        break;
      }
    } while (input.next());
  }

  return null;
}

alias Buffer!(Token*) TokenBuffer;

TokenBuffer lex(StringBuffer input) {
  auto tokens = new TokenBuffer();

  int line = 1;
  int column = 0;
  do {
    column++;

    auto token = lexLeftParen(input, line, column);
    if (token is null) {
      token = lexRightParen(input, line, column);
    }

    if (token is null) {
      token = lexRightParen(input, line, column);
    }

    if (token is null) {
      token = lexQuote(input, line, column);
    }

    if (token is null) {
      token = lexDot(input, line, column);
    }

    if (token is null) {
      token = lexSymbol(input, line, column);
    }

    if (token is null) {
      token = lexChar(input, line, column);
    }

    if (token is null) {
      token = lexBool(input, line, column);
    }

    if (token is null) {
      token = lexString(input, line, column);
    }

    if (token is null) {
      token = lexComment(input, line, column);
    }

    if (token is null) {
      token = lexVector(input, line, column);
    }

    if (token !is null) {
      tokens.push(token);
    } else {
      char c = input.current();

      if (c == '\n') {
        line++;
        column = -1;
        continue;
      }

      if (c == ' ' || c == '\t') {
        continue;
      }

      throw new Exception(format("[LEX]: Unexpected token at (%d, %d): %c", line, column, input.current()));
    }
  } while (input.next());

  return tokens;
}

TokenBuffer lex(char[] input) {
  return lex(new StringBuffer(input));
}
