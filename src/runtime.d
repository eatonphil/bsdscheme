import std.conv;
import std.format;
import std.functional;
import std.stdio;

import lex;
import parse;
import value;
import interpret : interpret;

Value[] sexpsToValues(Value delegate(SExp*[], Context) f, SExp*[] arguments, Context ctx) {
  Value[] result;
  result.length = arguments.length;

  foreach (i, arg; arguments) {
    result[i] = f([arg], ctx);
  }

  return result;
}

Value sexpsToValue(Value delegate(Value, Value) f, SExp*[] arguments, Context ctx, ref Value initial) {
  Value result = initial;

  foreach (arg; arguments) {
    result = f(result, interpret(arg, ctx));
  }

  return result;
}

Value plus(SExp*[] arguments, Context ctx) {
  Value _plus(Value previous, Value current) {
    long sum = valueToInteger(previous) + valueToInteger(current);
    return makeIntegerValue(sum);
  }
  return sexpsToValue(&_plus, arguments, ctx, zeroValue);
}

Value times(SExp*[] arguments, Context ctx) {
  Value _times(Value previous, Value current) {
    long product = valueToInteger(previous) * valueToInteger(current);
    return makeIntegerValue(product);
  }
  auto initial = interpret(arguments[0], ctx);
  auto rest = arguments[1 .. arguments.length];
  return sexpsToValue(&_times, rest, ctx, initial);
}

Value minus(SExp*[] arguments, Context ctx) {
  Value _minus(Value previous, Value current) {
    long difference = valueToInteger(previous) - valueToInteger(current);
    return makeIntegerValue(difference);
  }
  auto initial = interpret(arguments[0], ctx);
  auto rest = arguments[1 .. arguments.length];
  return sexpsToValue(&_minus, rest, ctx, initial);
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
    b = valueIsFunction(right) && valueToFunction(left) == valueToFunction(right);
    break;
  case ValueTag.Bool:
    b = valueIsBool(right) && valueToBool(left) == valueToBool(right);
    break;
  default:
    b = false;
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

string stringOfValue(ref Value v) {
  switch (tagOfValue(v)) {
  case ValueTag.Integer:
    return format("%d", valueToInteger(v));
  case ValueTag.Bool:
    return valueToBool(v) ? "#t" : "#f";
  case ValueTag.Symbol:
    return valueToSymbol(v);
  case ValueTag.String:
    return valueToString(v);
  case ValueTag.Nil:
    return "'()";
  case ValueTag.List:
    auto list = valueToList(v);
    return format("(%s . %s)", stringOfValue(list[0]), stringOfValue(list[1]));
  case ValueTag.Function:
    return format("Function(%s)", v);
  default:
    // TODO: support printing vector
    return format("unknown value (%s)", v);
  }
}

Value display(SExp*[] arguments, Context ctx) {
  auto value = interpret(arguments[0], ctx);
  write(stringOfValue(value));
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

Value atomToValue(Atom* atom) {
  if (atom is null) {
    return nilValue;
  }

  Value v;
  string sValue = atom.value;
  switch (atom.schemeType) {
  case SchemeType.Integer:
    v = makeIntegerValue(to!int(sValue));
    break;
  case SchemeType.String:
    v = makeStringValue(sValue);
    break;
  case SchemeType.Symbol:
    v = makeSymbolValue(sValue);
    break;
  case SchemeType.Bool:
    v = makeBoolValue(sValue == "#t");
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
    auto head = quote([argument], ctx);
    value = makeListValue(head, value);
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
  return valueToList(list)[0];
}

Value cdr(SExp*[] arguments, Context ctx) {
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
      "cdr": &cdr,
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
