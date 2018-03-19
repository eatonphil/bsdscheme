import std.algorithm;
import std.format;
import std.stdio;

class Context {
  string[string] ctx;
  bool[string] tmps;

  this(string[string] initCtx) {
    ctx = initCtx;
  }

  this() {}

  string set(string key, string value, bool requireUnique) {
    if (requireUnique) {
      long i = 0;
      while (key in ctx) {
        key = format("%s_%d", key, i++);
      }
    }

    ctx[key] = value;
    return key;
  }

  string set(string key, string value) {
    return set(key, value, true);
  }

  string get(string key) {
    return ctx[key];
  }

  string setTmp(string key) {
    long i = 0;
    while ((key in tmps) !is null || contains(key)) {
      key = format("%s_%d", key, i++);
    }

    tmps[key] = true;
    return key;
  }

  Context dup() {
    auto d = new Context;
    d.ctx = ctx.dup();
    d.tmps = tmps;
    return d;
  }

  bool contains(string key) {
    return (key in ctx) !is null;
  }

  static Context getDefault() {
    return new Context([
      "+": "plus",
      "-": "minus",
      "*": "times",
      "=": "equals",
      "cons": "cons",
      "car": "_car",
      "cdr": "_cdr",
      "display": "display",
      "newline": "newline",
      "read": "_read",
      "string?": "stringP",
      "make-string": "makeString",
      "string": "stringFun",
      "string-length": "stringLength",
      "string-ref": "stringRef",
      "string=?": "stringEquals",
      "string-append": "stringAppend",
      "list->string": "listToString",
      "string-upcase": "stringUpcase",
      "string-downcase": "stringDowncase",
      "substring": "substring",
      "string->list": "stringToList",
      "vector-length": "vectorLength",
      "vector-ref": "vectorRef",
      "vector?": "vectorP",
      "vector->string": "vectorToString",
      "string->vector": "stringToVector",
      "vector->list": "_vectorToList",
      "list->vector": "_listToVector",
      "vector-append": "vectorAppend",
      "make-vector": "makeVector",
    ]);
  }
}
