import std.functional;

import common;

import runtime;

class SchemeWrite : Context {
  private this() {
    setSpecial("display", toDelegate(&display));
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
