import std.file;

import lex : lex, StringBuffer, Token;
import parse : parse, SExp;
import runtime;
import utility;
import value;

Value interpret(SExp* sexp, Context ctx, bool topLevel) {
  if (sexp is null) {
    return nilValue;
  }

  bool isPrimitive = sexp.sexps is null;
  if (isPrimitive) {
    Value v = atomToValue(sexp.atom);

    if (valueIsSymbol(v)) {
      return ctx.get(valueToSymbol(v));
    }

    return v;
  }

  Value[] vs;

  if (sexp.sexps !is null) {
    if (topLevel) {
      foreach (_sexp; sexp.sexps) {
        vs ~= interpret(_sexp, ctx);
      }
    } else {
      auto head = interpret(sexp.sexps[0], ctx);
      auto tail = sexp.sexps[1 .. sexp.sexps.length];

      if (!valueIsNil(head)) {
        if (valueIsFunction(head)) {
          auto fn = valueToFunction(head);
          vs ~= fn(tail, ctx);
        } else {
          error("Call of non-procedure", head);
        }
      } else {
        // TODO: handle this: ((identity +) 1 2)
      }
    }
  }

  if (vs.length == 0) {
    return nilValue;
  } else {
    return vs[vs.length - 1];
  }
}

Value interpret(SExp* sexp, Context ctx) {
  return interpret(sexp, ctx, false);
}

int interpretFile(string filename) {
  char[] source = cast(char[])read(filename);
  auto tokens = lex(new StringBuffer(source));

  auto ctx = new Context;
  auto buffer = tokens.buffer;
  while (buffer.length > 0) {
    Token*[] filteredBuffer;
    foreach (token; buffer) {
      if (token !is null) {
        filteredBuffer ~= token;
      }
    }

    auto parsed = parse(filteredBuffer);
    auto value = interpret(parsed[1], ctx, true);
    buffer = parsed[0];
  }

  return 0;
}
