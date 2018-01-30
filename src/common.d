import core.stdc.stdlib;
import core.vararg;
import std.bigint;
import std.format;
import std.functional;
import std.stdio;
import std.uni;

import value;
import parse;
import utility;

void error(string msg, Value value) {
  writeln(format("[ERROR] %s: %s", msg, formatValue(value)));
  exit(1);
}

Value reduceValues(Value delegate(Value, Value) f, Value arguments, ref Value initial) {
  Value result = initial;

  auto iterator = arguments;
  while (valueIsList(iterator)) {
    result = f(result, car(iterator));
    iterator = cdr(iterator);
  }

  return result;
}

Value plus(Value arguments, ...) {
  Value _plus(Value previous, Value current) {
    if (valueIsBigInteger(previous) || valueIsBigInteger(current)) {
      BigInt a, b;

      if (valueIsBigInteger(previous)) {
        a = valueToBigInteger(previous);
      } else {
        a = BigInt(valueToInteger(previous));
      }

      if (valueIsBigInteger(current)) {
        b = valueToBigInteger(current);
      } else {
        b = BigInt(valueToInteger(current));
      }

      return makeBigIntegerValue(a + b);
    }

    long a = valueToInteger(previous);
    long b = valueToInteger(current);

    if (b > 0 && a > long.max - b ||
        b < 0 && a < long.max - b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerValue(bA + bB);
    }

    return makeIntegerValue(a + b);
  }

  return reduceValues(&_plus, arguments, zeroValue);
}

Value times(Value arguments, ...) {
  Value _times(Value previous, Value current) {
    if (valueIsBigInteger(previous) || valueIsBigInteger(current)) {
      BigInt a, b;

      if (valueIsBigInteger(previous)) {
        a = valueToBigInteger(previous);
      } else {
        a = BigInt(valueToInteger(previous));
      }

      if (valueIsBigInteger(current)) {
        b = valueToBigInteger(current);
      } else {
        b = BigInt(valueToInteger(current));
      }

      return makeBigIntegerValue(a * b);
    }

    long a = valueToInteger(previous);
    long b = valueToInteger(current);

    if (a > long.max / b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerValue(bA * bB);
    }

    return makeIntegerValue(a * b);
  }

  auto tuple = valueToList(arguments);
  return reduceValues(&_times, tuple[1], tuple[0]);
}

// TODO: unify plus and minus
Value minus(Value arguments, ...) {
  Value _minus(Value previous, Value current) {
    if (valueIsBigInteger(previous) || valueIsBigInteger(current)) {
      BigInt a, b;

      if (valueIsBigInteger(previous)) {
        a = valueToBigInteger(previous);
      } else {
        a = BigInt(valueToInteger(previous));
      }

      if (valueIsBigInteger(current)) {
        b = valueToBigInteger(current);
      } else {
        b = BigInt(valueToInteger(current));
      }

      return makeBigIntegerValue(a - b);
    }

    long a = valueToInteger(previous);
    long b = valueToInteger(current);

    if (b > 0 && a > long.max - b ||
        b < 0 && a < long.max - b) {
      BigInt bA = BigInt(a);
      BigInt bB = BigInt(b);
      return makeBigIntegerValue(bA - bB);
    }

    return makeIntegerValue(a - b);
  }

  auto tuple = valueToList(arguments);
  return reduceValues(&_minus, tuple[1], tuple[0]);
}

Value equals(Value arguments, ...) {
  auto tuple = valueToList(arguments);
  auto left = tuple[0];
  auto right = car(tuple[1]);

  bool b;

  switch (tagOfValue(left)) {
  case ValueTag.Integer:
    b = valueIsInteger(right) && valueToInteger(left) == valueToInteger(right);
    break;
  case ValueTag.Char:
    b = valueIsChar(right) && valueToChar(left) == valueToChar(right);
    break;
  case ValueTag.String:
    b = valueIsString(right) && valueToString(left) == valueToString(right);
    break;
  case ValueTag.Symbol:
    b = valueIsSymbol(right) && valueToSymbol(left) == valueToSymbol(right);
    break;
  case ValueTag.Function:
    b = valueIsFunction(right) && valueToFunction(left)[1] == valueToFunction(right)[1];
    break;
  case ValueTag.Bool:
    b = valueIsBool(right) && valueToBool(left) == valueToBool(right);
    break;
  default:
    b = false;
  }

  return makeBoolValue(b);
}

Value display(Value arguments, ...) {
  Value head = car(arguments);
  write(formatValue(head));
  return nilValue;
}

Value newline(Value arguments, ...) {
  write("\n");
  return nilValue;
}

Value quote(Value arguments, ...) {
  return car(arguments);
}

Value cons(Value arguments, ...) {
  return arguments;
}

Value _car(Value arguments, ...) {
  return car(car(arguments));
}

Value _cdr(Value arguments, ...) {
  return valueToList(car(arguments))[1];
}

Value begin(Value arguments, ...) {
  Value result = arguments;
  auto tmp = valueToList(arguments);

  while (true) {
    result = tmp[0];

    if (valueIsList(tmp[1])) {
      tmp = valueToList(tmp[1]);
    } else {
      break;
    }
  }

  return result;
}

Value stringP(Value arguments, ...) {
  auto arg1 = car(arguments);
  bool b = valueIsString(arg1);
  return makeBoolValue(b);
}

Value makeString(Value arguments, ...) {
  auto arg1 = car(arguments);
  long k = valueToInteger(arg1);
  char[] s;
  s.length = k;

  char fill = '\0';

  auto rest = cdr(arguments);
  if (!valueIsNil(rest)) {
    auto arg2 = car(cdr(arguments));
    fill = valueToChar(arg2);
  }

  for (int i = 0; i < k; i++) {
    s[i] = fill;
  }

  return makeStringValue(s.dup);
}

Value stringFun(Value arguments, ...) {
  string s = "";

  auto iterator = arguments;
  while (!valueIsNil(iterator)) {
    auto arg = car(iterator);
    char c = valueToChar(arg);
    s ~= c;
    iterator = cdr(iterator);
  }

  return makeStringValue(s);
}

Value stringLength(Value arguments, ...) {
  auto arg1 = car(arguments);
  long l = valueToString(arg1).length;
  return makeIntegerValue(l);
}

Value stringRef(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto arg2 = car(cdr(arguments));
  string s = valueToString(arg1);
  long i = valueToInteger(arg2);
  return makeCharValue(s[i]);
}

Value stringEquals(Value arguments, ...) {
  auto arg1 = car(arguments);
  string s = valueToString(arg1);

  auto iterator = cdr(arguments);
  while (!valueIsNil(iterator)) {
    auto arg = car(iterator);
    if (s != valueToString(arg)) {
      return makeBoolValue(false);
    }
    iterator = cdr(iterator);
  }

  return makeBoolValue(true);
}

Value stringAppend(Value arguments, ...) {
  string s = "";

  auto iterator = arguments;
  while (!valueIsNil(iterator)) {
    auto arg = car(iterator);
    s ~= valueToString(arg);
    iterator = cdr(iterator);
  }

  return makeStringValue(s);
}

Value listToString(Value arguments, ...) {
  return stringFun(car(arguments));
}

Value stringUpcase(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto s = valueToString(arg1);
  return makeStringValue(toUpper(s));
}

Value stringDowncase(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto s = valueToString(arg1);
  return makeStringValue(toLower(s));
}

Value substring(Value arguments, ...) {
  auto arg1 = car(arguments);
  char[] s = valueToString(arg1).dup;

  auto arg2 = car(cdr(arguments));
  long start = valueToInteger(arg2);

  auto arg3 = car(cdr(cdr(arguments)));
  long end = valueToInteger(arg3);

  return makeStringValue(s[start .. end].dup);
}

Value stringToList(Value arguments, ...) {
  auto arg1 = car(arguments);
  char[] s = valueToString(arg1).dup;

  auto value = nilValue;

  foreach (char c; s) {
    auto cValue = makeCharValue(c);
    auto part = makeListValue(cValue, nilValue);
    value = appendList(value, part);
  }

  return value;
}

Value vectorLength(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto vector = valueToVector(arg1);
  return makeIntegerValue(vector.length);
}

Value vectorRef(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto vector = valueToVector(arg1);

  auto arg2 = car(cdr(arguments));
  long i = valueToInteger(arg2);

  return vector[i];
}

Value vectorP(Value arguments, ...) {
  auto arg1 = car(arguments);
  return makeBoolValue(valueIsVector(arg1));
}

Value vectorToString(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto vector = valueToVector(arg1);

  string s = "";

  foreach (c; vector) {
    s ~= valueToChar(c);
  }

  return makeStringValue(s);
}

Value stringToVector(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto s = valueToString(arg1);

  Value[] v;

  foreach (c; s) {
    v ~= makeCharValue(c);
  }

  return makeVectorValue(v);
}

Value _vectorToList(Value arguments, ...) {
  auto arg1 = car(arguments);
  return vectorToList(valueToVector(arg1));
}

Value _listToVector(Value arguments, ...) {
  return makeVectorValue(listToVector(car(arguments)));
}

Value vectorAppend(Value arguments, ...) {
  Value[] vector;

  auto iterator = arguments;
  while (!valueIsNil(iterator)) {
    auto arg = car(iterator);
    auto vArg = valueToVector(arg);
    vector ~= vArg;
    iterator = cdr(iterator);
  }

  return makeVectorValue(vector);
}

Value makeVector(Value arguments, ...) {
  auto arg1 = car(arguments);
  auto k = valueToInteger(arg1);

  char c = '\0';
  auto rest = cdr(arguments);
  if (!valueIsNil(rest)) {
    auto arg2 = car(rest);
    c = valueToChar(arg2);
  }

  Value[] v;
  v.length = k;

  foreach (i, _; v) {
    v[i] = makeCharValue(c);
  }

  return makeVectorValue(v);
}
