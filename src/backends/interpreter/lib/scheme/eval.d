import std.functional;

import common;
import utility;
import value;

import runtime;

Value eval(Value value, void** rest, bool tailCallPosition) {
  Context ctx = cast(Context)(*rest);

  switch (tagOfValue(value)) {
  case ValueTag.Symbol:
    return ctx.get(valueToSymbol(value));
    break;
  case ValueTag.List:
    auto v = valueToList(value);

    auto car = eval(v[0], rest);
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
      args = mapValues(toDelegate(&eval), args, rest);
    }

    if (tailCallPosition) {
      auto cc = ctx.callingContext;
      for (int i = 0; i < cc.index; i++) {
        auto callStackDelegate = cc.buffer[i][1];
        if (callStackDelegate == fnDelegate) {
          ctx.doTailCall = fnDelegate;
          return args;
        }
      }
    }

    return fnDelegate(args, rest);
    break;
  default:
    return value;
    break;
  }
}

Value eval(Value arguments, void** rest) {
  return eval(arguments, rest, false);
}

Value _eval(Value arguments, void** rest) {
  return eval(eval(car(arguments), rest), rest);
}

class SchemeEval : Context {
  private this() {
    setSpecial("eval", toDelegate(&_eval));
    setSpecial("copy-context", makeCopyContext(null, this));
  }

  private static SchemeEval instance;
  static SchemeEval getContext() {
    if (instance is null) {
      instance = new SchemeEval;
    }

    return instance;
  }
}
