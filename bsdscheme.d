import std.conv;
import std.stdio;
import std.string;

enum TokenType {
  LeftParen,
  RightParen,
  Symbol,
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
  string symbol = "";
  string currentCharAsString = "";

  while ((currentCharAsString = to!string(input.current())) != " ") {
    symbol ~= currentCharAsString;

    if (!input.next()) {
      break;
    }
  }

  if (symbol.length) {
    return new Token(0, 0, "", symbol, TokenType.Symbol);
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
      token = lexSymbol(input);
    }

    if (token !is null) {
      tokens.push(token);
    }
  } while (!input.next());

  return tokens;
}

alias Buffer!(SExp*) SExpBuffer;

struct Exp {
  SExp* head;
  SExpBuffer tail;
};

alias Atom Token;

class SExp {
  union {
    Exp* exp;
    Atom* atom;
  } value;

  bool isAtom() {
    return this.value.atom !is null;
  }
};

class Program {
  SExp* program;

  this(SExp program) {
    this.program = program;
  }

  void run() {
    
  }
}

Program parse(TokenBuffer tokens) {
  SExp* sexp;
  SExp* currentSexp = sexp;

  do {
    auto token = tokens.current();

    if (token.type == LeftParen) {
      if (currentSexp is null) {
        currentSexp = new SExp;
      } else if (current.head is null) {
        currentSexp.head = new SExp;
        currentSexp = sexp.head;
      } else {
        sexp.tail.push(new SExp);
        sexp.tail.next();
        currentSexp = sexp.tail.current();
      }
    } else if (token.type == RightParen) {
      if (sexp.head !is null) {
        sexp.tail.increase(1);
        sexp.tail.next();
      }
    } else {
      currentSexp.value.atom = token;
    }
  } while (!tokens.next());

  return new Program(sexp);
}

int main() {
  auto source = "(+ (- 3 2) 5)".dup;
  auto tokens = lex(new StringBuffer(source));
  auto program = parse(tokens);
  program.run();
  return 0;
}
