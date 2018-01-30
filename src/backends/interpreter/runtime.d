import core.stdc.stdlib;
import core.vararg;
import std.bigint;
import std.file : read;
import std.format;
import std.functional;
import std.stdio;
import std.uni;

import common;
import value;
import parse;
import utility;

Value ifFun(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  auto tuple = valueToList(arguments);
  auto test = eval(tuple[0], ctx);
  auto ok = valueIsInteger(test) && valueToInteger(test) ||
    valueIsString(test) && valueToString(test).length ||
    valueIsSymbol(test) ||
    valueIsFunction(test) ||
    valueIsBool(test) && valueToBool(test);

  tuple = valueToList(tuple[1]);
  if (ok) {
    return eval(tuple[0], ctx);
  }

  // TODO: support no second argument
  return eval(car(tuple[1]), ctx);
}

Value mapValues(Value delegate(Value, ...) f, Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);
  Value mapped;
  auto tmp = arguments;

  while (valueIsList(tmp)) {
    auto tuple = valueToList(tmp);
    Value mappedElement = f(tuple[0], ctx);
    mapped = appendList(mapped, makeListValue(mappedElement, nilValue));
    tmp = tuple[1];
  }

  return mapped;
}

Value let(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  auto tuple = valueToList(arguments);
  auto bindings = tuple[0];
  auto letBody = car(tuple[1]);

  Context newCtx = ctx.dup();

  auto tmp = valueToList(bindings);
  while (true) {
    auto bindingTuple = valueToList(tmp[0]);
    auto key = valueToSymbol(bindingTuple[0]);
    auto value = eval(car(bindingTuple[1]), ctx);
    newCtx.set(key, value);

    if (valueIsList(tmp[1])) {
      tmp = valueToList(tmp[1]);
    } else {
      break;
    }
  }

  return eval(letBody, newCtx);
}

Value namedLambda(Value arguments, Context ctx, string name) {
  auto funArguments = car(arguments);
  auto funBody = cdr(arguments);

  Value defined(Value parameters, ...) {
    Context newCtx = ctx.dup();

    if (valueIsList(funArguments)) {
      auto keyTmp = valueToList(funArguments);
      auto valueTmp = valueToList(parameters);
      while (true) {
        auto key = valueToSymbol(keyTmp[0]);
        auto value = valueTmp[0];

        newCtx.set(key, value);

        // TODO: handle arg count mismatch
        if (valueIsList(keyTmp[1])) {
          keyTmp = valueToList(keyTmp[1]);
          valueTmp = valueToList(valueTmp[1]);
        } else {
          break;
        }
      }
    } else if (valueIsSymbol(funArguments)) {
      auto key = valueToSymbol(funArguments);
      newCtx.set(key, car(parameters));
    } else {
      error("Expected symbol or list in lambda formals", funArguments);
    }

    auto begin = makeSymbolValue("begin");
    auto withBegin = makeListValue(begin, funBody);
    return eval(withBegin, newCtx);
  }

  return makeFunctionValue(name, &defined, false);
}

Value lambda(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);
  return namedLambda(arguments, ctx, "lambda");
}

Value define(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);
  auto tuple = valueToList(arguments);
  auto name = valueToSymbol(tuple[0]);
  Value value = nilValue;

  // (define (a b) b)
  if (valueIsList(tuple[0])) {
    auto nameTuple = valueToList(tuple[0]);
    name = valueToSymbol(nameTuple[0]);
    value = namedLambda(makeListValue(nameTuple[1], tuple[1]), ctx, name);
  } else { // (define a)
    if (valueIsNil(tuple[1])) {
      error("expected value to bind to symbol", tuple[0]);
    } else { // (define a 4)
      value = eval(valueToList(tuple[1])[0], ctx);
    }
  }

  ctx.set(name, value);
  return value;
}

Value setFun(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);
  auto tuple = valueToList(arguments);
  auto name = valueToSymbol(tuple[0]);
  auto value = eval(car(tuple[1]), ctx);
  ctx.set(name, value);
  return value;
}

Value eval(Value value, ...) {
  Context ctx = va_arg!Context(_argptr);

  switch (tagOfValue(value)) {
  case ValueTag.Symbol:
    return ctx.get(valueToSymbol(value));
    break;
  case ValueTag.List:
    auto v = valueToList(value);

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

Value _eval(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);
  return eval(eval(car(arguments), ctx), ctx);
}

Value _read(Value arguments, ...) {
  Value arg1 = car(arguments);
  string s = valueToString(arg1);
  string sWithBegin = format("(begin %s)", s);
  return quote(parse.read(sWithBegin.dup), va_arg!Context(_argptr));
}

Value include(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);
  Value arg1 = car(arguments);
  string includeFile = valueToString(arg1);
  string fileContents = (cast(char[])read(includeFile)).dup;
  Value source = makeStringValue(fileContents);
  Value readArgs = makeListValue(source, nilValue);
  Value parsed = _read(readArgs, ctx);
  return eval(parsed, ctx);
}

Value stringSet(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  auto arg1 = car(arguments);
  auto symbol = valueToSymbol(arg1);
  auto value = eval(arg1, ctx);

  auto arg2 = eval(car(cdr(arguments)), ctx);
  long k = valueToInteger(arg2);

  auto arg3 = eval(car(cdr(cdr(arguments))), ctx);
  char c = valueToChar(arg3);

  updateValueString(value, k, c);
  return value;
}

Value stringFill(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  auto arg1 = car(arguments);
  string symbol = valueToSymbol(arg1);
  auto value = eval(arg1, ctx);
  char[] s = valueToString(value).dup;

  auto arg2 = eval(car(cdr(arguments)), ctx);
  char c = valueToChar(arg2);

  long start = 0, end = s.length;

  auto cddr = cdr(cdr(arguments));
  if (!valueIsNil(cddr)) {
    auto arg3 = eval(car(cddr), ctx);
    start = valueToInteger(arg3);

    auto cdddr = cdr(cddr);
    if (!valueIsNil(cdddr)) {
      auto arg4 = eval(car(cdddr), ctx);
      end = valueToInteger(arg4);
    }
  }

  for (long i = start; i < end; i++) {
    updateValueString(value, i, c);
  }

  ctx.set(symbol, value);

  return value;
}

Value vectorFun(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  Value[] vector;
  auto iterator = car(arguments);
  while (!valueIsNil(iterator)) {
    vector ~= eval(car(iterator), ctx);
    iterator = cdr(iterator);
  }

  auto f = makeVectorValue(vector);
  return f;
}

Value vectorSet(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  auto arg1 = car(arguments);
  string symbol = valueToSymbol(arg1);
  auto value = eval(arg1, ctx);

  auto arg2 = eval(car(cdr(arguments)), ctx);
  long index = valueToInteger(arg2);

  auto arg3 = eval(car(cdr(cdr(arguments))), ctx);

  updateValueVector(value, index, arg3);
  return value;
}

Value vectorFill(Value arguments, ...) {
  Context ctx = va_arg!Context(_argptr);

  auto arg1 = car(arguments);
  string symbol = valueToSymbol(arg1);
  auto value = eval(arg1, ctx);
  auto vector = valueToVector(value);

  auto arg2 = eval(car(cdr(arguments)), ctx);

  long start = 0, end = vector.length;

  auto cddr = cdr(cdr(arguments));
  if (!valueIsNil(cddr)) {
    auto arg3 = eval(car(cddr), ctx);
    start = valueToInteger(arg3);

    auto cdddr = cdr(cddr);
    if (!valueIsNil(cdddr)) {
      auto arg4 = eval(car(cdddr), ctx);
      end = valueToInteger(arg4);
    }
  }

  for (long i = start; i < end; i++) {
    updateValueVector(value, i, arg2);
  }

  return value;
}

class Context {
  Value[string] map;
  Value function(Value, ...)[string] builtins;
  Value function(Value, ...)[string] builtinSpecials;

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
