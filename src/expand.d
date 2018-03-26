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
 *      (if test then '()))))
 *
 * (when #t (display "here\n"))
 */

Nullable!(Value[string]) matchRuleAndBind(Value rule, string[] keywords, Value args) {
  Nullable!(Value[string]) ctx = [" ": nilValue].nullable;

  if (valueIsNil(rule)) {
    return ctx;
  }

  if (valueIsList(rule)) {
    if (!valueIsList(args)) {
      ctx.nullify();
      return ctx;
    }

    auto r1 = car(rule);
    auto a1 = car(args);

    auto carCtx = matchRuleAndBind(car(r1), keywords, car(a1));
    if (carCtx.isNull) {
      return carCtx;
    } else {
      auto cdrCtx = matchRuleAndBind(cdr(r1), keywords, cdr(a1));
      if (cdrCtx.isNull) {
        return cdrCtx;
      }

      foreach (key, value; cdrCtx) {
        carCtx[key] = value;
      }

      return carCtx;
    }
  } else {
    auto rSym = valueToSymbol(rule);

    // Match keyword
    if (keywords.canFind(rSym)) {
      if (valueIsSymbol(args) && valueToSymbol(args) == rSym) {
        ctx.nullify();
        return ctx;
      }

      return ctx;
    }

    switch (rSym) {
    case "_": // Match anything/nothing;
      break;
    case "...": // Match rest
      ctx[rSym] = args;
      break;
    default:
      ctx[rSym] = args;
      break;
    }
  }

  return ctx;
}

Value bindTransformation(Value tfm, Value[string] bindings) {
  if (valueIsNil(tfm)) {
    return tfm;
  } else if (valueIsList(tfm)) {
    auto _car = bindTransformation(car(tfm), bindings);
    auto _cdr = bindTransformation(cdr(tfm), bindings);
    return makeListValue(_car, _cdr);
  } else {
    auto sym = valueToSymbol(tfm);
    if (sym in bindings) {
      return bindings[sym];
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
    foreach (ruleAndTransformation; rules) {
      auto rule = car(ruleAndTransformation);
      auto tfm = car(cdr(ruleAndTransformation));
      auto ctx = matchRuleAndBind(rule, keywords, ast);
      if (!ctx.isNull) {
        return bindTransformation(tfm, ctx);
      }
    }

    exError(format("Syntax error: %s", formatValue(ast)));
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
    exError(format("%s syntax transformer is not supported", transformer));
    assert(0);
  }
}

void defineSyntax(Value ast, ref Extensions extensions) {
  auto dispatcher = valueToString(car(ast));
  auto transformer = cdr(ast);
  extensions[dispatcher] = makeTransformer(transformer);
}

Value expand(Value ast, ref Extensions extensions) {
  if (valueIsList(ast)) {
    auto _car = expand(car(ast), extensions);
    auto _cdr = expand(cdr(ast), extensions);
    return makeListValue(_car, _cdr);
  } else if (valueIsSymbol(ast)) {
    string symbol = valueToSymbol(ast);

    if (symbol in extensions) {
      return expand(extensions[symbol](ast), extensions);
    } else {
      switch (symbol) {
      case "define-syntax":
        defineSyntax(cdr(ast), extensions);
        return nilValue;
      case "syntax-error":
        writeln("Syntax error");
        assert(0);
      default:
        return ast;
      }
    }
  }

  return ast;
}
