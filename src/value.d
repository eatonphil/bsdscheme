import std.bigint;
import std.conv;
import std.math;
import std.string;
import std.typecons;
import std.stdio;

static const long WORD_SIZE = 64;
static const int HEADER_TAG_WIDTH = 8;

enum ValueTag {
  Nil,
  Integer,
  Char,
  Bool,
  BigInteger,
  String,
  Symbol,
  List,
  Vector,
  Function,
}

struct Value {
  long header;
  long data;
}

string formatValue(Value v) {
  switch (tagOfValue(v)) {
  case ValueTag.Integer:
    return to!(string)(valueToInteger(v));
  case ValueTag.Bool:
    return valueToBool(v) ? "#t" : "#f";
  case ValueTag.Symbol:
    return valueToSymbol(v);
  case ValueTag.Char:
    return format("#\\%c", valueToChar(v));
  case ValueTag.String:
    return valueToString(v);
  case ValueTag.Nil:
    return "()";
  case ValueTag.BigInteger:
    return valueToBigInteger(v).toDecimalString();
  case ValueTag.Function:
    return "#<procedure>";
  case ValueTag.List:
    auto fmt = "(";
    auto tuple = valueToList(v);

    while (true) {
      fmt = format("%s%s", fmt, formatValue(tuple[0]));

      if (valueIsList(tuple[1])) {
        tuple = valueToList(tuple[1]);
        fmt = format("%s ", fmt);
      } else if (valueIsNil(tuple[1])) {
        break;
      } else {
        fmt = format("%s . %s", fmt, formatValue(tuple[1]));
        break;
      }
    }

    return format("%s)", fmt);
    break;
  case ValueTag.Vector:
    auto vector = valueToVector(v);
    auto fmt = format("#(%s", formatValue(vector[0]));

    foreach (Value i; vector[1 .. vector.length]) {
      fmt = format("%s %s", fmt, formatValue(i));
    }

    return format("%s)", fmt);
    break;
  default:
    return "<unknown object>";
  }
}

ValueTag tagOfValue(Value v) {
  return cast(ValueTag)(v.header & (pow(2, HEADER_TAG_WIDTH) - 1));
}

bool isValue(Value v, ValueTag vt) {
  return tagOfValue(v) == vt;
}

bool valueIsNil(Value v) { return isValue(v, ValueTag.Nil); }

Value makeIntegerValue(long i) {
  Value v = { data: i, header: ValueTag.Integer };
  return v;
}

bool valueIsInteger(Value v) { return isValue(v, ValueTag.Integer); }

long valueToInteger(Value v) {
  return cast(long)v.data;
}

Value makeCharValue(char c) {
  Value v = { data: c, header: ValueTag.Char };
  return v;
}

bool valueIsChar(Value v) { return isValue(v, ValueTag.Char); }

char valueToChar(Value v) {
  return cast(char)v.data;
}

Value makeBoolValue(bool b) {
  Value v = { data: b, header: ValueTag.Bool };
  return v;
}

bool valueIsBool(Value v) { return isValue(v, ValueTag.Bool); }

bool valueToBool(Value v) {
  return cast(bool)v.data;
}

Value makeBigIntegerValue(BigInt i) {
  Value v = { data: cast(long)new BigInt(i), header: ValueTag.BigInteger };
  return v;
}

bool valueIsBigInteger(Value v) { return isValue(v, ValueTag.BigInteger); }

BigInt valueToBigInteger(Value v) {
  return *cast(BigInt*)v.data;
}

static const ulong MAX_VALUE_LENGTH = pow(2, WORD_SIZE) - 1;

Tuple!(void*, ulong) copyString(string s) {
  ulong size = s.length + 1 > MAX_VALUE_LENGTH ? MAX_VALUE_LENGTH : s.length + 1;

  auto heapString = new char[size];
  foreach (i, c; s[0 .. size - 1]) {
    heapString[i] = c;
  }
  heapString[size - 1] = '\0';
  return Tuple!(void*, ulong)(cast(void*)heapString, size);
}

Value makeStringValue(string s) {
  auto string = copyString(s);
  Value v = { data: cast(long)string[0], header: string[1] << HEADER_TAG_WIDTH | ValueTag.String };
  return v;
}

bool valueIsString(Value v) { return isValue(v, ValueTag.String); }

char* valueToByteVector(Value v) {
  return cast(char*)v.data;
}

string valueToString(Value v) {
  return fromStringz(valueToByteVector(v)).dup;
}

void updateValueString(Value v, long index, char c) {
  auto vector = valueToByteVector(v);
  vector[index] = c;
}

Value makeSymbolValue(string s) {
  Value v = makeStringValue(s);
  v.header >>= HEADER_TAG_WIDTH;
  v.header <<= HEADER_TAG_WIDTH;
  v.header |= ValueTag.Symbol;
  return v;
}

bool valueIsSymbol(Value v) { return isValue(v, ValueTag.Symbol); }

string valueToSymbol(Value v) {
  return valueToString(v);
}

Value makeListValue(Value head, Value tail) {
  Value v;
  v.header = ValueTag.List;
  Value** tuple = cast(Value**)new Value*[2];
  foreach (i, item; [head, tail]) {
    tuple[i] = new Value;
    tuple[i].header = item.header;
    tuple[i].data = item.data;
  }
  v.data = cast(long)tuple;
  return v;
}

bool valueIsList(Value v) { return isValue(v, ValueTag.List); }

Tuple!(Value, Value) valueToList(Value v) {
  Value** m = cast(Value**)v.data;
  return Tuple!(Value, Value)(*m[0], *m[1]);
}

Value makeVectorValue(Value[] v) {
  ulong size = v.length > MAX_VALUE_LENGTH ? MAX_VALUE_LENGTH : v.length;
  Value[] vCopy = new Value[v.length];
  foreach (i, e; v) {
    vCopy[i] = e;
  }

  Value ve = { data: cast(long)vCopy.ptr, header: size << HEADER_TAG_WIDTH | ValueTag.Vector };
  return ve;
}

bool valueIsVector(Value v) { return isValue(v, ValueTag.Vector); }

Value[] valueToVector(Value v) {
  long size = v.header >> HEADER_TAG_WIDTH;
  Value[] vector;
  vector = (cast(Value*)v.data)[0 .. size];
  return vector;
}

void updateValueVector(Value v, long index, Value element) {
  auto vector = valueToVector(v);
  vector[index] = element;
}

Value makeFunctionValue(string name, Value delegate(Value, void**) f, bool special) {
  void* namePtr = copyString(name)[0];
  Value v;
  v.header = ValueTag.Function;
  long* tuple = cast(long*)new long[3];
  tuple[0] = cast(long)namePtr;
  tuple[0] <<= HEADER_TAG_WIDTH;
  tuple[0] |= cast(int)special;
  tuple[1] = cast(long)f.ptr;
  tuple[2] = cast(long)f.funcptr;
  v.data = cast(long)tuple;
  return v;
}

bool valueIsFunction(Value v) { return isValue(v, ValueTag.Function); }

Tuple!(string, Value delegate(Value, void**), bool) valueToFunction(Value v) {
  Value delegate(Value, void**) f;
  long* tuple = cast(long*)v.data;
  bool special = cast(bool)(tuple[0] & (pow(2, HEADER_TAG_WIDTH) - 1));
  void* namePtr = cast(void*)(tuple[0] >> HEADER_TAG_WIDTH);
  string name = fromStringz(cast(char*)namePtr).dup;
  f.ptr = cast(void*)tuple[1];
  f.funcptr = cast(Value function(Value, void**))(tuple[2]);
  return Tuple!(string, Value delegate(Value, void**), bool)(name, f, special);
}
