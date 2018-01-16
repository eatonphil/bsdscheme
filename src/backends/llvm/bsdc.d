import std.functional;
import std.file;
import std.stdio;

import parse;
import ast;

alias Context = AST[string];
struct Program {
  string[] external;
  string[] constants;
  string[] definitions;
}

void compile(AST ast, Context* ctx, Program* pgm) {

}

void generate(Program* pgm, string outFile) {
  
}

int main(string[] args) {
  auto source = cast(char[])read(args[1]);
  AST ast = parse.read(source);
  AST begin = makeSymbolAst("begin");
  AST topLevelItem = makeListAst(begin, ast);

  Context ctx;
  auto pgm = new Program;
  compile(topLevelItem, &ctx, pgm);
  generate(pgm, "a.ll");

  return 0;
}
