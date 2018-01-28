import ast;

AST nil = { data: 0, header: ASTTag.Nil };

AST appendList(AST l1, AST l2) {
  if (astIsNil(l1)) {
    return l2;
  }

  auto tuple = astToList(l1);
  AST car = tuple[0];
  AST cdr = appendList(tuple[1], l2);
  return makeListAst(car, cdr);
}

AST reverseList(AST value) {
  if (astIsList(value)) {
    auto tuple = astToList(value);
    return appendList(reverseList(tuple[1]),
                      makeListAst(tuple[0], nil));
  }

  return value;
}

AST car(AST arguments) {
  return astToList(arguments)[0];
}

AST cdr(AST arguments) {
  return astToList(arguments)[1];
}

AST[] listToVector(AST list) {
  AST[] vector;
  while (!astIsNil(list)) {
    vector ~= car(list);
    list = cdr(list);
  }
  return vector;
}

AST vectorToList(AST[] vector) {
  AST list;
  foreach (i; vector) {
    list = appendList(list, makeListAst(i, nil));
  }
  return list;
}
