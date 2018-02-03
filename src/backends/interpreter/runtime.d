import core.stdc.stdlib;
import core.vararg;
import std.algorithm;
import std.bigint;
import std.conv;
import std.file : read;
import std.format;
import std.functional;
import std.stdio;
import std.string;
import std.typecons;
import std.uni;

import common;
import value;
import parse;
import utility;
import buffer;

alias Delegate = Value delegate(Value, void**);
alias Function = Value function(Value, void**);

Value mapValues(Value delegate(Value, void**, bool) f, Value arguments, void** rest) {
  Value mapped;

  auto iterator = arguments;
  while (valueIsList(iterator)) {
    Value mappedElement = f(car(iterator), rest, false);
    mapped = appendList(mapped, makeListValue(mappedElement, nilValue));
    iterator = cdr(iterator);
  }

  return mapped;
}

Value ifFun(Value arguments, void** rest) {
  auto test = eval(car(arguments), rest);
  auto ok = truthy(test);

  auto ifBody = cdr(arguments);

  if (ok) {
    return eval(car(ifBody), rest, true);
  }

  auto ifElse = cdr(ifBody);
  if (valueIsNil(ifElse)) {
    return nilValue;
  }

  return eval(car(ifElse), rest, true);
}

Value letVariant(Value arguments, void** rest, bool star, bool rec) {
  Context ctx = cast(Context)(*rest);

  auto bindings = car(arguments);
  auto letBody = cdr(arguments);

  Context newCtx = ctx.dup;

  auto iterator = bindings;
  while (valueIsList(iterator)) {
    auto arg = car(iterator);
    string key = valueToSymbol(car(arg));

    Context valueCtx = ctx.dup;
    if (star) {
      valueCtx = newCtx.dup;
    }

    // TODO: handle rec and recstar

    Value value = eval(car(cdr(arg)), cast(void**)[valueCtx]);
    newCtx.set(key, value);

    iterator = cdr(iterator);
  }

  return eval(withBegin(letBody), cast(void**)[newCtx]);
}

Value let(Value arguments, void** rest) {
  return letVariant(arguments, rest, false, false);
}

Value letStar(Value arguments, void** rest) {
  return letVariant(arguments, rest, true, false);
}

Value letRec(Value arguments, void** rest) {
  return letVariant(arguments, rest, false, true);
}

Value letRecStar(Value arguments, void** rest) {
  return letVariant(arguments, rest, true, true);
}

Value namedLambda(Value arguments, Context ctx, string name) {
  auto funArguments = car(arguments);
  auto funBody = cdr(arguments);

  Value defined(Value parameters, void** rest) {
    Context newCtx = ctx.dup;

    // Copy the runtime calling context to the new context.
    Context runtimeCtx = cast(Context)(*rest);
    auto runtimeCallingContext = runtimeCtx.callingContext;
    newCtx.callingContext = runtimeCallingContext.dup;

    Value result;
    bool tailCalling = false;
    while (true) {
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
      } else if (!valueIsNil(funArguments)) {
        error("Expected symbol or list in lambda formals", funArguments);
      }

      if (!tailCalling) {
        newCtx.callingContext.push(Tuple!(string, Delegate)(name, &defined));
      }

      result = eval(withBegin(funBody), cast(void**)[newCtx]);

      if (newCtx.doTailCall == &defined) {
        tailCalling = true;
        parameters = result;
        newCtx.doTailCall = null;
      } else {
        break;
      }
    }

    return result;
  }

  return makeFunctionValue(name, &defined, false);
}

Value lambda(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
  return namedLambda(arguments, ctx, "lambda");
}

Value define(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
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
      value = eval(valueToList(tuple[1])[0], cast(void**)[ctx]);
    }
  }

  ctx.set(name, value);
  return value;
}

Value setFun(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
  auto tuple = valueToList(arguments);
  auto name = valueToSymbol(tuple[0]);
  auto value = eval(car(tuple[1]), cast(void**)[ctx]);
  ctx.set(name, value);
  return value;
}

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

Value load(Value arguments, void** rest) {
  Value arg1 = car(arguments);
  string includeFile = valueToString(arg1);
  string fileContents = (cast(char[])read(includeFile)).dup;
  Value source = makeStringValue(fileContents);
  Value readArgs = makeListValue(source, nilValue);
  Value parsed = _read(readArgs, rest);
  return eval(parsed, rest);
}

Value stringSet(Value arguments, void** rest) {
  auto arg1 = car(arguments);
  auto symbol = valueToSymbol(arg1);
  auto value = eval(arg1, rest);

  auto arg2 = eval(car(cdr(arguments)), rest);
  long k = valueToInteger(arg2);

  auto arg3 = eval(car(cdr(cdr(arguments))), rest);
  char c = valueToChar(arg3);

  updateValueString(value, k, c);
  return value;
}

Value stringFill(Value arguments, void** rest) {
  auto arg1 = car(arguments);
  string symbol = valueToSymbol(arg1);
  auto value = eval(arg1, rest);
  char[] s = valueToString(value).dup;

  auto arg2 = eval(car(cdr(arguments)), rest);
  char c = valueToChar(arg2);

  long start = 0, end = s.length;

  auto cddr = cdr(cdr(arguments));
  if (!valueIsNil(cddr)) {
    auto arg3 = eval(car(cddr), rest);
    start = valueToInteger(arg3);

    auto cdddr = cdr(cddr);
    if (!valueIsNil(cdddr)) {
      auto arg4 = eval(car(cdddr), rest);
      end = valueToInteger(arg4);
    }
  }

  for (long i = start; i < end; i++) {
    updateValueString(value, i, c);
  }

  return value;
}

Value vectorFun(Value arguments, void** rest) {
  Value[] vector;
  auto iterator = car(arguments);
  while (!valueIsNil(iterator)) {
    vector ~= eval(car(iterator), rest);
    iterator = cdr(iterator);
  }

  auto f = makeVectorValue(vector);
  return f;
}

Value vectorSet(Value arguments, void** rest) {
  auto arg1 = car(arguments);
  string symbol = valueToSymbol(arg1);
  auto value = eval(arg1, rest);

  auto arg2 = eval(car(cdr(arguments)), rest);
  long index = valueToInteger(arg2);

  auto arg3 = eval(car(cdr(cdr(arguments))), rest);

  updateValueVector(value, index, arg3);
  return value;
}

Value vectorFill(Value arguments, void** rest) {
  auto arg1 = car(arguments);
  string symbol = valueToSymbol(arg1);
  auto value = eval(arg1, rest);
  auto vector = valueToVector(value);

  auto arg2 = eval(car(cdr(arguments)), rest);

  long start = 0, end = vector.length;

  auto cddr = cdr(cdr(arguments));
  if (!valueIsNil(cddr)) {
    auto arg3 = eval(car(cddr), rest);
    start = valueToInteger(arg3);

    auto cdddr = cdr(cddr);
    if (!valueIsNil(cdddr)) {
      auto arg4 = eval(car(cdddr), rest);
      end = valueToInteger(arg4);
    }
  }

  for (long i = start; i < end; i++) {
    updateValueVector(value, i, arg2);
  }

  return value;
}

Value callstack(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);

  for (int i = 0; i < ctx.callingContext.index; i++) {
    string indent = "";
    for (int j = 0; j < i; j++) {
      indent ~= "  ";
    }
    writeln(format("%s%s", indent, ctx.callingContext.buffer[i][0]));
  }
  return nilValue;
}

Value begin(Value arguments, void** rest) {
  Value result = arguments;

  auto iterator = arguments;
  while (!valueIsNil(iterator)) {
    auto exp = car(iterator);
    bool tcoPosition = valueIsNil(cdr(iterator));
    result = eval(exp, rest, tcoPosition);
    iterator = cdr(iterator);
  }

  return result;
}

string[] specsToString(Value arguments) {
  string[] specs;

  foreach (spec; listToVector(arguments)) {
    if (valueIsList(spec)) {
      specs ~= specsToString(spec).join(".");
    } else {
      specs ~= valueToSymbol(spec);
    }
  }

  return specs;
}

Value defineLibrary(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
  // TODO: stop dup-ing when no builtins are imported by default
  Context libraryCtx = ctx.dup;

  auto arg1 = car(arguments);
  string library = specsToString(arg1).join(".");

  string[] exports;
  Value _export(Value arguments, void** rest) {
    foreach (arg; listToVector(arguments)) {
      exports ~= valueToSymbol(arg);
    }
    return nilValue;
  }

  libraryCtx.setSpecial("export", &_export);

  foreach (exp; listToVector(cdr(arguments))) {
    eval(exp, cast(void**)[libraryCtx]);
  }

  // TODO: support renaming
  Value _import(Value arguments, void** rest) {
    Context ctx = cast(Context)(*rest);

    foreach (symbol; exports) {
      ctx.set(symbol, libraryCtx.get(symbol));
    }

    return nilValue;
  }

  libraryCtx.setSpecial("import", &_import);

  ctx.modules[library] = libraryCtx.dup;
  ctx.modules[library].map.remove("export");

  return nilValue;
}

Value _import(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
  string include = valueToString(ctx.get("#library-include-path#"));
  foreach (spec; listToVector(arguments)) {
    Context loadCtx = new Context;
    string lib = valueIsList(spec) ? specsToString(spec)[0] : valueToSymbol(spec);
    if (lib in ctx.modules) {
      loadCtx = ctx.modules[lib];
    } else {
      auto filename = makeStringValue(format("%s/%s.scm", include, lib.replace(".", "/")));

      // Compile the file.
      load(makeListValue(filename, nilValue), cast(void**)[loadCtx]);
      // Cache the module
      loadCtx = loadCtx.modules[lib];
      ctx.modules[lib] = loadCtx;
    }

    // Copy the exported symbols into the current context.
    auto fn = valueToFunction(loadCtx.get("import"));
    fn[1](nilValue, cast(void**)[ctx]);
  }

  return nilValue;
}

class Context {
  Buffer!(Tuple!(string, Delegate)) callingContext;
  Delegate doTailCall;
  Value[string] map;
  Context[string] modules;

  this() {
    map = [
      "#library-include-path#": makeStringValue("src/lib"),
    ];

    auto builtins = [
      "+": &plus,
      "-": &minus,
      "*": &times,
      "=": &equals,
      "cons": &cons,
      "car": &_car,
      "cdr": &_cdr,
      "display": &display,
      "newline": &newline,
      "read": &_read,
      "load": &load,
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
      "callstack": &callstack,
    ];

    foreach (key, value; builtins) {
      set(key, makeFunctionValue(key, toDelegate(value), false));
    }

    auto builtinSpecials = [
      "begin": &begin,
      "if": &ifFun,
      "let": &let,
      "let*": &letStar,
      //"letrec": &letRec,
      //"letrec*": &letRecStar,
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
      "import": &_import,
      "define-library": &defineLibrary,
    ];

    foreach (key, value; builtinSpecials) {
      setSpecial(key, toDelegate(value));
    }

    callingContext = new Buffer!(Tuple!(string, Delegate))();
  }

  Context dup() {
    auto dup = new Context();
    dup.map = map.dup;
    dup.modules = modules.dup;
    dup.callingContext = callingContext.dup;
    return dup;
  }

  void set(string key, Value value) {
    this.map[key] = value;
  }

  void setSpecial(string key, Value delegate(Value, void**) value) {
    this.map[key] = makeFunctionValue(key, value, true);
  }

  Value get(string key, bool failIfNotFound) {
    if (key in map) {
      return map[key];
    } else if (failIfNotFound) {
      error("Undefined symbol", makeSymbolValue(key));
    }

    return nilValue;
  }

  Value get(string key) {
    return get(key, true);
  }
}
