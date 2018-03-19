import std.format;
import std.stdio;

import value;
import utility;

import context;

void irError(string error) {
  throw new Exception(format("[IR][ERROR]: %s", error));
}

void irWarning(string warning) {
  writeln(format("[IR][WARNING]: %s", warning));
}

class IR {
  static IR fromAST(Value value, Context ctx) {
    switch (tagOfValue(value)) {
    case ValueTag.Symbol:
      return VariableIR.fromAST(value, ctx);
    case ValueTag.String:
      auto s = valueToString(value);
      return new LiteralIR!string(s);
    case ValueTag.Integer:
      auto i = valueToInteger(value);
      return new LiteralIR!long(i);
    case ValueTag.Bool:
      auto b = valueToBool(value);
      return new LiteralIR!bool(b);
    case ValueTag.Char:
      auto c = valueToChar(value);
      return new LiteralIR!char(c);
    case ValueTag.Nil:
      return NilIR.get();
    case ValueTag.List:
      return FuncallIR.fromAST(value, ctx);
    default:
      irError(format("Bad value: %s", tagOfValue(value)));
      assert(0);
    }
  }

  IR getReturnIR() {
    return this;
  }
}

class NilIR : IR {
  static NilIR nir;

  static NilIR get() {
    if (NilIR.nir is null) {
      NilIR.nir = new NilIR;
    }

    return NilIR.nir;
  }
}

class LiteralIR(T) : IR {
  T value;

  this(T initValue) {
    value = initValue;
  }
}

class VariableIR : IR {
  string name;

  // Assumes the variable is already accessible in scope.
  this(string initName) {
    name = initName;
  }

  static VariableIR fromAST(Value value, Context ctx) {
    string symbol = valueToSymbol(value);
    if (!ctx.contains(symbol)) {
      irError(format("Undefined symbol: %s", symbol));
      assert(0);
    }

    return new VariableIR(symbol);
  }
}

class FuncallIR : IR {
  string name;
  string returnVariable;
  IR[] arguments;

  this(string initName, IR[] initArguments, string initReturnVariable) {
    name = initName;
    arguments = initArguments;
    returnVariable = initReturnVariable;
  }

  static IR fromAST(Value value, Context ctx) {
    auto v = valueToList(value);
    string symbol = valueToString(v[0]);

    switch (symbol) {
    case "define":
      return DefineIR.fromAST(v[1], ctx);
    case "begin":
      return BeginIR.fromAST(v[1], ctx);
    case "if":
      return IfIR.fromAST(v[1], ctx);
    case "let":
      return LetIR.fromAST(v[1], ctx);
    case "let*":
      return LetStarIR.fromAST(v[1], ctx);
    case "set!":
      return SetIR.fromAST(v[1], ctx);
    default:
      break;
    }

    if (!ctx.contains(symbol)) {
      irError(format("Call to unknown function: %s", symbol));
      assert(0);
    }

    auto fn = ctx.get(symbol);

    string returnVariable = ctx.setTmp(format("%s_result", fn));
    auto fir = new FuncallIR(fn, [], returnVariable);

    foreach (arg; listToVector(v[1])) {
      fir.arguments ~= IR.fromAST(arg, ctx);
    }

    return fir;
  }

  override IR getReturnIR() {
    return new VariableIR(returnVariable);
  }
}

class AssignmentIR : IR {
  string assignTo;
  IR value;
  bool shadowing;

  this(string initAssignTo, IR initValue, bool initShadowing) {
    assignTo = initAssignTo;
    value = initValue;
    shadowing = initShadowing;
  }

  this(string assignTo, IR value) {
    this(assignTo, value, false);
  }

  override IR getReturnIR() {
    return new VariableIR(assignTo);
  }
}

const string ARGUMENTS = "arguments";

class DefineFunctionIR : IR {
  string name;
  string tmp;
  string[] parameters;
  BeginIR block;

  static IR fromAST(Value definition, Value block, Context ctx) {
    auto functionName = car(definition);
    string symbol = valueToSymbol(functionName);

    auto dir = new DefineFunctionIR;

    if (ctx.contains(symbol)) {
      irWarning(format("Shadowing assignment: %s", symbol));
    }
    dir.name = format("BSDScheme_%s", symbol);
    ctx.set(symbol, dir.name, false);

    auto arg2 = cdr(definition);
    string[] parameters;

    foreach (i, parameter; listToVector(arg2)) {
      string p = valueToString(parameter);
      ctx.set(p, "", false);
      dir.parameters ~= p;
    }

    auto newCtx = ctx.dup();
    newCtx.tmps.clear;

    dir.tmp = newCtx.setTmp("tmp");
    dir.block = BeginIR.fromAST(block, newCtx);

    return dir;
  }

  override IR getReturnIR() {
    return block.getReturnIR();
  }
}

class DefineIR : IR {
  IR value;

  static IR fromAST(Value value, Context ctx) {
    auto dir = new DefineIR;

    auto definition = car(value);

    // (define (fn ...) ...)
    if (valueIsList(definition)) {
      return DefineFunctionIR.fromAST(definition, cdr(value), ctx);
    }

    if (!valueIsSymbol(definition)) {
      irError("Unexpected define structure");
      assert(0);
    }

    string symbol = valueToSymbol(definition);

    auto arg2 = car(cdr(value));
    auto ir = IR.fromAST(arg2, ctx);

    if (ctx.contains(symbol)) {
      irWarning(format("Shadowing assignment: %s", symbol));
    }
    ctx.set(symbol, symbol, false);
    dir.value = new AssignmentIR(symbol, ir);

    return dir;
  }
}

class BeginIR : IR {
  IR[] expressions;

  static BeginIR fromAST(Value value, Context ctx) {
    auto bir = new BeginIR;

    auto vector = listToVector(value);
    foreach (i, arg; vector) {
      bir.expressions ~= IR.fromAST(arg, ctx);
    }

    return bir;
  }

  override IR getReturnIR() {
    auto length = this.expressions.length;
    if (!length) {
      return NilIR.get();
    }

    auto lastExp = this.expressions[length - 1];
    return lastExp.getReturnIR();
  }
}

class IfIR : IR {
  IR test;
  IR ifThen;
  IR ifElse;
  string returnVariable;

  static IfIR fromAST(Value value, Context ctx) {
    auto iir = new IfIR;

    auto vector = listToVector(value);
    auto arg1 = vector[0];
    iir.test = IR.fromAST(arg1, ctx);

    auto arg2 = vector[1];
    iir.ifThen = IR.fromAST(arg2, ctx);

    auto arg3 = vector.length == 3 ? vector[2] : nilValue;
    iir.ifElse = IR.fromAST(arg3, ctx);

    iir.returnVariable = ctx.setTmp("if_result");

    return iir;
  }

  override IR getReturnIR() {
    return new VariableIR(returnVariable);
  }
}

LetXIR letXIRFromAST(Value value, Context ctx, bool letStar) {
  auto defs = car(value);
  auto block = cdr(value);

  auto lir = new LetIR;
  foreach (def; listToVector(defs)) {
    auto key = valueToString(car(def));
    auto val = car(cdr(def));

    bool shadowing = ctx.contains(key);

    if (letStar) {
      ctx.set(key, "", false);
    }
    lir.assignments ~= new AssignmentIR(key, IR.fromAST(val, ctx.dup()), shadowing);
    if (!letStar) {
      ctx.set(key, "", false);
    }
  }

  auto newCtx = ctx.dup();
  lir.block = BeginIR.fromAST(block, newCtx);

  return lir;
}

class LetXIR : IR {
  AssignmentIR[] assignments;
  BeginIR block;

  override IR getReturnIR() {
    return block.getReturnIR();
  }
}

class LetIR : LetXIR {
  static LetXIR fromAST(Value value, Context ctx) {
    return letXIRFromAST(value, ctx, false);
  }
}

class LetStarIR : LetXIR {
  static LetXIR fromAST(Value value, Context ctx) {
    return letXIRFromAST(value, ctx, true);
  }
}

class SetIR : IR {
  static AssignmentIR fromAST(Value value, Context ctx) {
    auto symbol = valueToString(car(value));
    auto val = car(cdr(value));

    if (!ctx.contains(symbol)) {
      irError(format("Attempted to set! undefined symbol: %s", symbol));
    }

    return new AssignmentIR(symbol, IR.fromAST(val, ctx), true);
  }
}
