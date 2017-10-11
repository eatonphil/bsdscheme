import std.conv;
import std.stdio;
import std.string;

enum TokenType {
  LeftParen,
  RightParen,
  Integer,
}

struct Token {
  int line;
  int lineOffset;
  string filename;
  string value;
  TokenType type;
}

class Buffer(T) {
  int index;
  T[] buffer;

  this(T[] buffer) {
    this.buffer = buffer;
    this.index = -1;
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
alias Buffer!(Token) TokenBuffer;

Token* lexLeftParen(StringBuffer input) {
  if (input.current() == '(') {
    return new Token(0, 0, "", "(", TokenType.LeftParen);
  }

  return null;
}

Token* lexRightParen(StringBuffer input) {
  if (input.current() == ')') {
    return new Token(0, 0, "", ")", TokenType.RightParen);
  }

  return null;
}

Token* lexSymbol(StringBuffer input) {
  auto intString = "";

  while (true) {
    intString ~= currentCharAsString;
    currentCharAsString = to!string(input.current());

    input.next();
  }

  if (intString.length) {
    input.previous();
    return new Token(0, 0, "", intString, TokenType.Integer);
  }

  return null;
}

TokenBuffer lex(StringBuffer input) {
  auto tokens = new TokenBuffer();

  while (input.next()) {
    auto token = lexLeftParen(input);
    if (token is null) {
      token = lexRightParen(input);
    }

    if (token is null) {
      token = lexRightParen(input);
    }

    if (token is null) {
      token = lexSymbol(input);
    }

    if (token !is null) {
      tokens.push(*token);
    }
  }

  return tokens;
}

void parse() {
  char[] program = "(+ (- 3 2) 5)".dup;
  writeln(lex(new StringBuffer(program)).buffer);
}

int main() {
  parse();
  return 0;
}
