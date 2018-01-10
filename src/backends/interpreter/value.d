import std.math;
import std.string;
import std.typecons;

import ast;

// Lucky D can deal with this circular import.
// In future better to import context; and have
// bsdi.d initialize the context.
import runtime;

alias Value = AST;

Value zeroValue = makeIntegerAst(0);
Value nilValue = { data: 0, header: ASTTag.Nil };

alias FunctionTag = ASTTag.Unused1;

string formatValue(Value v) {
  switch (tagOfAst(v)) {
  case FunctionTag:
    return "#<procedure>";

  default:
    // TODO: support printing vector
    return formatAst(v);
  }
}

Value makeFunctionValue(string name, Value delegate(Value, Context) f, bool special) {
  void* namePtr = copyString(name)[0];
  Value v;
  v.header = FunctionTag;
  long* tuple = cast(long*)new long[3];
  tuple[0] = cast(long)namePtr;
  tuple[0] <<= HEADER_TAG_WIDTH;
  tuple[0] |= cast(int)special;
  tuple[1] = cast(long)f.ptr;
  tuple[2] = cast(long)f.funcptr;
  v.data = cast(long)tuple;
  return v;
}

bool valueIsFunction(ref Value v) { return isAst(v, FunctionTag); }

Tuple!(string, Value delegate(Value, Context), bool) valueToFunction(ref Value v) {
  Value delegate(Value, Context) f;
  long* tuple = cast(long*)v.data;
  bool special = cast(bool)(tuple[0] & (pow(2, HEADER_TAG_WIDTH) - 1));
  void* namePtr = cast(void*)(tuple[0] >> HEADER_TAG_WIDTH);
  string name = fromStringz(cast(char*)namePtr).dup;
  f.ptr = cast(void*)tuple[1];
  f.funcptr = cast(Value function(Value, Context))(tuple[2]);
  return Tuple!(string, Value delegate(Value, Context), bool)(name, f, special);
}
