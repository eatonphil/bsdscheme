import core.stdc.stdlib;
import std.bigint;
import std.file : read;
import std.format;
import std.functional;
import std.stdio;

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
  auto tuple = astToList(arguments);
  auto funArguments = tuple[0];
  auto funBody = astToList(tuple[1])[0];

  Value defined(Value parameters, Context ctx) {
    Context newCtx = ctx.dup();

    auto keyTmp = astToList(funArguments);
    auto valueTmp = astToList(parameters);
    while (true) {
      auto key = astToSymbol(keyTmp[0]);
      auto value = eval(valueTmp[0], ctx);

      newCtx.set(key, value);

      // TODO: handle arg count mismatch
      if (astIsList(keyTmp[1])) {
        keyTmp = astToList(keyTmp[1]);
        valueTmp = astToList(valueTmp[1]);
      } else {
        break;
      }
    }

    return eval(funBody, newCtx);
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

Value car(Value arguments) {
  return astToList(arguments)[0];
}

Value _car(Value arguments, Context ctx) {
  return car(car(arguments));
}

Value cdr(Value arguments, Context ctx) {
  return astToList(car(arguments))[1];
}

Value begin(Value arguments, Context ctx) {
  // TODO: rewrite using reduce.
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
      "cdr": &cdr,
      "begin": &begin,
      "display": &display,
      "newline": &newline,
      "read": &_read,
      "include": &include,
    ];

    this.builtinSpecials = [
      "if": &ifFun,
      "let": &let,
      "define": &define,
      "lambda": &lambda,
      "set!": &setFun,
      "eval": &_eval,
      "quote": &quote,
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
