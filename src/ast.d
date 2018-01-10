import std.bigint;
import std.conv;
import std.math;
import std.string;
import std.typecons;
import std.stdio;

static const long WORD_SIZE = 64;
static const int HEADER_TAG_WIDTH = WORD_SIZE / 8;

enum ASTTag {
  Nil,
  Integer,
  Bool,
  BigInteger,
  String,
  Symbol,
  List,
  Vector,
  Unused1,
}

struct AST {
  long header;
  long data;
}

string formatAst(AST v) {
  switch (tagOfAst(v)) {
  case ASTTag.Integer:
    return to!(string)(astToInteger(v));
  case ASTTag.Bool:
    return astToBool(v) ? "#t" : "#f";
  case ASTTag.Symbol:
    return astToSymbol(v);
  case ASTTag.String:
    return astToString(v);
  case ASTTag.Nil:
    return "()";
  case ASTTag.BigInteger:
    return astToBigInteger(v).toDecimalString();
  case ASTTag.List:
    auto fmt = "(";
    auto tuple = astToList(v);

    while (true) {
      fmt = format("%s%s", fmt, formatAst(tuple[0]));

      if (astIsList(tuple[1])) {
        tuple = astToList(tuple[1]);
        fmt = format("%s ", fmt);
      } else if (astIsNil(tuple[1])) {
        break;
      } else {
        fmt = format("%s . %s", fmt, formatAst(tuple[1]));
        break;
      }
    }

    return format("%s)", fmt);
    break;
  default:
    // TODO: support vector
    return "<unknown object>";
  }
}

ASTTag tagOfAst(ref AST v) {
  return cast(ASTTag)(v.header & (pow(2, HEADER_TAG_WIDTH) - 1));
}

bool isAst(ref AST v, ASTTag vt) {
  return tagOfAst(v) == vt;
}

bool astIsNil(ref AST v) { return isAst(v, ASTTag.Nil); }

AST makeIntegerAst(long i) {
  AST v = { data: i, header: ASTTag.Integer };
  return v;
}

bool astIsInteger(ref AST v) { return isAst(v, ASTTag.Integer); }

long astToInteger(ref AST v) {
  return cast(long)v.data;
}

AST makeBoolAst(bool b) {
  AST v = { data: b, header: ASTTag.Bool };
  return v;
}

bool astIsBool(ref AST v) { return isAst(v, ASTTag.Bool); }

bool astToBool(ref AST v) {
  return cast(bool)v.data;
}

AST makeBigIntegerAst(BigInt i) {
  AST v = { data: cast(long)new BigInt(i), header: ASTTag.BigInteger };
  return v;
}

bool astIsBigInteger(ref AST v) { return isAst(v, ASTTag.BigInteger); }

BigInt astToBigInteger(ref AST v) {
  return *cast(BigInt*)v.data;
}

static const long MAX_AST_LENGTH = (long.sizeof * 8) - 1;

Tuple!(void*, ulong) copyString(string s) {
  ulong size = s.length + 1 > MAX_AST_LENGTH ? MAX_AST_LENGTH : s.length + 1;

  auto heapString = new char[size];
  foreach (i, c; s[0 .. size - 1]) {
    heapString[i] = c;
  }
  heapString[size - 1] = '\0';
  return Tuple!(void*, ulong)(cast(void*)heapString, size);
}

AST makeStringAst(string s) {
  auto string = copyString(s);
  AST v = { data: cast(long)string[0], header: string[1] << HEADER_TAG_WIDTH | ASTTag.String };
  return v;
}

bool astIsString(ref AST v) { return isAst(v, ASTTag.String); }

string astToString(ref AST v) {
  return fromStringz(cast(char*)v.data).dup;
}

AST makeSymbolAst(string s) {
  AST v = makeStringAst(s);
  v.header >>= HEADER_TAG_WIDTH;
  v.header <<= HEADER_TAG_WIDTH;
  v.header |= ASTTag.Symbol;
  return v;
}

bool astIsSymbol(ref AST v) { return isAst(v, ASTTag.Symbol); }

string astToSymbol(ref AST v) {
  return astToString(v);
}

AST makeListAst(ref AST head, ref AST tail) {
  AST v;
  v.header = ASTTag.List;
  AST** tuple = cast(AST**)new AST*[2];
  foreach (i, item; [head, tail]) {
    tuple[i] = new AST;
    tuple[i].header = item.header;
    tuple[i].data = item.data;
  }
  v.data = cast(long)tuple;
  return v;
}

bool astIsList(ref AST v) { return isAst(v, ASTTag.List); }

Tuple!(AST, AST) astToList(AST v) {
  AST** m = cast(AST**)v.data;
  return Tuple!(AST, AST)(*m[0], *m[1]);
}

AST makeVectorAst(AST[] v) {
  ulong size = v.length > MAX_AST_LENGTH ? MAX_AST_LENGTH : v.length;
  AST ve = { data: cast(long)v.ptr, header: size << HEADER_TAG_WIDTH | ASTTag.Vector };
  return ve;
}

bool astIsVector(ref AST v) { return isAst(v, ASTTag.Vector); }

AST[] astToVector(ref AST v) {
  return *cast(AST[]*)v.data;
}
