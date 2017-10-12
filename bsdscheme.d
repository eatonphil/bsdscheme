import std.conv;
import std.functional;
import std.file;
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

  if (i > 0) {
    return Tuple!(Token*[], SExp*)(tokens[i + 1 .. tokens.length], sexp);
  }

  return Tuple!(Token*[], SExp*)([], sexp);
}

Tuple!(Token*[], SExp*) parse(Token*[] tokens) {
  return parse(tokens, new SExp);
}

void print(SExp* sexp) {
  if (sexp is null) {
    return;
  }

  if (sexp.atom !is null) {
    writef("%s ", sexp.atom.value);
    return;
  }

  if (sexp.sexps !is null) {
    writef("(");
    foreach (ref _sexp; sexp.sexps) {
      print(_sexp);
    }
    writef(")");
  }
}

struct Value {
  int* _integer;
  string* _string;
  string* _symbol;
  bool _nil;
  Value delegate(SExp*[], Context ctx) _fun;
}

Value nilValue = { _nil: true };

Value plus(SExp*[] arguments, Context ctx) {
  int i = 0;

  foreach (arg; arguments) {
    i += *(interpret(arg, ctx))._integer;
  }

  Value v;
  v._integer = new int(i);
  return v;
}

Value minus(SExp*[] arguments, Context ctx) {
  int i = *(interpret(arguments[0], ctx))._integer;

  foreach (arg; arguments[1 .. arguments.length]) {
    i -= *(interpret(arg, ctx))._integer;
  }

  Value v;
  v._integer = new int(i);
  return v;
}

Value let(SExp*[] arguments, Context ctx) {
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

Value define(SExp*[] arguments, Context ctx) {
  auto name = arguments[0].atom.value;
  auto funArguments = arguments[1].sexps;
  auto funBody = arguments[2];
  
  Context newCtx = ctx.dup();

  Value defined(SExp*[] parameters, Context ctx) {
    for (int i = 0; i < funArguments.length; i++) {
      auto key = funArguments[i].atom.value;
      auto value = parameters[i];
      newCtx.set(key, interpret(value, ctx));
    }

    return interpret(funBody, newCtx);
  }

  Value funValue;
  funValue._fun = &defined;
  ctx.set(name, funValue);
  return funValue;
}

class Context {
  Value[string] map;

  void set(string key, Value value) {
    this.map[key] = value;
  }

  Context dup() {
    Context dup = new Context;
    dup.map = this.map.dup;
    return dup;
  }

  Value get(string key) {
    Value value;

    if (key in this.map) {
      value = this.map[key];
    }

    if (isNumeric(key)) {
      value._integer = new int(to!int(key));
    } else if (key == "+") {
      value._fun = toDelegate(&plus);
    } else if (key == "-") {
      value._fun = toDelegate(&minus);
    } else if (key == "let") {
      value._fun = toDelegate(&let);
    } else if (key == "define") {
      value._fun = toDelegate(&define);
    }

    return value;
  }
}

Value interpret(SExp* sexp, Context ctx, bool topLevel) {
  if (sexp is null) {
    // TODO: handle this?
    return nilValue;
  }

  if (sexp.atom !is null) {
    return ctx.get(sexp.atom.value);
  }

  Value[] vs;

  if (sexp.sexps !is null) {
    if (topLevel) {
      foreach (_sexp; sexp.sexps) {
        vs ~= interpret(_sexp, ctx);
      }
    } else {
      auto head = interpret(sexp.sexps[0], ctx);
      auto tail = sexp.sexps[1 .. sexp.sexps.length];

      if (!head._nil) {
        if (head._fun !is null) {
          vs ~= head._fun(tail, ctx);
        } else if (tail.length == 0) {
          vs ~= head;
        } else {
          // TODO: handle head not being a function and not at the top-level
        }
      } else {
        // TODO: handle this: ((identity +) 1 2)
      }
    }
  }

  if (vs.length == 0) {
    return nilValue;
  } else {
    return vs[vs.length - 1];
  }
}

Value interpret(SExp* sexp, Context ctx) {
  return interpret(sexp, ctx, false);
}

int main(string[] args) {
  char[] source = cast(char[])read(args[1]);
  auto tokens = lex(new StringBuffer(source));

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
    auto value = interpret(parsed[1], ctx, true);
    writeln(*value._integer);
    buffer = parsed[0];
  }

  return 0;
}
