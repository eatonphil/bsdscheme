import core.stdc.stdlib;
import std.bigint;
import std.file : read;
import std.format;
import std.functional;
import std.stdio;
import std.uni;

import ast;
import parse;
import utility;

import value;

void error(string msg, Value value) {
  writeln(format("[ERROR] %s: %s", msg, formatValue(value)));
  exit(1);
}

Value reduceValues(Value delegate(Value, Value) f, Value arguments, Context ctx, ref Value initial) {
  Value result = initial;
  auto tmp = arguments;

  while (astIsList(tmp)) {
    auto tuple = astToList(tmp);
    result = f(result, tuple[0]);
    tmp = tuple[1];
  }

  return result;
}

Value mapValues(Value delegate(Value, Context) f, Value arguments, Context ctx) {
  Value mapped;
  auto tmp = arguments;

  while (astIsList(tmp)) {
    auto tuple = astToList(tmp);
    Value mappedElement = f(tuple[0], ctx);
    mapped = appendList(mapped, makeListAst(mappedElement, nilValue));
    tmp = tuple[1];
  }

  return mapped;
}

Value plus(Value arguments, Context ctx) {
  Value _plus(Value previous, Value current) {
    if (astIsBigInteger(previous) || astIsBigInteger(current)) {
      BigInt a, b;

      if (astIsBigInteger(previous)) {
        a = astToBigInteger(previous);
      } else {
        a = BigInt(astToInteger(previous));
      }

      if (astIsBigInteger(current)) {
        b = astToBigInteger(current);
      } else {
        b = BigInt(astToInteger(current));
      }

      return makeBigIntegerAst(a + b);
    }

    long a = astToInteger(previous);
    long b = astToInteger(current);

    if (b > 0 && a > long.max - b ||
        b < 0 && a < long.max - b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerAst(bA + bB);
    }

    return makeIntegerAst(a + b);
  }

  return reduceValues(&_plus, arguments, ctx, zeroValue);
}

Value times(Value arguments, Context ctx) {
  Value _times(Value previous, Value current) {
    if (astIsBigInteger(previous) || astIsBigInteger(current)) {
      BigInt a, b;

      if (astIsBigInteger(previous)) {
        a = astToBigInteger(previous);
      } else {
        a = BigInt(astToInteger(previous));
      }

      if (astIsBigInteger(current)) {
        b = astToBigInteger(current);
      } else {
        b = BigInt(astToInteger(current));
      }

      return makeBigIntegerAst(a * b);
    }

    long a = astToInteger(previous);
    long b = astToInteger(current);

    if (a > long.max / b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerAst(bA * bB);
    }

    return makeIntegerAst(a * b);
  }

  auto tuple = astToList(arguments);
  return reduceValues(&_times, tuple[1], ctx, tuple[0]);
}

// TODO: unify plus and minus
Value minus(Value arguments, Context ctx) {
  Value _minus(Value previous, Value current) {
    if (astIsBigInteger(previous) || astIsBigInteger(current)) {
      BigInt a, b;

      if (astIsBigInteger(previous)) {
        a = astToBigInteger(previous);
      } else {
        a = BigInt(astToInteger(previous));
      }

      if (astIsBigInteger(current)) {
        b = astToBigInteger(current);
      } else {
        b = BigInt(astToInteger(current));
      }

      return makeBigIntegerAst(a - b);
    }

    long a = astToInteger(previous);
    long b = astToInteger(current);

    if (b > 0 && a > long.max - b ||
        b < 0 && a < long.max - b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerAst(bA - bB);
    }

    return makeIntegerAst(a - b);
  }

  auto tuple = astToList(arguments);
  return reduceValues(&_minus, tuple[1], ctx, tuple[0]);
}

Value let(Value arguments, Context ctx) {
  auto tuple = astToList(arguments);
  auto bindings = tuple[0];
  auto letBody = car(tuple[1]);

  Context newCtx = ctx.dup();

  auto tmp = astToList(bindings);
  while (true) {
    auto bindingTuple = astToList(tmp[0]);
    auto key = astToSymbol(bindingTuple[0]);
    auto value = eval(car(bindingTuple[1]), ctx);
    newCtx.set(key, value);

    if (astIsList(tmp[1])) {
      tmp = astToList(tmp[1]);
    } else {
      break;
    }
  }

  return eval(letBody, newCtx);
}

Value namedLambda(Value arguments, Context ctx, string name) {
  auto funArguments = car(arguments);
  auto funBody = cdr(arguments);

  Value defined(Value parameters, Context ctx) {
    Context newCtx = ctx.dup();

    if (astIsList(funArguments)) {
      auto keyTmp = astToList(funArguments);
      auto valueTmp = astToList(parameters);
      while (true) {
        auto key = astToSymbol(keyTmp[0]);
        auto value = valueTmp[0];

        newCtx.set(key, value);

        // TODO: handle arg count mismatch
        if (astIsList(keyTmp[1])) {
          keyTmp = astToList(keyTmp[1]);
          valueTmp = astToList(valueTmp[1]);
        } else {
          break;
        }
      }
    } else if (astIsSymbol(funArguments)) {
      auto key = astToSymbol(funArguments);
      newCtx.set(key, car(parameters));
    } else {
      error("Expected symbol or list in lambda formals", funArguments);
    }

    auto begin = makeSymbolAst("begin");
    auto withBegin = makeListAst(begin, funBody);
    return eval(withBegin, newCtx);
  }

  return makeFunctionValue(name, &defined, false);
}

Value lambda(Value arguments, Context ctx) {
  return namedLambda(arguments, ctx, "lambda");
}

Value define(Value arguments, Context ctx) {
  auto tuple = astToList(arguments);
  auto name = astToSymbol(tuple[0]);
  Value value = nilValue;

  // (define (a b) b)
  if (astIsList(tuple[0])) {
    auto nameTuple = astToList(tuple[0]);
    name = astToSymbol(nameTuple[0]);
    value = namedLambda(makeListAst(nameTuple[1], tuple[1]), ctx, name);
  } else { // (define a)
    if (astIsNil(tuple[1])) {
      error("expected value to bind to symbol", tuple[0]);
    } else { // (define a 4)
      value = eval(astToList(tuple[1])[0], ctx);
    }
  }

  ctx.set(name, value);
  return value;
}

Value equals(Value arguments, Context ctx) {
  auto tuple = astToList(arguments);
  auto left = tuple[0];
  auto right = car(tuple[1]);

  bool b;

  switch (tagOfAst(left)) {
  case ASTTag.Integer:
    b = astIsInteger(right) && astToInteger(left) == astToInteger(right);
    break;
  case ASTTag.Char:
    b = astIsChar(right) && astToChar(left) == astToChar(right);
    break;
  case ASTTag.String:
    b = astIsString(right) && astToString(left) == astToString(right);
    break;
  case ASTTag.Symbol:
    b = astIsSymbol(right) && astToSymbol(left) == astToSymbol(right);
    break;
  case FunctionTag:
    b = valueIsFunction(right) && valueToFunction(left)[1] == valueToFunction(right)[1];
    break;
  case ASTTag.Bool:
    b = astIsBool(right) && astToBool(left) == astToBool(right);
    break;
  default:
    b = false;
  }

  return makeBoolAst(b);
}

Value ifFun(Value arguments, Context ctx) {
  auto tuple = astToList(arguments);
  auto test = eval(tuple[0], ctx);
  auto ok = astIsInteger(test) && astToInteger(test) ||
    astIsString(test) && astToString(test).length ||
    astIsSymbol(test) ||
    valueIsFunction(test) ||
    astIsBool(test) && astToBool(test);

  tuple = astToList(tuple[1]);
  if (ok) {
    return eval(tuple[0], ctx);
  }

  // TODO: support no second argument
  return eval(car(tuple[1]), ctx);
}

Value display(Value arguments, Context ctx) {
  Value head = car(arguments);
  write(formatValue(head));
  return nilValue;
}

Value newline(Value arguments, Context ctx) {
  write("\n");
  return nilValue;
}

Value setFun(Value arguments, Context ctx) {
  auto tuple = astToList(arguments);
  auto name = astToSymbol(tuple[0]);
  auto value = eval(car(tuple[1]), ctx);
  ctx.set(name, value);
  return value;
}

Value quote(Value arguments, Context ctx) {
  return car(arguments);
}

Value cons(Value arguments, Context ctx) {
  return arguments;
}

Value _car(Value arguments, Context ctx) {
  return car(car(arguments));
}

Value _cdr(Value arguments, Context ctx) {
  return astToList(car(arguments))[1];
}

Value begin(Value arguments, Context ctx) {
  Value result = arguments;
  auto tmp = astToList(arguments);

  while (true) {
    result = tmp[0];

    if (astIsList(tmp[1])) {
      tmp = astToList(tmp[1]);
    } else {
      break;
    }
  }

  return result;
}

Value eval(Value value, Context ctx) {
  switch (tagOfAst(value)) {
  case ASTTag.Symbol:
    return ctx.get(astToSymbol(value));
    break;
  case ASTTag.List:
    auto v = astToList(value);

    auto car = eval(v[0], ctx);
    auto cdr = v[1];

    if (!valueIsFunction(car)) {
      error("Call of non-procedure", car);
      return nilValue;
    }

    auto fn = valueToFunction(car);
    string fnName = fn[0];
    auto fnDelegate = fn[1];
    bool fnIsSpecial = fn[2];

    auto args = v[1];
    // Evaluate all arguments unless this is a special function.
    if (!fnIsSpecial) {
      args = mapValues(toDelegate(&eval), args, ctx);
    }

    return fnDelegate(args, ctx);
    break;
  default:
    return value;
    break;
  }
}

Value _eval(Value arguments, Context ctx) {
  return eval(eval(car(arguments), ctx), ctx);
}

Value _read(Value arguments, Context ctx) {
  Value arg1 = car(arguments);
  string s = astToString(arg1);
  string sWithBegin = format("(begin %s)", s);
  return quote(parse.read(sWithBegin.dup), ctx);
}

Value include(Value arguments, Context ctx) {
  Value arg1 = car(arguments);
  string includeFile = astToString(arg1);
  string fileContents = (cast(char[])read(includeFile)).dup;
  Value source = makeStringAst(fileContents);
  Value readArgs = makeListAst(source, nilValue);
  Value parsed = _read(readArgs, ctx);
  return eval(parsed, ctx);
}

Value stringP(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  bool b = astIsString(arg1);
  return makeBoolAst(b);
}

Value makeString(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  long k = astToInteger(arg1);
  char[] s;
  s.length = k;

  char fill = '\0';

  auto rest = cdr(arguments);
  if (!astIsNil(rest)) {
    auto arg2 = car(cdr(arguments));
    fill = astToChar(arg2);
  }

  for (int i = 0; i < k; i++) {
    s[i] = fill;
  }

  return makeStringAst(s.dup);
}

Value stringFun(Value arguments, Context ctx) {
  string s = "";

  auto iterator = arguments;
  while (!astIsNil(iterator)) {
    auto arg = car(iterator);
    char c = astToChar(arg);
    s ~= c;
    iterator = cdr(iterator);
  }

  return makeStringAst(s);
}

Value stringLength(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  long l = astToString(arg1).length;
  return makeIntegerAst(l);
}

Value stringRef(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto arg2 = car(cdr(arguments));
  string s = astToString(arg1);
  long i = astToInteger(arg2);
  return makeCharAst(s[i]);
}

Value stringEquals(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  string s = astToString(arg1);

  auto iterator = cdr(arguments);
  while (!astIsNil(iterator)) {
    auto arg = car(iterator);
    if (s != astToString(arg)) {
      return makeBoolAst(false);
    }
    iterator = cdr(iterator);
  }

  return makeBoolAst(true);
}

Value stringSet(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto symbol = astToSymbol(arg1);
  auto value = eval(arg1, ctx);

  auto arg2 = eval(car(cdr(arguments)), ctx);
  long k = astToInteger(arg2);

  auto arg3 = eval(car(cdr(cdr(arguments))), ctx);
  char c = astToChar(arg3);

  updateAstString(value, k, c);
  return value;
}

Value stringAppend(Value arguments, Context ctx) {
  string s = "";

  auto iterator = arguments;
  while (!astIsNil(iterator)) {
    auto arg = car(iterator);
    s ~= astToString(arg);
    iterator = cdr(iterator);
  }

  return makeStringAst(s);
}

Value listToString(Value arguments, Context ctx) {
  return stringFun(car(arguments), ctx);
}

Value stringUpcase(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto s = astToString(arg1);
  return makeStringAst(toUpper(s));
}

Value stringDowncase(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto s = astToString(arg1);
  return makeStringAst(toLower(s));
}

Value stringFill(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  string symbol = astToSymbol(arg1);
  auto value = eval(arg1, ctx);
  char[] s = astToString(value).dup;

  auto arg2 = eval(car(cdr(arguments)), ctx);
  char c = astToChar(arg2);

  long start = 0, end = s.length;

  auto cddr = cdr(cdr(arguments));
  if (!astIsNil(cddr)) {
    auto arg3 = eval(car(cddr), ctx);
    start = astToInteger(arg3);

    auto cdddr = cdr(cddr);
    if (!astIsNil(cdddr)) {
      auto arg4 = eval(car(cdddr), ctx);
      end = astToInteger(arg4);
    }
  }

  for (long i = start; i < end; i++) {
    updateAstString(value, i, c);
  }

  ctx.set(symbol, value);

  return value;
}

Value substring(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  char[] s = astToString(arg1).dup;

  auto arg2 = car(cdr(arguments));
  long start = astToInteger(arg2);

  auto arg3 = car(cdr(cdr(arguments)));
  long end = astToInteger(arg3);

  return makeStringAst(s[start .. end].dup);
}

Value stringToList(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  char[] s = astToString(arg1).dup;

  auto value = nilValue;

  foreach (char c; s) {
    auto cValue = makeCharAst(c);
    auto part = makeListAst(cValue, nilValue);
    value = appendList(value, part);
  }

  return value;
}

Value vectorFun(Value arguments, Context ctx) {
  Value[] vector;
  auto iterator = car(arguments);
  while (!astIsNil(iterator)) {
    vector ~= eval(car(iterator), ctx);
    iterator = cdr(iterator);
  }

  auto f = makeVectorAst(vector);
  return f;
}

Value vectorLength(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto vector = astToVector(arg1);
  return makeIntegerAst(vector.length);
}

Value vectorRef(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto vector = astToVector(arg1);

  auto arg2 = car(cdr(arguments));
  long i = astToInteger(arg2);

  return vector[i];
}

Value vectorP(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  return makeBoolAst(astIsVector(arg1));
}

Value vectorSet(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  string symbol = astToSymbol(arg1);
  auto value = eval(arg1, ctx);

  auto arg2 = eval(car(cdr(arguments)), ctx);
  long index = astToInteger(arg2);

  auto arg3 = eval(car(cdr(cdr(arguments))), ctx);

  updateAstVector(value, index, arg3);
  return value;
}

Value vectorFill(Value arguments, Context ctx) {
  auto arg1 = car(arguments);
  string symbol = astToSymbol(arg1);
  auto value = eval(arg1, ctx);
  auto vector = astToVector(value);

  auto arg2 = eval(car(cdr(arguments)), ctx);

  long start = 0, end = vector.length;

  auto cddr = cdr(cdr(arguments));
  if (!astIsNil(cddr)) {
    auto arg3 = eval(car(cddr), ctx);
    start = astToInteger(arg3);

    auto cdddr = cdr(cddr);
    if (!astIsNil(cdddr)) {
      auto arg4 = eval(car(cdddr), ctx);
      end = astToInteger(arg4);
    }
  }

  for (long i = start; i < end; i++) {
    updateAstVector(value, i, arg2);
  }

  return value;
}

Value vectorToString(AST arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto vector = astToVector(arg1);

  string s = "";

  foreach (c; vector) {
    s ~= astToChar(c);
  }

  return makeStringAst(s);
}

Value stringToVector(AST arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto s = astToString(arg1);

  AST[] v;

  foreach (c; s) {
    v ~= makeCharAst(c);
  }

  return makeVectorAst(v);
}

Value _vectorToList(AST arguments, Context ctx) {
  auto arg1 = car(arguments);
  return vectorToList(astToVector(arg1));
}

Value _listToVector(AST arguments, Context ctx) {
  return makeVectorAst(listToVector(car(arguments)));
}

Value vectorAppend(AST arguments, Context ctx) {
  AST[] vector;

  auto iterator = arguments;
  while (!astIsNil(iterator)) {
    auto arg = car(iterator);
    auto vArg = astToVector(arg);
    vector ~= vArg;
    iterator = cdr(iterator);
  }

  return makeVectorAst(vector);
}

Value makeVector(AST arguments, Context ctx) {
  auto arg1 = car(arguments);
  auto k = astToInteger(arg1);

  char c = '\0';
  auto rest = cdr(arguments);
  if (!astIsNil(rest)) {
    auto arg2 = car(rest);
    c = astToChar(arg2);
  }

  AST[] v;
  v.length = k;

  foreach (i, _; v) {
    v[i] = makeCharAst(c);
  }

  return makeVectorAst(v);
}

class Context {
  Value[string] map;
  Value function(Value, Context)[string] builtins;
  Value function(Value, Context)[string] builtinSpecials;

  this() {
    this.builtins = [
      "+": &plus,
      "-": &minus,
      "*": &times,
      "=": &equals,
      "cons": &cons,
      "car": &_car,
      "cdr": &_cdr,
      "begin": &begin,
      "display": &display,
      "newline": &newline,
      "read": &_read,
      "include": &include,
      "string?": &stringP,
      "make-string": &makeString,
      "string": &stringFun,
      "string-length": &stringLength,
      "string-ref": &stringRef,
      "string=?": &stringEquals,
      "string-append": &stringAppend,
      "list->string": &listToString,
      "string-upcase": &stringUpcase,
      "string-downcase": &stringDowncase,
      "substring": &substring,
      "string->list": &stringToList,
      "vector-length": &vectorLength,
      "vector-ref": &vectorRef,
      "vector?": &vectorP,
      "vector->string": &vectorToString,
      "string->vector": &stringToVector,
      "vector->list": &_vectorToList,
      "list->vector": &_listToVector,
      "vector-append": &vectorAppend,
      "make-vector": &makeVector,
    ];

    this.builtinSpecials = [
      "if": &ifFun,
      "let": &let,
      "define": &define,
      "lambda": &lambda,
      "set!": &setFun,
      "eval": &_eval,
      "quote": &quote,
      "string-set!": &stringSet,
      "string-fill!": &stringFill,
      "vector": &vectorFun,
      "vector-set!": &vectorSet,
      "vector-fill!": &vectorFill,
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

    if (key in builtins) {
      value = makeFunctionValue(key, toDelegate(builtins[key]), false);
    } else if (key in builtinSpecials) {
      value = makeFunctionValue(key, toDelegate(builtinSpecials[key]), true);
    }

    if (key in map) {
      value = map[key];
    }

    return value;
  }
}
