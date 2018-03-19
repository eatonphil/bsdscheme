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
  static string fromIR(IR ir) {
    if (auto sir = cast(StringIR)ir) {
      return format("makeStringValue(\"%s\")", sir.value);
    } else if (auto bir = cast(BooleanIR)ir) {
      return format("makeBoolValue(%b)", bir.value);
    } else if (auto cir = cast(CharacterIR)ir) {
      return format("makeCharValue(%c)", cir.value);
    } else if (auto iir = cast(IntegerIR)ir) {
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
      return BeginCG.fromIR(bir);
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
    string[] args;

    foreach(arg; fir.arguments) {
      args ~= CG.fromIR(arg);
    }

    return format("Value %s = %s(%s, null)",
                  fir.returnVariable,
                  fir.name,
                  args.join(", "));
  }
}

class DefineFunctionCG : CG {
  static string fromIR(DefineFunctionIR fir) {
    string functionHeader = format("Value %s(%s) {\n");
    string functionFooter = format("}\n");

    string block = "\t";
    foreach (parameter; fir.parameters) {
      block ~= CG.fromIR(parameter);
      block ~= ";\n\t";
    }

    block ~= BeginCG.fromIR(fir.block);

    block ~= format("\treturn %s;\n", CG.fromIR(fir.getReturnIR()));

    return format("%s%s%s", functionHeader, block, functionFooter);
  }
}

class BeginCG : CG {
  static string fromIR(BeginIR bir) {
    string[] block;

    if (bir.expressions.length) {
      foreach (expression; bir.expressions) {
        block ~= CG.fromIR(expression);
      }
    }

    block ~= CG.fromIR(bir.getReturnIR());

    return block.join(";\n\t");
  }
}

class DefineCG : CG {
  static string fromIR(DefineIR dir) {
    // TODO: support global initialization
    return CG.fromIR(dir.value);
  }
}

class IfCG : CG {
  static string fromIR(IfIR iir) {
    return format("\tValue %s;\n\tif (%s) {\n\t%s;\n\t%s = %s\n} else {\n\t%s;\n\t%s = %s\n}",
                  iir.returnVariable,
                  CG.fromIR(iir.test),
                  CG.fromIR(iir.ifThen),
                  iir.returnVariable,
                  iir.ifThen.getReturnIR(),
                  CG.fromIR(iir.ifElse),
                  iir.returnVariable,
                  iir.ifElse.getReturnIR());
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
                  CG.fromIR(air.value));
  }
}
