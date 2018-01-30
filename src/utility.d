import value;

Value nilValue = { data: 0, header: ValueTag.Nil };
Value zeroValue = makeIntegerValue(0);
Value trueValue = makeBoolValue(true);
Value falseValue = makeBoolValue(false);

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

Value car(Value arguments) {
  return valueToList(arguments)[0];
}

Value cdr(Value arguments) {
  return valueToList(arguments)[1];
}

Value[] listToVector(Value list) {
  Value[] vector;
  while (!valueIsNil(list)) {
    vector ~= car(list);
    list = cdr(list);
  }
  return vector;
}

Value vectorToList(Value[] vector) {
  Value list;
  foreach (i; vector) {
    list = appendList(list, makeListValue(i, nilValue));
  }
  return list;
}

Value withBegin(Value beginBody) {
  Value begin = makeSymbolValue("begin");
  Value beginList = makeListValue(begin, nilValue);
  return appendList(beginList, beginBody);
}

bool truthy(Value test) {
  return valueIsInteger(test) && valueToInteger(test) ||
    valueIsString(test) && valueToString(test).length ||
    valueIsSymbol(test) ||
    valueIsFunction(test) ||
    valueIsBool(test) && valueToBool(test);
}
