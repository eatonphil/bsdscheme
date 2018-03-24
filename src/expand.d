import std.stdio;

import value;

void exError(string error) {
  throw new Exception(format("[EX][ERROR]: %s", error));
}

void exWarning(string warning) {
  writeln(format("[EX][WARNING]: %s", warning));
}

alias Extension = Value function(Value);
alias Extensions = Extension[string];

Extension syntaxRules(Value ast) {
  return Value function(Value) {
    
  }
}

Extension makeTransformer(Value transformerAst) {
  auto _cdr = cdr(transformerAst);
  auto transformer = valueToString(car(transformerAst));
  switch (transformer) {
  case "syntax-rules":
    return syntaxRules(_cdr);
  case "syntax-case":
    exError("syntax-case is not supported");
  default:
    exError(format("%s syntax transformer is not supported", transformer));
  }
}

void defineSyntax(Value ast, ref Extensions extensions) {
  auto dispatcher = valueToString(car(ast));
  auto transformer = cdr(ast);
  extensions[dispatcher] = makeTransformer(transformer);
}

Value expand(Value ast, ref Extensions extensions) {
  switch (tagOfValue(ast)) {
  case ValueTag.Symbol:
    return ast;
  case ValueTag.List:
    string symbol = valueToString(car(ast));

    if (symbol in extensions) {
      return expand(extensions[symbol](ast), extensions);
    } else {
      switch (symbol) {
      case "define-syntax":
        defineSyntax(cdr(ast), extensions);
        return nilValue;
      default:
        break;
      }
    }

    Value[] vs = [car(ast)];
    foreach (v; listToVector(cdr(ast))) {
      vs ~= expand(v);
    }

    return vectorToList(vs);
  default:
    return ast;
  }
}
