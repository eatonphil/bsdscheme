import core.stdc.stdlib;
import std.bigint;
import std.conv;
import std.file;
import std.format;
import std.functional;
import std.stdint;
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
    return new Token(0, 0, "", "\'", TokenType.Quote, SchemeType.Symbol);
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
  uint header;
  void* data;
}

enum ValueTag {
  Nil,
  Integer,
  Bool,
  BigInteger,
  String,
  Symbol,
  List,
  Vector,
  Function,
}

bool isValue(ref Value v, ValueTag vt) {
  return (v.header & 32) == vt;
}

bool valueIsNil(ref Value v) { return isValue(v, ValueTag.Nil); }

Value nilValue = { data: null, header: ValueTag.Nil };

Value makeIntegerValue(uint i) {
  Value v = { data: cast(void*)i, header: ValueTag.Integer };
  return v;
}

bool valueIsInteger(ref Value v) { return isValue(v, ValueTag.Integer); }

int valueToInteger(ref Value v) {
  return cast(int)v.data;
}

Value makeBoolValue(bool b) {
  Value v = { data: cast(void*)b, header: ValueTag.Bool };
  return v;
}

bool valueIsBool(ref Value v) { return isValue(v, ValueTag.Bool); }

bool valueToBool(ref Value v) {
  return cast(bool)v.data;
}

Value makeBigIntegerValue(string i) {
  Value v = { data: new BigInt(i), header: ValueTag.BigInteger };
  return v;
}

bool valueIsBigInteger(ref Value v) { return isValue(v, ValueTag.BigInteger); }

BigInt valueToBigInteger(ref Value v) {
  return *cast(BigInt*)v.data;
}

static const int MAX_VALUE_LENGTH = uint.sizeof - 1;

Value makeStringValue(string s) {
  int size = s.length > MAX_VALUE_LENGTH ? MAX_VALUE_LENGTH : s.length;
  void* sp = new string(s);
  Value v = { data: s, header: size << 8 | ValueTag.String };
  return v;
}

bool valueIsString(ref Value v) { return isValue(v, ValueTag.String); }

string valueToString(ref Value v) {
  return *cast(string*)v.data;
}

Value makeSymbolValue(string s) {
  Value v = makeStringValue(s);
  v.header >>= 8;
  v.header <<= 8;
  v.header |= ValueTag.Symbol;
  return v;
}

bool valueIsSymbol(ref Value v) { return isValue(v, ValueTag.Symbol); }

string valueToSymbol(ref Value v) {
  return valueToString(v);
}

Value makeListValue(ref Value head, ref Value tail) {
  Value v;
  v.header = ValueTag.List;
  v.data = new void*[2];
  v.data[0] = head;
  v.data[1] = tail;
  return v;
}

bool valueIsList(ref Value v) { return isValue(v, ValueTag.List); }

Tuple!(Value, Value) valueToList(Value v) {
  return cast(Tuple!(Value, Value))(*cast(Value*)v.data[0], *cast(Value*)v.data[1]);
}

Value makeVectorValue(Value[] v) {
  int size = v.length > MAX_VALUE_LENGTH ? MAX_VALUE_LENGTH : v.length;
  Value ve = { data: v, header: size << 8 | ValueTag.Vector };
  return ve;
}

bool valueIsVector(ref Value v) { return isValue(v, ValueTag.Vector); }

Value[] valueToVector(ref Value v) {
  return cast(Value[v.header >> 8])*v.data;
}

Value makeFunctionValue(void* f) {
  Value v = { data: f, header: ValueTag.Function };
  return v;
}

bool valueIsFunction(ref Value v) { return isValue(v, ValueTag.Function); }

Value delegate(SExp*[], Context ctx) valueAsFunction(ref Value v) {
  return cast(Value delegate(SExp*[], Context ctx))v.data;
}

Value[] sexpsToValues(Value delegate (SExp, Context) f, SExp*[] arguments, Context ctx) {
  Value[arguments.length] result;

  foreach (i, arg; arguments) {
    result[i] = f(*arg, ctx);
  }

  return result;
}

Value sexpsToValue(Value delegate (Value, SExp, Context) f, SExp*[] arguments, Context ctx, ref Value initial) {
  Value result = initial;

  foreach (arg; arguments) {
    result = f(result, *arg, ctx, false);
  }

  return result;
}

Value plus(SExp*[] arguments, Context ctx) {
  Value _plus(Value previous, SExp current, Context ctx) {
    return valueAsInteger(previous) + valueAsInteger(interpret(current, ctx));
  }
  return sexpsToValue(_plus, arguments, ctx, makeIntegerValue(0));
}

Value times(SExp*[] arguments, Context ctx) {
  Value _times(Value previous, SExp current, Context ctx) {
    return valueAsInteger(previous) * valueAsInteger(interpret(current, ctx));
  }
  return sexpsToValue(_times, arguments, ctx, makeIntegerValue(0));
}

Value minus(SExp*[] arguments, Context ctx) {
  Value _minus(Value previous, SExp current, Context ctx) {
    return valueAsInteger(previous) * valueAsInteger(interpret(current, ctx));
  }
  return sexpsToValue(_minus,
                      arguments[1 .. arguments.length],
                      ctx,
                      interpret(arguments[0], ctx));
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

  return makeFunctionValue(&defined);
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

  bool b;

  if (valueIsInteger(left)) {
    b = valueIsInteger(right) && valueToInteger(left) == valueToInteger(right);
  } else if (valueIsString(left)) {
    b = valueIsString(right) && valueToString(left) == valueToString(right);
  } else if (valueIsSymbol(left)) {
    b = valueIsSymbol(right) && valueToSymbol(left) == valueToSymbol(right);
  } else if (valueIsFunction(left)) {
    b = valueIsFunction(right) && valueToFunction(left) == valueToFunction(right);
  } else if (valueIsBool(left)) {
    b = valueIsBool(right) && valueToBool(left) == valueToBool(right);
  }

  return makeBoolValue(b);
}

Value ifFun(SExp*[] arguments, Context ctx) {
  auto test = interpret(arguments[0], ctx);
  auto ok = valueIsInteger(test) && valueToInteger(test) ||
    valueIsString(test) && valueToString(test).length ||
    valueIsSymbol(test) ||
    valueIsFunction(test) ||
    valueIsBool(test) && valueToBool(test);

  if (ok) {
    return interpret(arguments[1], ctx);
  }

  return interpret(arguments[2], ctx);
 }

string valueToString(Value v) {
  if (valueIsInteger(v)) {
    return format("%d", valueToInteger(v));
  } else if (valueIsBool(v)) {
    if (valueToBool(v)) {
      return "#t";
    }

    return "#f";
  } else if (valueIsSymbol(v)) {
    return valueToSymbol(v);
  } else if (valueIsString(v)) {
    return valueToString(V);
  } else if (valueIsNil(v)) {
    return "'()";
  }

  // TODO: support printing list and vector

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
    v = makeBigIntegerValue(sValue);
    break;
  case SchemeType.String:
    v = makeStringValue(sValue);
    break;
  case SchemeType.Symbol:
    v = makeStringValue(sValue);
    break;
  case SchemeType.Bool:
    v = makeStringValue(sValue == "#t");
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

  auto value = nilValue;
  foreach (argument; arguments) {
    value = makeListValue(quote([argument], ctx), value);
  }

  return value;
}

Value cons(SExp*[] arguments, Context ctx) {
  auto first = interpret(arguments[0], ctx);
  auto second = interpret(arguments[1], ctx);

  return makeListValue(first, second);
}

Value car(SExp*[] arguments, Context ctx) {
  auto list = interpret(arguments[0], ctx);
  return valueToList(list)[1];
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
      value = makeFunctionValue(toDelegate(builtins[key]));
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

    if (valueIsSymbol(v)) {
      return ctx.get(valueToSymbol(v));
    }

    return v;
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

      if (!valueIsNil(head)) {
        if (valueIsFunction(head)) {
          vs ~= valueToFunction(head)(tail, ctx);
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
