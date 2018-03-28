import std.algorithm.searching;
import std.format;
import std.stdio;
import std.typecons;

import utility;
import value;

void exError(string error) {
  throw new Exception(format("[EX][ERROR]: %s", error));
}

void exWarning(string warning) {
  writeln(format("[EX][WARNING]: %s", warning));
}

alias Extension = Value delegate(Value);
alias Extensions = Extension[string];

/*
 * (define-syntax (when)
 *   (syntax-rules ()
 *     ((_ test then ...)
 *      (if test (begin then ...) '())))))
 *
 * (when #t (display "here\n"))
 */

bool matchRuleAndBind(Value rule, string[] keywords, Value args, ref Value[][string] ctx) {
  if (valueIsNil(rule)) {
    if (!valueIsNil(args)) {
      return false;
    }

    return true;
  }

  if (valueIsList(rule)) {
    auto a1 = args;
    if (valueIsList(args)) {
      a1 = car(args);
    }

    auto r1 = car(rule);

    auto ellipsisMatched = false;
    if (valueIsSymbol(r1)) {
      auto sym = valueToSymbol(r1);
      if (sym == "...") {
        if (sym !in ctx) {
          ctx["..."] = [];
          ellipsisMatched = true;
        }

        ctx["..."] ~= args;

        return true;
      }
    }

    if (!matchRuleAndBind(r1, keywords, a1, ctx)) {
      return false;
    }

    if (valueIsList(args) && !matchRuleAndBind(cdr(rule), keywords, cdr(args), ctx)) {
      return false;
    }

    return true;
  } else {
    auto rSym = valueToSymbol(rule);

    // Match keyword
    if (keywords.canFind(rSym)) {
      if (valueIsSymbol(args) && valueToSymbol(args) == rSym) {
        return false;
      }

      return true;
    }

    switch (rSym) {
    case "_": // Match anything/nothing;
      return true;
    case "...":
      // Already handled in the above case.
      return true;
    default:
      ctx[rSym] = [args];
      return true;
    }
  }

  return false;
}

Value bindTransformation(Value tfm, Value[][string] bindings) {
  if (valueIsNil(tfm)) {
    return tfm;
  } else if (valueIsList(tfm)) {
    auto _car = bindTransformation(car(tfm), bindings);
    auto _cdr = bindTransformation(cdr(tfm), bindings);

    if (valueIsList(_cdr)) {
      auto cadr = car(cdr(tfm));
      if (valueIsSymbol(cadr) && valueToSymbol(cadr) == "...") {
        if ("..." !in bindings) {
          exError(format("No matching ellipsis to bind near '%s'", formatValue(tfm)));
          assert(0);
        }

        if (bindings["..."].length == 1) {
          bindings["..."] = [];
        } else {
          bindings["..."] = bindings["..."][1 .. bindings["..."].length];
        }
        return appendList(makeListValue(_car, nilValue), car(_cdr));
      }
    }
    return makeListValue(_car, _cdr);
  } else {
    auto sym = valueToSymbol(tfm);
    if (sym in bindings) {
      return bindings[sym][0];
    }

    return tfm;
  }
}

Extension syntaxRules(Value ast) {
  auto _keywords = listToVector(car(ast));
  auto rules = listToVector(cdr(ast));
  string[] keywords;

  foreach (k; _keywords) {
    keywords ~= valueToSymbol(k);
  }

  return delegate Value (Value ast) {
    foreach (i, ruleAndTransformation; rules) {
      auto rule = car(ruleAndTransformation);
      auto tfm = car(cdr(ruleAndTransformation));
      Value[][string] ctx = [" ": [nilValue]];
      auto matched = matchRuleAndBind(rule, keywords, ast, ctx);
      if (matched) {
        return bindTransformation(tfm, ctx);
      }
    }

    exError(format("Syntax did not match any patterns: %s", formatValue(ast)));
    assert(0);
  };
}

Extension makeTransformer(Value transformerAst) {
  auto _cdr = cdr(transformerAst);
  auto transformer = valueToString(car(transformerAst));
  switch (transformer) {
  case "syntax-rules":
    return syntaxRules(_cdr);
  default:
    exError(format("%s syntax transformer is not supported: ", formatValue(transformerAst)));
    assert(0);
  }
}

void defineSyntax(Value ast, ref Extensions extensions) {
  auto dispatcher = valueToString(car(ast));
  auto transformer = car(cdr(ast));
  extensions[dispatcher] = makeTransformer(transformer);
}

Value _expand(Value ast, ref Extensions extensions) {
  if (valueIsList(ast)) {
    if (valueIsSymbol(car(ast))) {
      auto sym = valueToSymbol(car(ast));
      switch (sym) {
      case "define-syntax":
        defineSyntax(cdr(ast), extensions);
        return nilValue;
      case "let-syntax":
        writeln("let-syntax not supported yet");
        assert(0);
      case "letrec-syntax":
        writeln("letrec-syntax not supported yet");
        assert(0);
      case "syntax-error":
        writeln("Syntax error");
        assert(0);
      default:
        if (sym in extensions) {
          return _expand(extensions[sym](ast), extensions);
        }
      }
    }

    auto _car = _expand(car(ast), extensions);
    auto _cdr = _expand(cdr(ast), extensions);
    return makeListValue(_car, _cdr);
  }

  return ast;
}

Value expand(Value ast) {
  Value delegate(Value)[string] syntaxExtensions;

  // Filter out nilValues in top-level
  auto values = listToVector(_expand(ast, syntaxExtensions));
  Value[] r;
  foreach (v; values) {
    if (valueIsNil(v)) {
      continue;
    }

    r ~= v;
  }

  return vectorToList(r);
}
