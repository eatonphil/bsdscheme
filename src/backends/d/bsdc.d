import std.array;
import std.algorithm;
import std.file;
import std.format;
import std.functional;
import std.process;
import std.stdio;

import common;
import expand : expand;
import parse;
import utility;
import value;

import cg;
import context;
import ir;

void generate(string outFile, string prologue, IR ir, string epilogue) {
  auto f = File(outFile, "w");

  f.write(prologue);
  f.write(CG.fromIR(ir, true));
  f.write(epilogue);
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
  Value value = parse.read(source);
  Value delegate(Value)[string] syntaxExtensions;
  value = expand(value, syntaxExtensions);

  auto ctx = Context.getDefault();
  IR ir = IR.fromAST(withBegin(value), ctx);

  string[] dImports = ["std.stdio"];
  string[] localDImports = ["lex", "common", "parse", "utility", "value", "buffer"];

  string[] prologue;
  foreach (imp; dImports ~ localDImports) {
    prologue ~= format("import %s;", imp);
  }
  prologue ~= "\n";

  string epilogue = "\nvoid main() { BSDScheme_main(nilValue, cast(void**)0); }";

  auto buildFile = args.length > 2 ? args[2] : "a.d";
  generate(buildFile, prologue.join("\n"), ir, epilogue);

  auto outFile = args.length > 3 ? args[3] : "a";
  build(buildFile, localDImports, outFile);

  return 0;
}
