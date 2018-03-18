import ir;

class CG {
  static CG fromIR(IR ir, bool mustReturn) {
    if (ir instanceof StringIR ||
        ir instanceof IntegerIR ||
        ir instanceof CharacterIR ||
        ir instanceof BooleanIR) {
      return LiteralCG.fromIR(ir, mustReturn);
    } else if (ir instanceof FuncallIR) {
      return FuncallCG.fromIR(cast(FuncallIR)ir, mustReturn);
    } else if (ir instanceof DefineFunctionIR) {
      return DefineFunctionCG.fromIR(cast(DefineFunctionIR)ir, mustReturn);
    } else if (ir instanceof DefineIR) {
      return DefineCG.fromIR(cast(DefineIR)ir, mustReturn);
    } else if (ir instanceof BeginIR) {
      return BeginCG.fromIR(cast(BeginIR)ir, mustReturn);
    } else if (ir instanceof IfIR) {
      return IfCG.fromIR(cast(IfIR)ir, mustReturn);
    } else if (ir instanceof VariableIR) {
      return VariableCG.fromIR(cast(VariableIR)ir, mustReturn);
    } else if (ir instanceof AssignmentIR) {
      return AssignmentCG.fromIR(cast(AssignmentIR)ir, mustReturn);
    } else {
      compileError(format("Invalid IR."));
      assert(0);
    }
  }
}

class DefineFunctionCG : CG {
  static string fromIR(DefineFunctionIR fir, bool mustReturn) {
    string functionHeader = format("Value %s(%s) {\n");
    string functionFooter = format("}\n");

    string block = fir.expressions.join(";\n\t");
    block ~= BeginCG.fromIR(fir.block);

    block ~= 

    return format("%s%s%s", functionHeader, block, functionFooter);
  }
}

class BeginCG : CG {
  static string fromIR(BeginIR bir, bool mustReturn) {
    string[] block;

    if (bir.expressions.length) {
      foreach (i, expression; bir.expressions) {
        lastExpression = expression;
        block ~= CG.fromIR();
      }
    }

    block ~= CG.fromIR(bir.getReturnIR());

    return block.join(";\n\t");
  }
}
