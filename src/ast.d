import std.bigint;
import std.conv;
import std.math;
import std.string;
import std.typecons;
import std.stdio;

static const long WORD_SIZE = 64;
static const int HEADER_TAG_WIDTH = 8;

enum ASTTag {
  Nil,
  Integer,
  Char,
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
  case ASTTag.Char:
    return format("#\\%c", astToChar(v));
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
  case ASTTag.Vector:
    auto vector = astToVector(v);
    auto fmt = format("#(%s", formatAst(vector[0]));

    foreach (AST i; vector[1 .. vector.length]) {
      fmt = format("%s %s", fmt, formatAst(i));
    }

    return format("%s)", fmt);
    break;
  default:
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

AST makeCharAst(char c) {
  AST v = { data: c, header: ASTTag.Char };
  return v;
}

bool astIsChar(ref AST v) { return isAst(v, ASTTag.Char); }

char astToChar(ref AST v) {
  return cast(char)v.data;
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

static const ulong MAX_VALUE_LENGTH = pow(2, WORD_SIZE) - 1;

Tuple!(void*, ulong) copyString(string s) {
  ulong size = s.length + 1 > MAX_VALUE_LENGTH ? MAX_VALUE_LENGTH : s.length + 1;

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

char* astToByteVector(ref AST v) {
  return cast(char*)v.data;
}

string astToString(ref AST v) {
  return fromStringz(astToByteVector(v)).dup;
}

void updateAstString(AST v, long index, char c) {
  auto vector = astToByteVector(v);
  vector[index] = c;
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
  ulong size = v.length > MAX_VALUE_LENGTH ? MAX_VALUE_LENGTH : v.length;
  AST[] vCopy = new AST[v.length];
  foreach (i, e; v) {
    vCopy[i] = e;
  }

  AST ve = { data: cast(long)vCopy.ptr, header: size << HEADER_TAG_WIDTH | ASTTag.Vector };
  return ve;
}

bool astIsVector(ref AST v) { return isAst(v, ASTTag.Vector); }

AST[] astToVector(ref AST v) {
  long size = v.header >> HEADER_TAG_WIDTH;
  AST[] vector;
  vector = (cast(AST*)v.data)[0 .. size];
  return vector;
}

void updateAstVector(AST v, long index, AST element) {
  auto vector = astToVector(v);
  vector[index] = element;
}
