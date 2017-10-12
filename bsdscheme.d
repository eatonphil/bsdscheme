import std.conv;
import std.stdio;
import std.string;
import std.typecons;
import std.variant;

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

 loop: do {
    auto c = input.current();

    switch (c) {
    case '(':
    case ')':
    case ' ':
    case '\n':
    case '\t':
      break loop;
      break;
    default:
      symbol ~= to!string(c);
    }
  } while (input.next());

  if (symbol.length) {
    input.previous();
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
  } while (input.next());

  return tokens;
}

alias Buffer!(SExp*) SExpBuffer;
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
      (*sexp).sexps ~= program[1];
      tokens = program[0];
      i = -1;
      break;
    case TokenType.RightParen:
      return Tuple!(Token*[], SExp*)(tokens[i + 1 .. tokens.length], sexp);
      break;
    default:
      auto atom = new SExp;
      atom.atom = token;
      (*sexp).sexps ~= atom;
      break;
    }

    i += 1;
  }

  return Tuple!(Token*[], SExp*)(tokens[i + 1 .. tokens.length], sexp);
}

Tuple!(Token*[], SExp*) parse(Token*[] tokens) {
  return parse(tokens, new SExp);
}

void print(SExp* sexp) {
  if (sexp is null) {
    return;
  }

  if (sexp.atom !is null) {
    return;
  }

  if (sexp.sexps !is null) {
    foreach (ref _sexp; sexp.sexps) {
      print(_sexp);
    }
  }
}

struct Value {
  int* _integer;
  string* _string;
  string* _symbol;
  bool _nil;
  Value* function(SExp*[], Context ctx) _fun;
}

Value* plus(SExp*[] arguments, Context ctx) {
  int i = 0;

  foreach (arg; arguments) {
    i += *(*(interpret(arg, ctx)))._integer;
  }

  auto v = new Value;
  v._integer = new int(i);
  return v;
}

Value* minus(SExp*[] arguments, Context ctx) {
  int i = *(*(interpret(arguments[0], ctx)))._integer;

  foreach (arg; arguments[1 .. arguments.length]) {
    i -= *(*(interpret(arg, ctx)))._integer;
  }

  auto v = new Value;
  v._integer = new int(i);
  return v;
}

Value* let(SExp*[] arguments, Context ctx) {
  auto bindings = arguments[0].sexps;
  auto letBody = arguments[1];

  Context newCtx = ctx.dup();

  foreach (binding; bindings) {
    auto key = binding.sexps[0].atom.value;
    auto value = binding.sexps[1];
    newCtx.set(key, interpret(value, ctx));
  }

  return interpret(letBody, newCtx);
}

class Context {
  Value*[string] map;

  void set(string key, Value* value) {
    this.map[key] = value;
  }

  Context dup() {
    Context dup = new Context;
    dup.map = this.map.dup;
    return dup;
  }

  Value* get(string key) {
    Value* value = null;

    if (key in this.map) {
      value = this.map[key];
    }

    if (isNumeric(key)) {
      value = new Value;
      value._integer = new int(to!int(key));
    } else if (key == "+") {
      value = new Value;
      value._fun = &plus;
    } else if (key == "-") {
      value = new Value;
      value._fun = &minus;
    } else if (key == "let") {
      value = new Value;
      value._fun = &let;
    }

    return value;
  }
}

Value* interpret(SExp* sexp, Context ctx) {
  Value* v = new Value;

  if (sexp is null) {
    // TODO: handle this?
    v._nil = true;
    return v;
  }

  if (sexp.atom !is null) {
    return ctx.get(sexp.atom.value);
  }

  if (sexp.sexps !is null) {
    auto head = interpret(sexp.sexps[0], ctx);
    auto tail = sexp.sexps[1 .. sexp.sexps.length];

    if (!head._nil) {
      if (head._fun !is null) {
        return (*(head._fun))(tail, ctx);
      } else if (tail.length == 0) {
        return head;
      } else {
        // TODO: handle head not being a function
      }
    } else {
      // TODO: handle this: ((identity +) 1 2)
    }
  }

  v._nil = true;
  return v;
  // TODO: handle this?
}

int main() {
  auto source = "(let ((a 7)) (+ (- 3 2) a 3))".dup;
  auto tokens = lex(new StringBuffer(source));
  auto program = parse(tokens.buffer)[1];
  auto value = interpret(program, new Context);
  writeln(*value._integer);
  return 0;
}
