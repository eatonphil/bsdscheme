import core.stdc.stdlib;
import core.vararg;
import std.algorithm;
import std.algorithm.mutation;
import std.bigint;
import std.conv;
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

import dbg;

import base;
import read;
import write;
import eval : eval, SchemeEval;

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

string specsToString(Value arguments) {
  string[] specs;

  foreach (spec; listToVector(arguments)) {
    if (valueIsList(spec)) {
      specs ~= specsToString(spec);
    } else {
      specs ~= valueToSymbol(spec);
    }
  }

  return specs.join(".");
}

Value delegate(Value, void**) makeCopyContext(string[] exports, Context libraryCtx) {
  // TODO: support renaming
  Value copyContext(Value arguments, void** rest) {
    Context ctx = cast(Context)(*rest);

    if (exports is null) {
      foreach (key, value; libraryCtx.map) {
        ctx.set(key, value);
      }
    } else {
      foreach (symbol; exports) {
        ctx.set(symbol, libraryCtx.get(symbol));
      }
    }

    return nilValue;
  }

  return &copyContext;
}

Value defineLibrary(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
  Context libraryCtx = new Context;

  auto arg1 = car(arguments);
  string library = specsToString(arg1);

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

  libraryCtx.setSpecial("copy-context", makeCopyContext(exports, libraryCtx));

  ctx.modules[library] = libraryCtx.dup;
  ctx.modules[library].map.remove("export");

  return nilValue;
}

Value _import(Value arguments, void** rest) {
  Context ctx = cast(Context)(*rest);
  string path = valueToString(ctx.get("*library-include-path*"));
  foreach (spec; listToVector(arguments)) {
    Context loadCtx = new Context;
    string lib = valueIsList(spec) ? specsToString(spec) : valueToSymbol(spec);
    if (ctx.getModule(lib) !is null) {
      loadCtx = ctx.modules[lib];
    } else {
      auto fileValue = makeStringValue(format("%s/%s.scm",
                                              path,
                                              lib.replace(".", "/")));

      // Compile the file.
      include(makeListValue(fileValue, nilValue), cast(void**)[loadCtx]);
      // Cache the module
      loadCtx = loadCtx.modules[lib];
      ctx.modules[lib] = loadCtx;
    }

    // Copy the exported symbols into the current context.
    auto fn = valueToFunction(loadCtx.get("copy-context"));
    fn[1](nilValue, cast(void**)[ctx]);
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

class Context {
  Buffer!(Tuple!(string, Delegate)) callingContext;
  Delegate doTailCall;
  Value[string] map;
  Context[string] modules;

  this() {
    set("*library-include-path*", makeStringValue("src/lib"));
    setSpecial("begin", toDelegate(&begin));
    setSpecial("import", toDelegate(&_import));
    setSpecial("define-library", toDelegate(&defineLibrary));

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

  Context getModule(string name) {
    modules = [
      "scheme.base": SchemeBase.getContext(),
      "scheme.read": SchemeRead.getContext(),
      "scheme.write": SchemeWrite.getContext(),
      "scheme.eval": SchemeEval.getContext(),
      "bsds.dbg": BSDSDbg.getContext(),
    ];

    if (name in modules) {
      return modules[name];
    }

    return null;
  }
}
