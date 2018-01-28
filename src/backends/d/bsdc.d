import std.array;
import std.file;
import std.format;
import std.functional;
import std.process;
import std.stdio;

import ast;
import parse;
import utility;

alias Context = string[string];
struct Program {
  string[] external;
  string[] constants;
  string[] definitions;
}

void compileError(string error) {
  throw new Exception(format("[ERROR]: %s", error));
}

AST withBegin(AST beginBody) {
  AST begin = makeSymbolAst("begin");
  AST beginList = makeListAst(begin, nil);
  return appendList(beginList, beginBody);
}

AST compileDefine(AST ast, Context* ctx, Program* pgm) {
  auto definition = car(ast);
  auto functionName = car(definition);
  string symbol = astToString(functionName);

  auto arg2 = cdr(definition);
  string[] parameters;

  foreach (parameter; listToVector(arg2)) {
    auto compiled = compile(parameter, ctx, pgm);
    parameters ~= format("AST %s", astToString(compiled));
  }

  (*ctx)[symbol] = format("BSDScheme_%s", symbol);
  Context newCtx = ctx.dup();
  AST compiled = compile(withBegin(cdr(ast)), &newCtx, pgm);

  pgm.definitions ~= format("AST %s(%s) {\n%s\n}\n", (*ctx)[symbol], parameters.join(", "), astToString(compiled));

  return nil;
}

AST compilePlus(AST ast, Context* ctx, Program* pgm) {
  string[] parameters;
  foreach (arg; listToVector(ast)) {
    auto compiled = compile(arg, ctx, pgm);
    parameters ~= format("astToInteger(%s)", astToString(compiled));
  }

  return makeStringAst(format("makeIntegerAst(%s)", parameters.join(" + ")));
}

AST compileBegin(AST ast, Context* ctx, Program* pgm) {
  string[] expressions;

  auto vector = listToVector(ast);
  foreach (i, arg; vector) {
    AST compiled = compile(arg, ctx, pgm);
    if (!astIsNil(compiled)) {
      expressions ~= format("    %s%s", i == vector.length - 1 ? "return " : "", astToString(compiled));
    }
  }

  return makeStringAst(expressions.join(";\n") ~ ";");
}

AST compileDisplay(AST ast, Context* ctx, Program* pgm) {
  auto compiled = compile(car(ast), ctx, pgm);
  return makeStringAst(format("writeln(formatAst(%s)), nil", astToString(compiled)));
}

AST compile(AST ast, Context* ctx, Program* pgm) {
  switch (tagOfAst(ast)) {
  case ASTTag.Symbol:
    auto string = astToSymbol(ast);
    return makeStringAst(string);
  case ASTTag.String:
    auto string = astToString(ast);
    return makeStringAst(format("makeStringAst(\"%s\")", string));
  case ASTTag.Integer:
    auto i = astToInteger(ast);
    return makeStringAst(format("makeIntegerAst(%d)", i));
  case ASTTag.Bool:
    auto b = astToBool(ast);
    return makeStringAst(format("makeBoolAst(%s)", b ? "true" : "false"));
  case ASTTag.Char:
    auto c = astToChar(ast);
    return makeStringAst(format("makeCharAst('%c')", c));
  case ASTTag.List:
    AST result;
    auto v = astToList(ast);

    string symbol = astToString(v[0]);
    switch (symbol) {
    case "begin":
      return compileBegin(v[1], ctx, pgm);
    case "define":
      return compileDefine(v[1], ctx, pgm);
    case "display":
      return compileDisplay(v[1], ctx, pgm);
    case "+":
      return compilePlus(v[1], ctx, pgm);
    default:
      if (symbol !in *ctx) {
        compileError(format("Cannot call undefined function %s", symbol));
      }

      string[] arguments;
      foreach (arg; listToVector(v[1])) {
        auto compiled = compile(arg, ctx, pgm);
        arguments ~= astToString(compiled);
      }

      string functionName = (*ctx)[symbol];
      return makeStringAst(format("%s(%s)", functionName, arguments.join(", ")));
    }
  default:
    return nil;
  }
}

void generate(Program pgm, string outFile) {
  auto f = File(outFile, "w");

  foreach (line; pgm.external) {
    f.writeln(line);
  }

  f.writeln();

  foreach (line; pgm.constants) {
    f.writeln(line);
  }

  f.writeln();

  foreach (line; pgm.definitions) {
    f.writeln(line);
  }
}

void build(string buildFile, string[] localDImports, string outFile) {
  string[] importsWithPath;

  foreach (imp; localDImports) {
    importsWithPath ~= format("src/%s", imp);
  }

  string[] cmd = ["ldc", buildFile] ~ importsWithPath ~ ["-of", outFile];
  auto execution = execute(cmd);
  if (execution.status != 0) {
    writeln(execution.output);
  }
}

int main(string[] args) {
  auto source = cast(char[])read(args[1]);
  AST ast = parse.read(source);

  Context ctx;
  Program pgm;
  compile(withBegin(ast), &ctx, &pgm);

  string[] dImports = ["std.stdio"];
  string[] localDImports = ["ast", "utility"];

  foreach (imp; dImports ~ localDImports) {
    pgm.external ~= format("import %s;", imp);
  }
  pgm.definitions ~= "void main() { BSDScheme_main(); }";

  auto buildFile = args.length > 2 ? args[2] : "a.d";
  generate(pgm, buildFile);

  auto outFile = args.length > 3 ? args[3] : "a";
  build(buildFile, localDImports, outFile);

  return 0;
}
