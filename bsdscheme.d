import core.stdc.stdlib;
import std.conv;
import std.file;
import std.format;
import std.functional;
import std.stdio;
import std.string;
import std.typecons;

enum TokenType {
  LeftParen,
  RightParen,
  Quote,
  Symbol,
}

enum SchemeType {
  String,
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

Token* lexQuote(StringBuffer input) {
  if (input.current() == '\'') {
    return new Token(0, 0, "", "\'", TokenType.Quote);
  }

  return null;
}

Token* lexBool(StringBuffer input) {
  if (input.current() == '#') {
    input.next();

    if (input.current() == 't' || input.current() == 'f') {
      return new Token(0, 0, "", "#", TokenType.Symbol, SchemeType.Bool);
    }

    input.previous();
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

    return new Token(0, 0, "", symbol, TokenType.Symbol, schemeType);
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
      token = lexBool(input);
    }

    if (token !is null) {
      tokens.push(token);
    }
  } while (input.next());

  return tokens;
}

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
      quote.atom = new Token(0, 0, "", "quote", TokenType.Quote);

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

alias Tuple!(Value, Value) List;

struct Value {
  int* _integer;
  string _string;
  string _symbol;
  List* _list;
  bool _nil;
  bool* _bool;
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

Value times(SExp*[] arguments, Context ctx) {
  int i = 1;

  foreach (arg; arguments) {
    i *= *(interpret(arg, ctx))._integer;
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

Value lambda(SExp*[] arguments, Context ctx) {
  auto funArguments = arguments[0].sexps;
  auto funBody = arguments[1];

  Value defined(SExp*[] parameters, Context ctx) {
    Context newCtx = ctx.dup();

    for (int i = 0; i < funArguments.length; i++) {
      auto key = funArguments[i].atom.value;
      auto value = parameters[i];
      newCtx.set(key, interpret(value, ctx));
    }

    return interpret(funBody, newCtx);
  }

  Value funValue;
  funValue._fun = &defined;
  return funValue;
}

Value define(SExp*[] arguments, Context ctx) {
  auto name = arguments[0].atom.value;
  Value value;

  if (arguments.length > 2) {
    value = lambda(arguments[1 .. arguments.length], ctx);
  } else {
    value = interpret(arguments[1], ctx);
  }

  ctx.set(name, value);
  return value;
}

Value equals(SExp*[] arguments, Context ctx) {
  auto left = interpret(arguments[0], ctx);
  auto right = interpret(arguments[1], ctx);

  Value v;
  bool b;

  if (left._integer !is null) {
    b = right._integer !is null && *(right._integer) == *(left._integer);
  } else if (left._string !is null) {
    b = right._string !is null && right._string == left._string;
  } else if (left._symbol !is null) {
    b = right._symbol !is null && right._symbol == left._symbol;
  } else if (left._fun !is null) {
    b = right._fun !is null && right._fun == left._fun;
  } else if (left._bool !is null) {
    b = right._bool !is null && *(right._bool) == *(left._bool);
  }

  v._bool = new bool(b);
  return v;
}

Value ifFun(SExp*[] arguments, Context ctx) {
  auto test = interpret(arguments[0], ctx);
  auto ok = false;

  if (test._integer !is null) {
    ok = *(test._integer) != 0;
  } else if (test._string !is null) {
    ok = test._string.length != 0;
  } else if (test._symbol !is null) {
    ok = true;
  } else if (test._fun !is null) {
    ok = true;
  } else if (test._bool !is null) {
    ok = *test._bool;
  }

  if (ok) {
    return interpret(arguments[1], ctx);
  }

  return interpret(arguments[2], ctx);
 }

string valueToString(Value value) {
  if (value._integer !is null) {
    return format("%d", *(value._integer));
  } else if (value._bool !is null) {
    if (*(value._bool)) {
      return "#t";
    }

    return "#f";
  } else if (value._symbol !is null) {
    return value._symbol;
  } else if (value._string !is null) {
    return value._string;
  } else if (value._list !is null) {
    return format("(%s . %s)", valueToString((*value._list)[0]), valueToString((*value._list)[1]));
  } else if (value._nil) {
    return "'()";
  }

  return format("unknown value (%s)", value);
}

Value display(SExp*[] arguments, Context ctx) {
  auto value = interpret(arguments[0], ctx);
  write(valueToString(value));
  return nilValue;
}

Value newline(SExp*[] arguments, Context ctx) {
  write("\n");
  return nilValue;
}

Value setFun(SExp*[] arguments, Context ctx) {
  auto name = arguments[0].atom.value;
  auto value = interpret(arguments[1], ctx);
  ctx.set(name, value);
  return value;
}

Value atomToValue(Token* atom) {
  if (atom is null) {
    return nilValue;
  }

  Value v;
  string sValue = atom.value;
  switch (atom.schemeType) {
  case SchemeType.Integer:
    int* i = new int(to!int(sValue));
    v._integer = i;
    break;
  case SchemeType.String:
    v._string = sValue;
    break;
  case SchemeType.Symbol:
    v._symbol = sValue;
    break;
  case SchemeType.Bool:
    bool* b = new bool(atom.value == "#t");
    v._bool = b;
    break;
  default:
    return nilValue;
    break;
  }

  return v;
}

Value quote(SExp*[] arguments, Context ctx) {
  if (arguments.length == 0) {
    // TODO: probs should be an error?
    return nilValue;
  }

  // TODO: handle arguments[0] is nilish?
  if (arguments.length == 1) {
    auto atom = arguments[0].atom;
    auto sexps = arguments[0].sexps;
    bool isPrimitive = sexps is null;
    if (isPrimitive) {
      return atomToValue(atom);
    }

    return quote(sexps, ctx);
  }

  Value value;
  Value *iterator = &value;
  foreach (argument; arguments) {
    List* l = new List(quote([argument], ctx), nilValue);
    (*iterator)._nil = false;
    (*iterator)._list = l;
    iterator = &((*l)[1]);
  }

  return value;
}

Value cons(SExp*[] arguments, Context ctx) {
  auto first = interpret(arguments[0], ctx);
  auto second = interpret(arguments[1], ctx);

  Value list;
  list._list = new List(first, second);
  return list;
}

Value car(SExp*[] arguments, Context ctx) {
  auto list = interpret(arguments[0], ctx);
  return (*list._list)[0];
}

class Context {
  Value[string] map;
  Value function(SExp*[], Context)[string] builtins;

  this() {
    this.builtins = [
      "if": &ifFun,
      "+": &plus,
      "-": &minus,
      "*": &times,
      "let": &let,
      "define": &define,
      "lambda": &lambda,
      "=": &equals,
      "newline": &newline,
      "display": &display,
      "set!": &setFun,
      "quote": &quote,
      "cons": &cons,
      "car": &car,
    ];
  }

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

    if (key in this.builtins) {
      value._fun = toDelegate(builtins[key]);
    }

    if (key in this.map) {
      value = this.map[key];
    }

    return value;
  }
}

void error(string msg, Value value) {
  writeln(format("[ERROR] %s: %s", msg, valueToString(value)));
  exit(1);
}

Value interpret(SExp* sexp, Context ctx, bool topLevel) {
  if (sexp is null) {
    return nilValue;
  }

  bool isPrimitive = sexp.sexps is null;
  if (isPrimitive) {
    Value v = atomToValue(sexp.atom);

    if (v._symbol !is null) {
      return ctx.get(v._symbol);
    }
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
        } else {
          error("Call of non-procedure", head);
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
    buffer = parsed[0];
  }

  return 0;
}
