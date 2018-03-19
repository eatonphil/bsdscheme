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
    return NilIR.get();
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

class StringIR : IR {
  string value;

  this(string initValue) {
    value = initValue;
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
    default:
      break;
    }

    if (!ctx.contains(symbol)) {
      irError(format("Call to unknown function: %s", symbol));
      assert(0);
    }

    // ctx.set handles returning a unique symbol.
    string returnVariable = ctx.set(symbol, "");
    auto fir = new FuncallIR(symbol, [], returnVariable);

    foreach(arg; listToVector(v[1])) {
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
  IR[] parameters;
  BeginIR block;

  static IR fromAST(Value definition, Value block, Context ctx) {
    auto dir = new DefineFunctionIR;

    auto functionName = car(definition);
    string symbol = valueToSymbol(functionName);
    dir.name = symbol;

    auto arg2 = cdr(definition);
    string[] parameters;

    foreach (i, parameter; listToVector(arg2)) {
      auto args = [new VariableIR(ARGUMENTS), new IntegerIR(i)];
      dir.parameters ~= new FuncallIR("nth", args, valueToString(parameter));
    }

    if (ctx.contains(symbol)) {
      irWarning(format("Shadowing assignment: %s", symbol));
    }
    ctx.set(symbol, format("BSDScheme_%s", symbol), false);
    auto newCtx = ctx.dup();
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
  string returnVariable;

  static BeginIR fromAST(Value value, Context ctx) {
    auto bir = new BeginIR;

    auto vector = listToVector(value);
    foreach (i, arg; vector) {
      bir.expressions ~= IR.fromAST(arg, ctx);
    }

    bir.returnVariable = ctx.set("begin", "");

    return bir;
  }

  override IR getReturnIR() {
    auto length = this.expressions.length;
    if (!length) {
      return NilIR.get();
    }

    auto lastExp = this.expressions[length - 1];
    auto assignment = new AssignmentIR(returnVariable, lastExp);
    return assignment.getReturnIR();
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

    iir.returnVariable = ctx.set("if", "");

    return iir;
  }

  override IR getReturnIR() {
    return new VariableIR(returnVariable);
  }
}
