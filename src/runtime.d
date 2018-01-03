import std.bigint;
import std.conv;
import std.format;
import std.functional;
import std.stdio : write;
import std.typecons;

import lex;
import parse;
import value;
import utility;

Value reduceValues(Value delegate(Value, Value) f, Value arguments, Context ctx, ref Value initial) {
  Value result = initial;
  auto tmp = arguments;

  while (valueIsList(tmp)) {
    auto tuple = valueToList(tmp);
    result = f(result, tuple[0]);
    tmp = tuple[1];
  }

  return result;
}

Value mapValues(Value delegate(Value, Context) f, Value arguments, Context ctx) {
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

Value plus(Value arguments, Context ctx) {
  Value _plus(Value previous, Value current) {
    if (valueIsBigInteger(previous) || valueIsBigInteger(current)) {
      BigInt a, b;

      if (valueIsBigInteger(previous)) {
        a = valueToBigInteger(previous);
      } else {
        a = BigInt(valueToInteger(previous));
      }

      if (valueIsBigInteger(current)) {
        b = valueToBigInteger(current);
      } else {
        b = BigInt(valueToInteger(current));
      }

      return makeBigIntegerValue(a + b);
    }

    long a = valueToInteger(previous);
    long b = valueToInteger(current);

    if (b > 0 && a > long.max - b ||
        b < 0 && a < long.max - b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerValue(bA + bB);
    }

    return makeIntegerValue(a + b);
  }

  return reduceValues(&_plus, arguments, ctx, zeroValue);
}

Value times(Value arguments, Context ctx) {
  Value _times(Value previous, Value current) {
    if (valueIsBigInteger(previous) || valueIsBigInteger(current)) {
      BigInt a, b;

      if (valueIsBigInteger(previous)) {
        a = valueToBigInteger(previous);
      } else {
        a = BigInt(valueToInteger(previous));
      }

      if (valueIsBigInteger(current)) {
        b = valueToBigInteger(current);
      } else {
        b = BigInt(valueToInteger(current));
      }

      return makeBigIntegerValue(a * b);
    }

    long a = valueToInteger(previous);
    long b = valueToInteger(current);

    if (a > long.max / b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerValue(bA * bB);
    }

    return makeIntegerValue(a * b);
  }

  auto tuple = valueToList(arguments);
  return reduceValues(&_times, tuple[1], ctx, tuple[0]);
}

// TODO: unify plus and minus
Value minus(Value arguments, Context ctx) {
  Value _minus(Value previous, Value current) {
    if (valueIsBigInteger(previous) || valueIsBigInteger(current)) {
      BigInt a, b;

      if (valueIsBigInteger(previous)) {
        a = valueToBigInteger(previous);
      } else {
        a = BigInt(valueToInteger(previous));
      }

      if (valueIsBigInteger(current)) {
        b = valueToBigInteger(current);
      } else {
        b = BigInt(valueToInteger(current));
      }

      return makeBigIntegerValue(a - b);
    }

    long a = valueToInteger(previous);
    long b = valueToInteger(current);

    if (b > 0 && a > long.max - b ||
        b < 0 && a < long.max - b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerValue(bA - bB);
    }

    return makeIntegerValue(a - b);
  }

  auto tuple = valueToList(arguments);
  return reduceValues(&_minus, tuple[1], ctx, tuple[0]);
}

Value let(Value arguments, Context ctx) {
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
  auto tuple = valueToList(arguments);
  auto funArguments = tuple[0];
  auto funBody = valueToList(tuple[1])[0];

  Value defined(Value parameters, Context ctx) {
    Context newCtx = ctx.dup();

    auto keyTmp = valueToList(funArguments);
    auto valueTmp = valueToList(parameters);
    while (true) {
      auto key = valueToSymbol(keyTmp[0]);
      auto value = eval(valueTmp[0], ctx);

      newCtx.set(key, value);

      // TODO: handle arg count mismatch
      if (valueIsList(keyTmp[1])) {
        keyTmp = valueToList(keyTmp[1]);
        valueTmp = valueToList(valueTmp[1]);
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

Value equals(Value arguments, Context ctx) {
  auto tuple = valueToList(arguments);
  auto left = tuple[0];
  auto right = car(tuple[1]);

  bool b;

  switch (tagOfValue(left)) {
  case ValueTag.Integer:
    b = valueIsInteger(right) && valueToInteger(left) == valueToInteger(right);
    break;
  case ValueTag.String:
    b = valueIsString(right) && valueToString(left) == valueToString(right);
    break;
  case ValueTag.Symbol:
    b = valueIsSymbol(right) && valueToSymbol(left) == valueToSymbol(right);
    break;
  case ValueTag.Function:
    b = valueIsFunction(right) && valueToFunction(left)[1] == valueToFunction(right)[1];
    break;
  case ValueTag.Bool:
    b = valueIsBool(right) && valueToBool(left) == valueToBool(right);
    break;
  default:
    b = false;
  }

  return makeBoolValue(b);
}

Value ifFun(Value arguments, Context ctx) {
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

  return eval(car(tuple[1]), ctx);
 }

string stringOfValue(ref Value v) {
  switch (tagOfValue(v)) {
  case ValueTag.Integer:
    return to!(string)(valueToInteger(v));
  case ValueTag.Bool:
    return valueToBool(v) ? "#t" : "#f";
  case ValueTag.Symbol:
    return valueToSymbol(v);
  case ValueTag.String:
    return valueToString(v);
  case ValueTag.Nil:
    return "()";
  case ValueTag.List:
    auto fmt = "(";
    auto tuple = valueToList(v);

    while (true) {
      fmt = format("%s%s", fmt, stringOfValue(tuple[0]));

      if (valueIsList(tuple[1])) {
        tuple = valueToList(tuple[1]);
        fmt = format("%s ", fmt);
      } else if (valueIsNil(tuple[1])) {
        break;
      } else {
        fmt = format("%s . %s", fmt, stringOfValue(tuple[1]));
        break;
      }
    }

    return format("%s)", fmt);
    break;
  case ValueTag.Function:
    return "#<procedure>";
  case ValueTag.BigInteger:
    return valueToBigInteger(v).toDecimalString();
  default:
    // TODO: support printing vector
    return format("#<%d>", tagOfValue(v));
  }
}

Value display(Value arguments, Context ctx) {
  Value head = car(arguments);
  write(stringOfValue(head));
  return nilValue;
}

Value newline(Value arguments, Context ctx) {
  write("\n");
  return nilValue;
}

Value setFun(Value arguments, Context ctx) {
  auto tuple = valueToList(arguments);
  auto name = valueToSymbol(tuple[0]);
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
  return valueToList(arguments)[0];
}

Value _car(Value arguments, Context ctx) {
  return car(car(arguments));
}

Value cdr(Value arguments, Context ctx) {
  return valueToList(car(arguments))[1];
}

Value begin(Value arguments, Context ctx) {
  // TODO: rewrite using reduce.
  Value result = arguments;
  auto tmp = valueToList(arguments);

  while (true) {
    result = tmp[0];

    if (valueIsList(tmp[1])) {
      tmp = valueToList(tmp[1]);
    } else {
      break;
    }
  }

  return result;
}

Value eval(Value value, Context ctx) {
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

Value _eval(Value arguments, Context ctx) {
  return eval(eval(car(arguments), ctx), ctx);
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
