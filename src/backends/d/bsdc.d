import std.array;
import std.file;
import std.format;
import std.functional;
import std.process;
import std.stdio;

import common;
import parse;
import utility;
import value;

alias Context = string[string];
struct Program {
  string[] external;
  string[] constants;
  string[] definitions;
  string[] functionBody;
}

void compileError(string error) {
  throw new Exception(format("[ERROR]: %s", error));
}

Value compileDefine(Value value, Context* ctx, Program* pgm) {
  const string ARGUMENTS = "arguments";
  auto definition = car(value);

  // (define (fn ...) ...)
  if (valueIsList(definition)) {
    auto functionName = car(definition);
    string symbol = valueToSymbol(functionName);

    auto arg2 = cdr(definition);
    string[] parameters;

    foreach (i, parameter; listToVector(arg2)) {
      string argCdrs = ARGUMENTS;
      for (int j = 0; j < i; j++) {
        argCdrs = format("cdr(%s)", argCdrs);
      }

      auto compiled = compile(parameter, ctx, pgm);
      parameters ~= format("    Value %s = car(%s)", valueToString(compiled), argCdrs);
    }

    (*ctx)[symbol] = format("BSDScheme_%s", symbol);
    Context newCtx = ctx.dup();
    Program newPgm;
    Value compiled = compile(withBegin(cdr(value)), &newCtx, &newPgm);

    pgm.definitions ~= newPgm.definitions;
    pgm.definitions ~= format("Value %s(Value %s, void** rest) {%s;\n%s\n%s\n}\n",
                              (*ctx)[symbol],
                              ARGUMENTS,
                              parameters.join(";\n"),
                              newPgm.functionBody.join(";\n") ~ ";",
                              valueToString(compiled));
  } else if (valueIsSymbol(definition)) {
    string symbol = valueToSymbol(definition);

    auto arg2 = car(cdr(value));
    auto compiled = compile(arg2, ctx, pgm);

    bool shadowing = (symbol in (*ctx)) !is null;
    (*ctx)[symbol] = symbol;

    pgm.functionBody ~= format("    %s%s = %s",
                               shadowing ? "" : "Value ",
                               symbol,
                               valueToString(compiled));
  } else {
    // TODO: handle this?
  }

  return nilValue;
}

Value compileBegin(Value value, Context* ctx, Program* pgm) {
  auto vector = listToVector(value);
  foreach (i, arg; vector) {
    Value compiled = compile(arg, ctx, pgm);

    if (!valueIsNil(compiled)) {
      pgm.functionBody ~= format("    %s%s", i == vector.length - 1 ? "return " : "", valueToString(compiled));
    }
  }

  return nilValue;
}

Value compileIf(Value value, Context* ctx, Program* pgm) {
  auto vector = listToVector(value);
  auto arg1 = vector[0];
  auto test = compile(arg1, ctx, pgm);

  auto arg2 = vector[1];
  auto ifThen = compile(arg2, ctx, pgm);

  auto arg3 = vector.length == 3 ? vector[2] : nilValue;
  auto ifElse = compile(arg3, ctx, pgm);

  pgm.functionBody ~= format("    if (truthy(%s)) {\n        return %s;\n    } else {\n        return %s;\n    }",
                             valueToString(test),
                             valueToString(ifThen),
                             valueToString(ifElse));
  return nilValue;
}

Value compile(Value value, Context* ctx, Program* pgm) {
  switch (tagOfValue(value)) {
  case ValueTag.Symbol:
    auto string = valueToSymbol(value);
    return makeStringValue(string);
  case ValueTag.String:
    auto string = valueToString(value);
    return makeStringValue(format("makeStringValue(\"%s\")", string));
  case ValueTag.Integer:
    auto i = valueToInteger(value);
    return makeStringValue(format("makeIntegerValue(%d)", i));
  case ValueTag.Bool:
    auto b = valueToBool(value);
    return makeStringValue(format("makeBoolValue(%s)", b ? "true" : "false"));
  case ValueTag.Char:
    auto c = valueToChar(value);
    return makeStringValue(format("makeCharValue('%c')", c));
  case ValueTag.List:
    Value result;
    auto v = valueToList(value);

    string symbol = valueToString(v[0]);
    switch (symbol) {
    case "define":
      return compileDefine(v[1], ctx, pgm);
    case "begin":
      return compileBegin(v[1], ctx, pgm);
    case "if":
      return compileIf(v[1], ctx, pgm);
    default:
      if (symbol !in *ctx) {
        compileError(format("Cannot call undefined function %s", symbol));
      }

      string[] arguments;
      foreach (arg; listToVector(v[1])) {
        auto compiled = compile(arg, ctx, pgm);
        arguments ~= valueToString(compiled);
      }

      string functionName = (*ctx)[symbol];
      string argumentsAsList = "nilValue";
      if (arguments.length > 1) {
        argumentsAsList = format("vectorToList([%s])", arguments.join(", "));
      } else if (arguments.length == 1 && arguments[0] != "") {
        argumentsAsList = format("makeListValue(%s, nilValue)", arguments[0]);
      }

      return makeStringValue(format("%s(%s, cast(void**)0)", functionName, argumentsAsList));
    }
  default:
    return nilValue;
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
  Value value = parse.read(source);

  Context ctx = [
    "+": "plus",
    "-": "minus",
    "*": "times",
    "=": "equals",
    "cons": "cons",
    "car": "_car",
    "cdr": "_cdr",
    "display": "display",
    "newline": "newline",
    "read": "_read",
    "string?": "stringP",
    "make-string": "makeString",
    "string": "stringFun",
    "string-length": "stringLength",
    "string-ref": "stringRef",
    "string=?": "stringEquals",
    "string-append": "stringAppend",
    "list->string": "listToString",
    "string-upcase": "stringUpcase",
    "string-downcase": "stringDowncase",
    "substring": "substring",
    "string->list": "stringToList",
    "vector-length": "vectorLength",
    "vector-ref": "vectorRef",
    "vector?": "vectorP",
    "vector->string": "vectorToString",
    "string->vector": "stringToVector",
    "vector->list": "_vectorToList",
    "list->vector": "_listToVector",
    "vector-append": "vectorAppend",
    "make-vector": "makeVector",
  ];
  Program pgm;
  compile(withBegin(value), &ctx, &pgm);

  string[] dImports = ["std.stdio"];
  string[] localDImports = ["lex", "common", "parse", "utility", "value", "buffer"];

  foreach (imp; dImports ~ localDImports) {
    pgm.external ~= format("import %s;", imp);
  }
  pgm.definitions ~= "void main() { BSDScheme_main(nilValue, cast(void**)0); }";

  auto buildFile = args.length > 2 ? args[2] : "a.d";
  generate(pgm, buildFile);

  auto outFile = args.length > 3 ? args[3] : "a";
  build(buildFile, localDImports, outFile);

  return 0;
}
