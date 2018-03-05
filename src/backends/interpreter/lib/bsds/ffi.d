import core.sys.posix.dlfcn;
import std.algorithm.searching;
import std.format;
import std.functional;
import std.stdio;
import std.string;

import common;
import utility;
import value;

import runtime;

import base;
import eval : eval;

Value _dlopen(Value arguments, void** rest) {
  const char* lib = valueToString(car(arguments)).toStringz();
  auto libHandler = dlopen(lib, RTLD_LAZY);
  return makeIntegerValue(cast(long)libHandler);
}

static Value libcValue;
Value libc(Value arguments, void** rest) {
  if (valueIsNil(libcValue)) {
    libcValue = _dlopen(makeListValue(makeStringValue("/usr/lib/libc.dylib"), nilValue), null);
  }

  return libcValue;
}

T call(T)(void* libHandler, string symName, void*[] args, T _default) {
  void* fp = dlsym(libHandler, symName.toStringz());

  switch (args.length) {
  case 0:
    return (cast(T function())fp)();
  case 1:
    return (cast(T function(void*))fp)(args[0]);
  case 2:
    return (cast(T function(void*, void*))fp)(args[0], args[1]);
  case 3:
    return (cast(T function(void*, void*, void*))fp)(args[0], args[1], args[2]);
  case 4:
    return (cast(T function(void*, void*, void*, void*))fp)(args[0], args[1], args[2], args[3]);
  case 5:
    return (cast(T function(void*, void*, void*, void*, void*))fp)(args[0], args[1], args[2], args[3], args[4]);
  case 6:
    return (cast(T function(void*, void*, void*, void*, void*, void*))fp)(args[0], args[1], args[2], args[3], args[4], args[5]);
  default:
    error(format("%d FFI-call arguments is not yet supported", args.length), nilValue);
    return _default;
  }
}

Value delegate(void*[] args) makeCLambda(T)(Value paramList, Value callbackBody, void** rest) {
  Value[] params;
  string[] paramTypes;

  foreach(param; listToVector(paramList)) {
    auto paramType = "long";
    Value paramName;
    if (valueIsList(param)) {
      paramType = valueToString(car(param));
      paramName = car(cdr(param));
    } else {
      paramName = param;
    }

    paramTypes ~= paramType;
    params ~= paramName;
  }

  Value wrapper(void*[] args) {
    Context ctx = cast(Context)(*rest);
    auto paramList = vectorToList(params);
    auto f = namedLambda(makeListValue(paramList, callbackBody), ctx, "");

    Value[] vArgs;
    foreach (i, paramType; paramTypes) {
      switch (paramType) {
      case "int":
      case "long":
      case "void*":
        vArgs ~= makeIntegerValue(cast(long)args[i]);
        break;
      case "bool":
        vArgs ~= makeBoolValue(cast(bool)args[i]);
        break;
      case "char":
        vArgs ~= makeCharValue(cast(char)args[i]);
        break;
      case "string":
        // TODO: fix accept strings as callback args
        string arg = cast(string)(cast(char*)args[i]).fromStringz();
        vArgs ~= makeStringValue(arg);
        break;
      default:
        error(format("Unsupported arg type %s", paramType), nilValue);
      }
    }

    return valueToFunction(f)[1](vectorToList(vArgs), rest);
  }

  return &wrapper;
}

void* defineCallback(Value f, string returnType, void** rest) {
  auto callbackBody = valueToFunction(f);

  void* callback;
  switch (returnType) {
  case "void":
    auto f = makeCLambda!void(parameters, callbackBody, rest);
    extern(C) void voidCallback(void* args...) {
      f(args);
      return;
    }
    callback = &voidCallback;
    break;
  case "int":
  case "long":
  case "void*":
    auto f = makeCLambda!long(parameters, callbackBody, rest);
    extern(C) long longCallback(void* args...) {
      auto l = f(args);
      return valueToInteger(l);
    }
    callback = &longCallback;
    break;
  default:
    error(format("Unsupported return type %s", returnType), nilValue);
  }

  return callback;
}

/*
 * (define-foreign (name {libHandler | "/path/to/lib"} "symbol_name"))
 */
Value defineForeign(Value arguments, void** rest) {
  auto name = valueToString(car(arguments));

  auto arg2 = car(cdr(arguments));
  Value libHandlerV;
  if (valueIsString(arg2)) {
    libHandlerV = _dlopen(makeListValue(arg2, nilValue), null);
  } else {
    libHandlerV = car(arguments);
  }

  void* libHandler = cast(void*)valueToInteger(libHandlerV);

  auto symName = valueToString(car(cdr(arguments)));
  auto returnType = valueToString(car(cdr(cdr(arguments))));
  Context ctx = cast(Context)(*rest);

  void* valueToPrimitive(Value v) {
    switch (tagOfValue(v)) {
    case ValueTag.Integer:
      return cast(void*)valueToInteger(v);
    case ValueTag.Bool:
      return cast(void*)valueToBool(v);
    case ValueTag.Symbol:
      string s = valueToSymbol(v);

      // TODO: support "address of" transformation and syntax
      // if (s.startsWith("&")) {
      //   string symbol = s[1 .. (s.length - 1)];

      //   return cast(void*)&ctx.get(symbol);
      // }

      return cast(void*)s.toStringz();
    case ValueTag.Char:
      return cast(void*)valueToChar(v);
    case ValueTag.String:
      return cast(void*)valueToString(v).toStringz();
    case ValueTag.Nil:
      return null;
    case ValueTag.Function:
      auto returnType = "void";
      if (!valueIsNil(cdr(cdr(definition)))) {
        returnType = valueToString(car(cdr(cdr(definition))));
      }

      return defineCallback(v, ctx);
    default:
      // TODO: support BigInteger and Function
      error("Unable to pass arg to foreign function", v);
      return null;
    }
  }

  Value wrapper(Value arguments, void** rest) {
    void*[] args;
    foreach (arg; listToVector(car(arguments))) {
      args ~= valueToPrimitive(eval(arg, rest));
    }

    // TODO: handle error https://dlang.org/articles/dll-linux.html
    switch (returnType) {
    case "int":
    case "long":
    case "void*":
      long result = call!long(libHandler, symName, args, 0);
      return makeIntegerValue(result);
    case "char":
      char result = call!char(libHandler, symName, args, 0);
      return makeCharValue(result);
    case "bool":
      bool result = call!bool(libHandler, symName, args, 0);
      return makeBoolValue(result);
    case "void":
      call!long(libHandler, symName, args, 0);
      return nilValue;
    case "string":
      string result = call!string(libHandler, symName, args, "");
      return makeStringValue(result);
    default:
      error(format("Unsupported return type %s", returnType), nilValue);
      return nilValue;
    }
  }

  auto fun = makeFunctionValue(name, &wrapper, true);
  ctx.set(name, fun);
  return fun;
}

class BSDSFfi : Context {
  private this() {
    set("dlopen", makeFunctionValue("dlopen", toDelegate(&_dlopen), false));
    set("libc", makeFunctionValue("libc", toDelegate(&libc), false));
    set("define-foreign", makeFunctionValue("define-foreign", toDelegate(&defineForeign), false));
    setSpecial("copy-context", makeCopyContext(null, this));
  }

  private static BSDSFfi instance;
  static BSDSFfi getContext() {
    if (instance is null) {
      instance = new BSDSFfi;
    }

    return instance;
  }
}
