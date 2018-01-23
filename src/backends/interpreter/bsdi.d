import parse;
import ast;

import runtime;
import value;

int main(string[] args) {
  auto ctx = new Context;
  auto include = makeSymbolAst("include");
  auto source = makeStringAst(args[1]);
  auto includeArgs = makeListAst(source, nilValue);
  auto topLevelItem = makeListAst(include, includeArgs);
  eval(topLevelItem, ctx);
  return 0;
}
