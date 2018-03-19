import std.array;
import std.format;
import std.stdio;

import ir;

void cgError(string error) {
  throw new Exception(format("[CG][ERROR]: %s", error));
}

void cgWarning(string warning) {
  writeln(format("[CG][WARNING]: %s", warning));
}

class CG {
  static string fromIR(IR ir, bool topLevel) {
    if (auto sir = cast(LiteralIR!string)ir) {
      return format("makeStringValue(\"%s\")", sir.value);
    } else if (auto bir = cast(LiteralIR!bool)ir) {
      return format("makeBoolValue(%b)", bir.value);
    } else if (auto cir = cast(LiteralIR!char)ir) {
      return format("makeCharValue(%c)", cir.value);
    } else if (auto iir = cast(LiteralIR!long)ir) {
      return format("makeIntegerValue(%d)", iir.value);
    } else if (auto nir = cast(NilIR)ir) {
      return "nilValue";
    } else if (auto fir = cast(FuncallIR)ir) {
      return FuncallCG.fromIR(fir);
    } else if (auto dir = cast(DefineFunctionIR)ir) {
      return DefineFunctionCG.fromIR(dir);
    } else if (auto dir = cast(DefineIR)ir) {
      return DefineCG.fromIR(dir);
    } else if (auto bir = cast(BeginIR)ir) {
      return BeginCG.fromIR(bir, topLevel);
    } else if (auto iir = cast(IfIR)ir) {
      return IfCG.fromIR(iir);
    } else if (auto vir = cast(VariableIR)ir) {
      return VariableCG.fromIR(vir);
    } else if (auto air = cast(AssignmentIR)ir) {
      return AssignmentCG.fromIR(air);
    } else {
      cgError(format("Invalid IR."));
      assert(0);
    }
  }
}

class FuncallCG : CG {
  static string fromIR(FuncallIR fir) {
    string[] argInitializers;
    string[] args;
    
    foreach(arg; fir.arguments) {
      if (cast(FuncallIR)arg) {
        argInitializers ~= CG.fromIR(arg, false);
      }
      args ~= CG.fromIR(arg.getReturnIR(), false);
    }

    string initializers = argInitializers.join(";\n\t");
    if (argInitializers.length) {
      initializers ~= ";\n\t";
    }

    return format("%s\n\tValue %s = %s(vectorToList([%s]), null)",
                  initializers,
                  fir.returnVariable,
                  fir.name,
                  args.join(", "));
  }
}

class DefineFunctionCG : CG {
  static string fromIR(DefineFunctionIR fir) {
    

    string functionHeader = format("Value %s(Value %s, void** ctx) {", fir.name, ARGUMENTS);
    string functionFooter = format("}\n");


    string block = format("\n\tValue[] %s = listToVector(%s);\n\t", fir.tmp, ARGUMENTS);
    foreach (i, parameter; fir.parameters) {
      block ~= format("Value %s = %s[%d];\n\t", parameter, fir.tmp, i);
    }

    block ~= BeginCG.fromIR(fir.block, false);

    block ~= format(";\n\treturn %s;\n", CG.fromIR(fir.getReturnIR(), false));

    return format("%s%s%s", functionHeader, block, functionFooter);
  }
}

class BeginCG : CG {
  static string fromIR(BeginIR bir, bool topLevel) {
    string[] block;

    if (bir.expressions.length) {
      foreach (expression; bir.expressions) {
        block ~= CG.fromIR(expression, false);
      }
    }

    if (topLevel) {
      return block.join("\n");
    }
    return block.join(";\n\t");
  }
}

class DefineCG : CG {
  static string fromIR(DefineIR dir) {
    // TODO: support global initialization
    return CG.fromIR(dir.value, false);
  }
}

class IfCG : CG {
  static string fromIR(IfIR iir) {
    string init = CG.fromIR(iir.test, false);

    return format("%s;\n\tValue %s;\n\tif (valueToBool(%s)) {\n\t%s;\n\t%s = %s;\n\t} else {\n\t%s;\n\t%s = %s;\n\t}",
                  init,
                  iir.returnVariable,
                  CG.fromIR(iir.test.getReturnIR(), false),
                  CG.fromIR(iir.ifThen, false),
                  iir.returnVariable,
                  CG.fromIR(iir.ifThen.getReturnIR(), false),
                  CG.fromIR(iir.ifElse, false),
                  iir.returnVariable,
                  CG.fromIR(iir.ifElse.getReturnIR(), false));
  }
}

class VariableCG : CG {
  static string fromIR(VariableIR vir) {
    return vir.name;
  }
}

class AssignmentCG : CG {
  static string fromIR(AssignmentIR air) {
    return format("%s%s = %s",
                  air.shadowing ? "" : "Value ",
                  air.assignTo,
                  CG.fromIR(air.value, false));
  }
}
