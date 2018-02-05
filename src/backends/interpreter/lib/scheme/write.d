import std.functional;

import common;
import value;

import runtime;

class SchemeWrite : Context {
  private this() {
    set("display", makeFunctionValue("display", toDelegate(&display), false));
    setSpecial("copy-context", makeCopyContext(null, this));
  }

  private static SchemeWrite instance;
  static SchemeWrite getContext() {
    if (instance is null) {
      instance = new SchemeWrite;
    }

    return instance;
  }
}
