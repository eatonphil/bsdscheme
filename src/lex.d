import std.conv;
import std.string;
import std.stdio;

enum TokenType {
  LeftParen,
  RightParen,
  Special,
  Atom,
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

class Buffer(T) {
  int index;
  T[] buffer;

  this(T[] buffer) {
    this.buffer = buffer;
    this.index = 0;
  }

  this() {
    this.buffer = [];
    this.buffer.length = 16;
  }

  T current() {
    return this.buffer[this.index];
  }

  bool next() {
    if (this.index + 1 >= this.buffer.length) {
      return false;
    }

    this.index++;
    return true;
  }

  void increase(int size) {
    this.buffer.length += size;
  }

  bool previous() {
    if (this.index == 0) {
      return false;
    }

    this.index--;
    return true;
  }

  void push(T item) {
    if (this.index / this.buffer.length > .75) {
      this.buffer.length *= 2;
    }

    this.buffer[this.index++] = item;
  }

  T pop() {
    return this.buffer[this.index--];
  }
}

alias Buffer!(char) StringBuffer;

Token* lexLeftParen(StringBuffer input) {
  char c = input.current();
  if (c == '(' || c == '[') {
    return new Token(0, 0, "", to!string(c), TokenType.LeftParen);
  }

  return null;
}

Token* lexRightParen(StringBuffer input) {
  char c = input.current();
  if (c == ')' || c == ']') {
    return new Token(0, 0, "", to!string(c), TokenType.RightParen);
  }

  return null;
}

Token* lexQuote(StringBuffer input) {
  if (input.current() == '\'') {
    return new Token(0, 0, "", "quote", TokenType.Special, SchemeType.Symbol);
  }

  return null;
}

Token* lexBool(StringBuffer input) {
  if (input.current() == '#') {
    input.next();

    if (input.current() == 't' || input.current() == 'f') {
      return new Token(0, 0, "", "#", TokenType.Atom, SchemeType.Bool);
    }

    input.previous();
  }

  return null;
}

Token* lexChar(StringBuffer input) {
  if (input.current() == '#') {
    input.next();

    if (input.current() == '\\') {
      input.next();

      char[1] s = [input.current()];
      return new Token(0, 0, "", s.dup, TokenType.Atom, SchemeType.Char);
    }

    input.previous();
  }

  return null;
}

Token* lexSymbol(StringBuffer input) {
  string symbol = "";

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
      symbol ~= to!string(c);
    }
  } while (input.next());

  if (symbol.length) {
    input.previous();

    auto schemeType = SchemeType.Symbol;
    if (isNumeric(symbol)) {
      schemeType = SchemeType.Integer;
    }

    return new Token(0, 0, "", symbol, TokenType.Atom, schemeType);
  }

  return null;
}

Token* lexString(StringBuffer input) {
  string s = "";

  if (input.current() != '"') {
    return null;
  }

  input.next();

  do {
    auto c = input.current();

    if (c == '"') {
      break;
    }

    s ~= to!string(c);
  } while (input.next());

  if (s.length) {
    auto schemeType = SchemeType.String;
    return new Token(0, 0, "", s, TokenType.Atom, schemeType);
  }

  return null;
}

Token* lexVector(StringBuffer input) {
  if (input.current() == '#') {
    input.next();
    char c = input.current();
    input.previous();

    if (c == '(') {
      return new Token(0, 0, "", "vector", TokenType.Special, SchemeType.Symbol);
    }
  }

  return null;
}

Token* lexComment(StringBuffer input) {
  if (input.current() == ';') {
    do {
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

  do {
    auto token = lexLeftParen(input);
    if (token is null) {
      token = lexRightParen(input);
    }

    if (token is null) {
      token = lexRightParen(input);
    }

    if (token is null) {
      token = lexQuote(input);
    }

    if (token is null) {
      token = lexSymbol(input);
    }

    if (token is null) {
      token = lexChar(input);
    }

    if (token is null) {
      token = lexBool(input);
    }

    if (token is null) {
      token = lexString(input);
    }

    if (token is null) {
      token = lexComment(input);
    }

    if (token is null) {
      token = lexVector(input);
    }

    if (token !is null) {
      tokens.push(token);
    }
  } while (input.next());

  return tokens;
}

TokenBuffer lex(char[] input) {
  return lex(new StringBuffer(input));
}
