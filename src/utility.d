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
