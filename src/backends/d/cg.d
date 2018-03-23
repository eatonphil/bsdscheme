import std.array;
import std.format;
import std.stdio;
import std.string;

import ir;

void cgError(string error) {
  throw new Exception(format("[CG][ERROR]: %s", error));
}

void cgWarning(string warning) {
  writeln(format("[CG][WARNING]: %s", warning));
}

bool nonLiteral(IR arg) {
  return cast(VariableIR)arg is null &&
    cast(LiteralIR!string)arg is null &&
    cast(LiteralIR!long)arg is null &&
    cast(LiteralIR!bool)arg is null &&
    cast(LiteralIR!char)arg is null;
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
    } else if (auto lir = cast(LetXIR)ir) {
      return LetCG.fromIR(lir);
    } else if (auto mir = cast(MapIR)ir) {
      return MapCG.fromIR(mir);
    } else if (auto lir = cast(ListIR)ir) {
      return ListCG.fromIR(lir);
    } else if (auto qir = cast(QuoteIR)ir) {
      return QuoteCG.fromIR(qir);
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

    string fnInit = fir.init is null ? "" : format("%s;\n\t", CG.fromIR(fir.init, false));
    
    foreach (arg; fir.arguments) {
      if (nonLiteral(arg)) {
        argInitializers ~= CG.fromIR(arg, false);
      }
      args ~= CG.fromIR(arg.getReturnIR(), false);
    }

    string initializers = argInitializers.join(";\n\t");
    if (argInitializers.length) {
      initializers ~= ";\n\t";
    }

    return format("%s%s\n\tValue %s = %s(vectorToList([%s]), null)",
                  fnInit,
                  initializers,
                  fir.returnVariable,
                  fir.name,
                  args.join(", "));
  }
}

class DefineFunctionCG : CG {
  static string fromIR(DefineFunctionIR fir) {
    string functionHeader = format("Value %s(Value %s, void** ctx) {\n\t", fir.name, ARGUMENTS);
    string functionFooter = format("}\n");

    string block = fir.parameters.length ?
      format("Value[] %s = listToVector(%s);\n\t", fir.tmp, ARGUMENTS) :
      "";
    foreach (i, parameter; fir.parameters) {
      block ~= format("Value %s = %s[%d];\n\t", parameter, fir.tmp, i);
    }

    block ~= BeginCG.fromIR(fir.block, false);
    block ~= format(";\n\treturn %s;\n", CG.fromIR(fir.block.getReturnIR(), false));

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
    string init = nonLiteral(iir.test) ? CG.fromIR(iir.test, false) : "";

    return format("%s;\n\tValue %s;\n\tif (truthy(%s)) {\n\t%s;\n\t%s = %s;\n\t} else {\n\t%s;\n\t%s = %s;\n\t}",
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
    string init = nonLiteral(air.value) ?
      format("%s;\n\t", CG.fromIR(air.value, false)) :
      "";

    return format("%s%s%s = %s",
                  init,
                  air.shadowing ? "" : "Value ",
                  air.assignTo,
                  CG.fromIR(air.value.getReturnIR(), false));
  }
}

class LetCG : CG {
  static string fromIR(LetXIR lir) {
    string[] assignments;

    foreach (asn; lir.assignments) {
      assignments ~= CG.fromIR(asn, false);
    }

    return format("%s;\n\t%s",
                  assignments.join(";\n\t"),
                  BeginCG.fromIR(lir.block, false));
  }
}

class MapCG : CG {
  static string fromIR(MapIR mir) {
    string init = nonLiteral(mir.list) ? CG.fromIR(mir.list, false) : "";
    string tmp = format("Value[] %s", mir.tmp);
    string foreachHeaderBody =
      format("foreach (item; listToVector(%s)) {\n\t",
             CG.fromIR(mir.list.getReturnIR(), false)) ~
      format("%s ~= %s(makeListValue(item, nilValue), null)",
             mir.tmp, CG.fromIR(mir.fn, false));
    string foreachFooter = format("}\n\tValue %s = vectorToList(%s)",
                                  mir.returnVariable, mir.tmp);
    return [init, tmp, foreachHeaderBody, foreachFooter].join(";\n\t");
  }
}

class ListCG : CG {
  static string fromIR(ListIR lir) {
    string[] inits;
    string[] returns;

    foreach (e; lir.list) {
      if (nonLiteral(e)) {
        inits ~= CG.fromIR(e, false);
      }
      returns ~= CG.fromIR(e.getReturnIR(), false);
    }

    string init = inits.join(";\n\t") ~ (inits.length ? ";\n\t" : "");

    return format("%sValue %s = vectorToList([%s])",
                  init,
                  lir.returnVariable,
                  returns.join(", "));
  }
}

class QuoteCG : CG {
  static string fromIR(QuoteIR qir) {
    auto safeSerialized = qir.serialized.translate(['"': "\\\""]);
    return format("Value %s = car(read(\"%s\".dup))", qir.tmp, safeSerialized);
  }
}
