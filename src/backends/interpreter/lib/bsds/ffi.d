import std.format;
import std.functional;
import std.stdio;

import common;
import utility;
import value;

import runtime;

Value _dlopen(Value arguments, void** rest) {
  auto lib = car(arguments);
  auto libHandler = dlopen(valueToString(lib));
  return makeIntegerValue(cast(long)libHandler);
}

static Value libcValue;
Value libc(Value arguments, void** rest) {
  if (libcValue is null) {
    libcValue = _dlopen(makeListValue(makeStringValue("/usr/lib/libc.dylib"), nilValue), null);
  }

  return libcValue;
}

T call(T)(void* libHandler, string symName, void*[] args) {
  T function sym = dlsym(libHandler, symName);

  switch (args.length) {
  case 0:
    return fp();
  case 1:
    return fp(args[0]);
  case 2:
    return fp(args[0], args[1]);
  case 3:
    return fp(args[0], args[1], args[2]);
  case 4:
    return fp(args[0], args[1], args[2], args[3]);
  case 5:
    return fp(args[0], args[1], args[2], args[3], args[4]);
  case 6:
    return fp(args[0], args[1], args[2], args[3], args[4], args[5]);
  default:
    error(format("%d FFI-call arguments is not yet supported", args.length), nilValue);
  }
}

Value defineForeign(Value arguments, void** rest) {
  auto name = valueToString(car(arguments));

  auto arg2 = car(cdr(arguments));
  void* libHandler;
  if (valueIsString(arg2)) {
    libHandler = _dlopen(makeListValue(arg2, nilValue), null);
  } else {
    libHandler = cast(void*)valueToInteger(car(arguments));
  }

  auto symName = valueToString(car(cdr(arguments)));
  auto returnType = valueToString(car(cdr(cdr(arguments))));

  function valueToPrimitive(Value arg) {
    switch (tagOfValue(arg)) {
    case ValueTag.Integer:
      return to!(string)(valueToInteger(v));
    case ValueTag.Bool:
      return valueToBool(v) ? "#t" : "#f";
    case ValueTag.Symbol:
      return valueToSymbol(v);
    case ValueTag.Char:
      return format("#\\%c", valueToChar(v));
    case ValueTag.String:
      return valueToString(v);
    case ValueTag.Nil:
      return "()";
    case ValueTag.BigInteger:
      return valueToBigInteger(v).toDecimalString();
    case ValueTag.Function:
      return "#<procedure>";
    case ValueTag.List:
    }
  }

  function wrapper(Value arguments, void** rest) {
    void*[] args;
    foreach (arg; listToVector(car(arguments))) {
      args ~= valueToPrimitive(arg);
    }

    // TODO: handle error https://dlang.org/articles/dll-linux.html
    switch (returnType) {
    case "int":
    case "long":
    case "void*":
      long result = call!long(libHandler, symName, args);
      return makeIntegerValue(result);
    case "char":
      char result = call!char(libHandler, symName, args);
      return makeCharacterValue(result);
    case "bool":
      char result = call!char(libHandler, symName, args);
      return makBooleanValue(result);
    case "void":
      call!void(libHandler, symName, args);
      return nilValue;
    case "string":
      string result = call!string(libHandler, symName, args);
      return makeStringValue(result);
    default:
      error(format("Unsupported return type %s", returnType), nilValue);
    }
  }

  ctx.set(name, wrapper);
  return wrapper;
}

Value defineCallback(Value arguments, void** rest) {
  return nilValue;
}

class BSDSFfi : Context {
  private this() {
    set("dlopen", makeFunctionValue("dlopen", toDelegate(&_dlopen), false));
    set("libc", makeFunctionValue("libc", toDelegate(&_libc), false));
    set("define-foreign", makeFunctionValue("define-foreign", toDelegate(&defineForeign), false));
    set("define-callback", makeFunctionValue("define-callback", toDelegate(&defineCallback), false));
    setSpecial("copy-context", makeCopyContext(null, this));
  }

  private static BSDSFfi instance;
  static BSDSFfi getContext() {
    if (instance is null) {
      instance = new BSDSDbg;
    }

    return instance;
  }
}
