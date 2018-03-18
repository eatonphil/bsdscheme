import std.array;
import std.algorithm;
import std.file;
import std.format;
import std.functional;
import std.process;
import std.stdio;

import common;
import parse;
import utility;
import value;

struct Context {
  string[string] ctx;
  string[] specialForms;

  this(string[string] initCtx, string[] initSpecialForms) {
    ctx = initCtx;
    specialForms = initSpecialForms;
  }

  string set(string key, string value, bool requireUnique) {
    if (key in this.ctx) {
      return this.set(format("%s_1", key), value, requireUnique);
    }

    this.ctx[key] = value;
    return key;
  }

  string set(string key, string value) {
    return this.set(key, value, true);
  }

  string get(string key) {
    return this.ctx[key];
  }

  void toggleSpecial(string key, bool special) {
    int index = this.specialForms.canFind(key) - 1;
    bool currentlySpecial = cast(bool)(index + 1);
    if (special && !currentlySpecial) {
      this.specialForms ~= key;
    } else if (!special && currentlySpecial) {
      this.specialForms.remove(index);
    }
  }

  Context* dup() {
    auto d = new Context;
    d.ctx = this.ctx.dup();
    d.specialForms = this.specialForms;
    return d;
  }

  bool contains(string key) {
    return (key in this.ctx) !is null;
  }
}

void compileError(string error) {
  throw new Exception(format("[ERROR]: %s", error));
}

enum Type {
  Value,
  Integer,
  String,
  Character,
};

class IR {
  string id;
}

class StringIR : IR {
  this(string value) {
    id = value;
  }
}

class SymbolIR : IR {
  this(string value) {
    id = value;
  }
}

class BooleanIR : IR {
  bool value;

  this(bool b) {
    value = b;
  }
}

class CharacterIR : IR {
  char value;

  this(char c) {
    value = c;
  }
}

class IntegerIR : IR {
  long value;

  this(long i) {
    value = i;
  }
}

class VariableIR : IR {
  this(string name) {
    id = name;
  }
}

class FuncallIR : IR {
  IR[] arguments;

  this(string name, IR[] args) {
    id = name;
    arguments = args;
  }

  static IR fromAST(Value value, Context* ctx) {
    auto v = valueToList(value);
    string symbol = valueToString(v[0]);

    switch (symbol) {
    case "define":
      return DefineIR.fromAST(v[1], ctx);
    case "begin":
      return BeginIR.fromAST(v[1], ctx);
    case "if":
      return IfIR.fromAST(v[1], ctx);
    default:
      break;
    }

    auto fir = new FuncallIR(symbol, []);

    foreach(arg; listToVector(v[1])) {
      fir.arguments ~= ProgramIR.fromAST(arg, ctx);
    }

    return fir;
  }
}

class AssignmentIR : IR {
  Type type;
  IR value;
  bool shadowing;

  this(string assignTo, IR value, bool shadowing) {
    type = Type.Value;
    id = assignTo;
    this.value = value;
    this.shadowing = shadowing;
  }

  this(string assignTo, IR value) {
    this(assignTo, value, false);
  }
}

class DefineIR : IR {
  string name;
  Context* ctx;
  IR[] expressions;

  static DefineIR fromAST(Value value, Context* ctx) {
    auto dir = new DefineIR;

    const string ARGUMENTS = "arguments";
    auto definition = car(value);

    // (define (fn ...) ...)
    if (valueIsList(definition)) {
      auto functionName = car(definition);
      string symbol = valueToSymbol(functionName);
      dir.id = symbol;

      auto arg2 = cdr(definition);
      string[] parameters;

      foreach (i, parameter; listToVector(arg2)) {
        auto vir = new FuncallIR("nth", [new VariableIR(ARGUMENTS), new IntegerIR(i)]);
        dir.expressions ~= new AssignmentIR(valueToString(parameter), vir);
      }

      ctx.set(symbol, format("BSDScheme_%s", symbol));
      auto newCtx = ctx.dup();
      auto bir = BeginIR.fromAST(cdr(value), newCtx);
      dir.expressions = bir.expressions;
    } else if (valueIsSymbol(definition)) {
      string symbol = valueToSymbol(definition);
      dir.id = symbol;

      auto arg2 = car(cdr(value));
      auto ir = ProgramIR.fromAST(arg2, ctx);

      bool shadowing = ctx.contains(symbol);
      symbol = ctx.set(symbol, symbol);

      dir.expressions ~= new AssignmentIR(symbol, ir, shadowing);
    } else {
      // TODO: handle this?
    }

    return dir;
  }
}

class BeginIR : IR {
  IR[] expressions;

  static BeginIR fromAST(Value value, Context* ctx) {
    auto bir = new BeginIR;

    auto vector = listToVector(value);
    foreach (i, arg; vector) {
      bir.expressions ~= ProgramIR.fromAST(arg, ctx);
    }

    return bir;
  }
}

class IfIR : IR {
  IR test;
  IR ifThen;
  IR ifElse;

  static IfIR fromAST(Value value, Context* ctx) {
    auto iir = new IfIR;

    auto vector = listToVector(value);
    auto arg1 = vector[0];
    iir.test = ProgramIR.fromAST(arg1, ctx);

    auto arg2 = vector[1];
    iir.ifThen = ProgramIR.fromAST(arg2, ctx);

    auto arg3 = vector.length == 3 ? vector[2] : nilValue;
    iir.ifElse = ProgramIR.fromAST(arg3, ctx);

    return iir;
  }
}

class ProgramIR {
  string returnValue;

  static IR fromAST(Value value, Context* ctx) {
    switch (tagOfValue(value)) {
    case ValueTag.Symbol:
      auto string = valueToSymbol(value);
      return new SymbolIR(string);
    case ValueTag.String:
      auto string = valueToString(value);
      return new StringIR(string);
    case ValueTag.Integer:
      auto i = valueToInteger(value);
      return new IntegerIR(i);
    case ValueTag.Bool:
      auto b = valueToBool(value);
      return new BooleanIR(b);
    case ValueTag.Char:
      auto c = valueToChar(value);
      return new CharacterIR(c);
    case ValueTag.List:
      return FuncallIR.fromAST(value, ctx);
    default:
      compileError(format("Bad value: %s", tagOfValue(value)));
      assert(0);
    }
  }
}

void generate(string outFile, string prologue, IR ir, string epilogue) {
  auto f = File(outFile, "w");

  return;
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

  auto ctx = new Context([
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
  ], []);
  IR ir = ProgramIR.fromAST(withBegin(value), ctx);

  string[] dImports = ["std.stdio"];
  string[] localDImports = ["lex", "common", "parse", "utility", "value", "buffer"];

  string[] prologue;
  foreach (imp; dImports ~ localDImports) {
    prologue ~= format("import %s;", imp);
  }
  string epilogue = "void main() { BSDScheme_main(nilValue, cast(void**)0); }";

  auto buildFile = args.length > 2 ? args[2] : "a.d";
  generate(buildFile, prologue.join("\n"), ir, epilogue);

  auto outFile = args.length > 3 ? args[3] : "a";
  build(buildFile, localDImports, outFile);

  return 0;
}
