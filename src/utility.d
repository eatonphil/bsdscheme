import core.stdc.stdlib;
import std.format;
import std.stdio;

import parse;
import runtime;
import value;

Value appendList(Value l1, Value l2) {
  if (valueIsNil(l1)) {
    return l2;
  }

  auto tuple = valueToList(l1);
  Value car = tuple[0];
  Value cdr = appendList(tuple[1], l2);
  return makeListValue(car, cdr);
}

Value reverseList(Value value) {
  if (valueIsList(value)) {
    auto tuple = valueToList(value);
    return appendList(reverseList(tuple[1]),
                      makeListValue(tuple[0], nilValue));
  }

  return value;
}

void print(Value value) {
  write(stringOfValue(value));
}

void error(string msg, Value value) {
  writeln(format("[ERROR] %s: %s", msg, stringOfValue(value)));
  exit(1);
}
