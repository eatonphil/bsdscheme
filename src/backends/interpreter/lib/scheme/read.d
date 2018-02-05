import std.functional;

import common;

import runtime;

class SchemeRead : Context {
  private this() {
    setSpecial("read", toDelegate(&_read));
    setSpecial("copy-context", makeCopyContext(null, this));
  }

  private static SchemeRead instance;
  static SchemeRead getContext() {
    if (instance is null) {
      instance = new SchemeRead;
    }

    return instance;
  }
}
