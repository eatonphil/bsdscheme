import core.stdc.stdlib;
import std.format;
import std.stdio;

import parse;
import runtime;
import value;

void print(SExp* sexp) {
  if (sexp is null) {
    return;
  }

  if (sexp.atom !is null) {
    writef("%s ", sexp.atom.value);
    return;
  }

  if (sexp.sexps !is null) {
    writef("(");
    foreach (ref _sexp; sexp.sexps) {
      print(_sexp);
    }
    writef(")");
  }
}

void error(string msg, Value value) {
  writeln(format("[ERROR] %s: %s", msg, stringOfValue(value)));
  exit(1);
}
