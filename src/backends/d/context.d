import std.algorithm;
import std.format;

class Context {
  string[string] ctx;
  string[] specialForms;

  this(string[string] initCtx, string[] initSpecialForms) {
    ctx = initCtx;
    specialForms = initSpecialForms;
  }

  
  this() {
  }

  string set(string key, string value, bool requireUnique) {
    if (requireUnique) {
      long i = 0;
      while (key in this.ctx) {
        key = format("%s_%d", key, i);
        i++;
      }
    }

    this.ctx[key] = value;
    return key;
  }

  string set(string key, string value) {
    return this.set(key, value, true);
  }

  string get(string key) {
    return this.ctx[key];
  }

  void toggleSpecial(string key, bool special) {
    int index = this.specialForms.canFind(key) - 1;
    bool currentlySpecial = cast(bool)(index + 1);
    if (special && !currentlySpecial) {
      this.specialForms ~= key;
    } else if (!special && currentlySpecial) {
      this.specialForms.remove(index);
    }
  }

  Context dup() {
    auto d = new Context;
    d.ctx = this.ctx.dup();
    d.specialForms = this.specialForms;
    return d;
  }

  bool contains(string key) {
    return (key in this.ctx) !is null;
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
    ], []);
  }
}
