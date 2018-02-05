import std.format;
import std.functional;
import std.stdio;

import common;
import utility;
import value;

import runtime;

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

class BSDSDbg : Context {
  private this() {
    set("callstack", makeFunctionValue("callstack", toDelegate(&callstack), false));
    setSpecial("copy-context", makeCopyContext(null, this));
  }

  private static BSDSDbg instance;
  static BSDSDbg getContext() {
    if (instance is null) {
      instance = new BSDSDbg;
    }

    return instance;
  }
}
