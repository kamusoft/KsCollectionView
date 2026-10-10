"""本体のソースから、公開の宣言の行を拾う。

利用者向け Skill の追従の道具 (skills-refresh.py・check-api-coverage.py) が共有する。文法を解く
道具は使わず、コメントと文字列の中身を空白に置き換えた行を、1 行ずつ読む。

拾うもの

  iOS (Swift)
    - public (または open) と書かれた struct・enum・class・actor・protocol・typealias・
      associatedtype・func・var・let の行。名前を持つ
    - public と書かれた init・subscript の行。名前を持たない (行としてだけ数える)
    - public の enum の中の case の行。case は public と書かれないので、enum の囲みの
      直下の行から拾う
    - public の extension と public の protocol の直下の、可視性の書かれていない
      func・var・let などの行 (書かなくても公開になるため)

  Android (Kotlin)
    - public と書かれた class・object・interface・typealias・fun・val・var の行。名前を持つ。
      1 行に複数あれば、すべて拾う (クラスの宣言と同じ行に書かれたプロパティなど)
    - public と書かれた constructor と、名前の無い companion object の行。名前を持たない
    - public の enum class の中の値の行。値は public と書かれないので、囲みの直下の、
      最初の ";" までの行から拾う
    - public の class の、最初のコンストラクタの引数のうち val・var の付いたもの。public と
      書かれていなくても公開になるので拾う (private・internal・protected の付いたものは拾わない)

拾わないもの

  - 引数の名前
  - iOS の、@_spi(...) の付いた公開の宣言と、その型の囲みの中の宣言 (利用者向けでない印)

拾い方の限界 (この形がソースに現れたら、拾い方を直すか、人が目で確かめる)

  - 複数行にわたる宣言は、名前のある行だけを拾う。続きの行 (引数の並びなど) は拾わない
  - 公開でない型の囲みの中に public と書かれた宣言があっても、拾う (外側の型の可視性を見ない)
  - 公開でない型の extension の中の public の宣言も、拾う
  - Swift の case を複数行に分けて並べたときの、2 行目から後の値は拾わない
  - 条件付きコンパイル (#if) の中かどうかは見ない
  - 文字列の中に引用符を含む式を埋め込んだ行は、文字列の終わりを取り違えることがある
    (取り違えは、その行の中で終わる)
  - 演算子の func のように、名前を読み取れない public の行は、宣言として拾わずに、
    読み取れなかった行として別に返す
"""

from __future__ import annotations

import dataclasses
import os
import re

KIND_TYPE = "型"
KIND_FUNCTION = "関数"
KIND_PROPERTY = "プロパティ"
KIND_ENUM_VALUE = "列挙の値"
KIND_INITIALIZER = "初期化"
KIND_SUBSCRIPT = "添字"
KIND_COMPANION = "companion object"


@dataclasses.dataclass(frozen=True)
class Platform:
    key: str
    title: str
    # 本体のソースの置き場。リポジトリのルートからの "/" 区切りの相対のパス。
    source_root: str
    extension: str
    # このプラットフォームの Skill のディレクトリの名前。
    skill: str


PLATFORMS = (
    Platform("ios", "iOS", "ios/Sources", ".swift", "kscollectionview-ios"),
    Platform("android", "Android", "android/kscollectionview/src/main", ".kt", "kscollectionview-android"),
)
PLATFORM_KEYS = tuple(platform.key for platform in PLATFORMS)


@dataclasses.dataclass(frozen=True)
class Declaration:
    # リポジトリのルートからの "/" 区切りの相対のパス。
    path: str
    line: int
    kind: str
    # 名前を持たない宣言 (初期化など) は None。
    name: str | None
    # 宣言を囲む、公開の型の名前。"." でつなぐ。最上位なら空の文字列。
    owner: str
    # ソースの行の文面 (前後の空白を除いたもの)。
    text: str


@dataclasses.dataclass(frozen=True)
class Unparsed:
    """public と書かれているのに、宣言として読み取れなかった行。"""

    path: str
    line: int
    text: str


@dataclasses.dataclass(frozen=True)
class Extraction:
    declarations: tuple[Declaration, ...]
    unparsed: tuple[Unparsed, ...]

    def names(self) -> dict[str, list[Declaration]]:
        """名前 → その名前を持つ宣言 の対応を返す。"""
        found: dict[str, list[Declaration]] = {}
        for declaration in self.declarations:
            if declaration.name is not None:
                found.setdefault(declaration.name, []).append(declaration)
        return found

    def lines(self) -> list[tuple[str, int, str]]:
        """宣言の行を、(パス, 行の番号, 文面) の並びで返す。同じ行は 1 回だけ数える。"""
        seen: dict[tuple[str, int], str] = {}
        for declaration in self.declarations:
            seen.setdefault((declaration.path, declaration.line), declaration.text)
        return [(path, line, text) for (path, line), text in seen.items()]


def platform_of(key: str) -> Platform:
    for platform in PLATFORMS:
        if platform.key == key:
            return platform
    raise KeyError(key)


def platform_for_path(path: str) -> Platform | None:
    """パスが本体のソースなら、そのプラットフォームを返す。"""
    for platform in PLATFORMS:
        if path.startswith(platform.source_root + "/") and path.endswith(platform.extension):
            return platform
    return None


# ---- コメントと文字列の中身を除く ----

CHARACTER_LITERAL = re.compile(r"'(?:\\.|[^'\\])'")


def code_lines(text: str) -> list[str]:
    """コメントを除き、文字列の中身を空白に置き換えた行を返す。行の数は変えない。"""
    lines: list[str] = []
    # 入れ子にできるブロックコメントの深さ。
    block_depth = 0
    in_multiline_string = False
    for raw in text.splitlines():
        out: list[str] = []
        in_string = False
        index = 0
        while index < len(raw):
            two, three = raw[index : index + 2], raw[index : index + 3]
            if block_depth:
                if two == "*/":
                    block_depth -= 1
                    index += 2
                elif two == "/*":
                    block_depth += 1
                    index += 2
                else:
                    index += 1
                out.append(" ")
            elif in_multiline_string:
                if three == '"""':
                    in_multiline_string = False
                    out.append('"""')
                    index += 3
                else:
                    out.append(" ")
                    index += 1
            elif in_string:
                if raw[index] == "\\":
                    out.append("  ")
                    index += 2
                elif raw[index] == '"':
                    in_string = False
                    out.append('"')
                    index += 1
                else:
                    out.append(" ")
                    index += 1
            elif two == "//":
                break
            elif two == "/*":
                block_depth = 1
                out.append(" ")
                index += 2
            elif three == '"""':
                in_multiline_string = True
                out.append('"""')
                index += 3
            elif raw[index] == '"':
                in_string = True
                out.append('"')
                index += 1
            else:
                literal = CHARACTER_LITERAL.match(raw, index)
                if literal:
                    out.append("' '")
                    index = literal.end()
                else:
                    out.append(raw[index])
                    index += 1
        lines.append("".join(out))
    return lines


# ---- 行から宣言を読む ----

IDENTIFIER = r"`?[A-Za-z_]\w*`?"
LEADING_IDENTIFIER = re.compile(rf"\s*({IDENTIFIER})")
PUBLIC_WORD = re.compile(r"(?<![.\w@])public\b")
RESTRICTED_WORD = re.compile(r"\b(?:private|fileprivate|internal|protected)\b")

SWIFT_ATTRIBUTES = r"(?:@\w+(?:\([^)]*\))?\s+)*"
SWIFT_MODIFIERS = (
    r"(?:(?:static|class|final|nonisolated|mutating|nonmutating|override|indirect|lazy|weak|dynamic"
    r"|convenience|required|unowned)\s+)*"
)
SWIFT_KEYWORDS = r"struct|enum|class|actor|protocol|extension|typealias|associatedtype|func|var|let|init|subscript"
SWIFT_PUBLIC = re.compile(
    r"^(?P<indent>\s*)"
    + SWIFT_ATTRIBUTES
    + SWIFT_MODIFIERS
    + r"(?:public|open)\s+(?:(?:private|fileprivate|internal)\(set\)\s+)?"
    + SWIFT_MODIFIERS
    + rf"(?P<keyword>{SWIFT_KEYWORDS})\b(?P<rest>.*)$"
)
# 可視性の書かれていない宣言。書かなくても公開になる囲み (public の extension・protocol) の直下で使う。
SWIFT_IMPLICIT = re.compile(
    r"^\s*" + SWIFT_ATTRIBUTES + SWIFT_MODIFIERS + rf"(?P<keyword>{SWIFT_KEYWORDS})\b(?P<rest>.*)$"
)
SWIFT_EXTENSION = re.compile(r"^\s*extension\s+(?P<name>[A-Za-z_]\w*)")
SWIFT_CASE = re.compile(r"^\s*(?:indirect\s+)?case\s+(?P<rest>.+)$")
SWIFT_SPI = "@_spi("
SWIFT_KINDS = {
    "struct": KIND_TYPE,
    "enum": KIND_TYPE,
    "class": KIND_TYPE,
    "actor": KIND_TYPE,
    "protocol": KIND_TYPE,
    "typealias": KIND_TYPE,
    "associatedtype": KIND_TYPE,
    "func": KIND_FUNCTION,
    "var": KIND_PROPERTY,
    "let": KIND_PROPERTY,
    "init": KIND_INITIALIZER,
    "subscript": KIND_SUBSCRIPT,
}
SWIFT_SCOPE_KEYWORDS = ("struct", "enum", "class", "actor", "protocol", "extension")

KOTLIN_MODIFIERS = (
    "abstract|open|final|sealed|data|enum|annotation|value|inner|inline|infix|operator|suspend|tailrec"
    "|external|override|lateinit|const|companion|expect|actual|fun"
)
KOTLIN_PUBLIC = re.compile(
    rf"(?<![.\w@])public\s+(?P<modifiers>(?:(?:{KOTLIN_MODIFIERS})\s+)*)"
    r"(?P<keyword>class|object|interface|typealias|fun|val|var|constructor)\b"
)
KOTLIN_CONSTRUCTOR_HEAD = re.compile(r"\s*(?:(?:@\w+\s+)*(?:public|internal|private|protected)\s+)?(?:constructor\s*)?\(")
KOTLIN_PROPERTY_PARAMETER = re.compile(rf"\b(?:val|var)\s+({IDENTIFIER})")
KOTLIN_ANNOTATION = re.compile(r"@[\w:.]+\s*")
KOTLIN_KINDS = {
    "class": KIND_TYPE,
    "object": KIND_TYPE,
    "interface": KIND_TYPE,
    "typealias": KIND_TYPE,
    "fun": KIND_FUNCTION,
    "val": KIND_PROPERTY,
    "var": KIND_PROPERTY,
    "constructor": KIND_INITIALIZER,
}
KOTLIN_SCOPE_KEYWORDS = ("class", "object", "interface")

# 型の宣言が次の行へ続いているときの、行の始まりと、前の行の終わり。
CONTINUATION_STARTS = (":", "where ", "{", ")", ",", "->", ">")
CONTINUATION_ENDS = (",", ":", "->", "&", "(", "<")


@dataclasses.dataclass
class _Scope:
    """波括弧の囲み 1 つ。"""

    # 公開の型の名前。型の囲みでなければ None。
    name: str | None = None
    # "type"・"enum" (値を直下に持つ)・"implicit" (直下の宣言が、書かなくても公開になる)・"other"。
    kind: str = "other"
    # 利用者向けでない印の付いた型の囲み。中の宣言を拾わない。
    hidden: bool = False
    # Kotlin の enum class の、値の並びがまだ続いている。
    entries_open: bool = False


@dataclasses.dataclass(frozen=True)
class _Match:
    start: int
    kind: str
    name: str | None
    # 囲みを作る宣言なら、その囲みの種類。
    scope_kind: str | None = None
    # Kotlin の最初のコンストラクタの "(" の位置。
    constructor_open: int | None = None


def unquote(name: str) -> str:
    return name.strip("`")


def skip_angle_brackets(text: str, index: int) -> int:
    """index が "<" を指していれば、対応する ">" の次の位置を返す。"""
    if index >= len(text) or text[index] != "<":
        return index
    depth = 0
    while index < len(text):
        if text[index] == "<":
            depth += 1
        elif text[index] == ">":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return index


def remove_angle_brackets(text: str) -> str:
    out: list[str] = []
    depth = 0
    for char in text:
        if char == "<":
            depth += 1
        elif char == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(char)
    return "".join(out)


def kotlin_member_name(rest: str, stops: str) -> str | None:
    """fun・val・var の後ろの文面から、名前を読む。型引数と、拡張の受け手を飛ばす。"""
    index = len(rest) - len(rest.lstrip())
    index = skip_angle_brackets(rest, index)
    head = rest[index:]
    for stop in stops:
        position = head.find(stop)
        if position >= 0:
            head = head[:position]
    head = remove_angle_brackets(head).strip()
    if not head:
        return None
    candidate = head.split()[0] if "." not in head else head.rsplit(".", 1)[1].strip()
    return unquote(candidate) if re.fullmatch(IDENTIFIER, candidate) else None


def swift_matches(line: str, in_implicit_scope: bool) -> tuple[list[_Match], bool]:
    """行の宣言を読む。(読んだ宣言, public と書かれているのに読み取れなかったか) を返す。"""
    public = SWIFT_PUBLIC.match(line)
    if public is None:
        if PUBLIC_WORD.search(line):
            return [], True
        extension = SWIFT_EXTENSION.match(line)
        if extension:
            # 公開でない extension。中の public の宣言に、型の名前を添えるためだけに囲みを作る。
            return [_Match(len(line) - len(line.lstrip()), "", extension.group("name"), scope_kind="extension")], False
        if in_implicit_scope and not RESTRICTED_WORD.search(line):
            implicit = SWIFT_IMPLICIT.match(line)
            if implicit:
                return swift_declaration(line, implicit, is_public=False)
        return [], False
    return swift_declaration(line, public, is_public=True)


def swift_declaration(line: str, matched: re.Match[str], is_public: bool) -> tuple[list[_Match], bool]:
    """is_public は、行に public と書かれているかどうか (書かなくても公開になる囲みの直下では False)。"""
    keyword, rest = matched.group("keyword"), matched.group("rest")
    start = len(line) - len(line.lstrip())
    if keyword in ("init", "subscript"):
        return [_Match(start, SWIFT_KINDS[keyword], None)], False
    name = LEADING_IDENTIFIER.match(rest)
    if name is None:
        return [], True
    identifier = unquote(name.group(1))
    if keyword == "extension":
        # extension は名前を宣言しない。直下の宣言が、書かなくても公開になる囲みを作る。
        return [_Match(start, "", identifier, scope_kind="implicit" if is_public else "extension")], False
    scope_kind = None
    if keyword in SWIFT_SCOPE_KEYWORDS:
        scope_kind = "enum" if keyword == "enum" else "implicit" if keyword == "protocol" else "type"
    return [_Match(start, SWIFT_KINDS[keyword], identifier, scope_kind=scope_kind)], False


def kotlin_matches(line: str) -> tuple[list[_Match], bool]:
    matches: list[_Match] = []
    unreadable = False
    for found in KOTLIN_PUBLIC.finditer(line):
        keyword, modifiers = found.group("keyword"), found.group("modifiers").split()
        rest = line[found.end() :]
        if keyword == "constructor":
            matches.append(_Match(found.start(), KIND_INITIALIZER, None))
            continue
        if keyword in ("fun", "val", "var"):
            name = kotlin_member_name(rest, "(" if keyword == "fun" else ":=")
            if name is None:
                unreadable = True
                continue
            matches.append(_Match(found.start(), KOTLIN_KINDS[keyword], name))
            continue
        identifier = LEADING_IDENTIFIER.match(rest)
        if identifier is None:
            if keyword == "object" and "companion" in modifiers:
                matches.append(_Match(found.start(), KIND_COMPANION, None, scope_kind="type"))
            else:
                unreadable = True
            continue
        scope_kind = None
        constructor_open = None
        if keyword in KOTLIN_SCOPE_KEYWORDS:
            scope_kind = "enum" if "enum" in modifiers else "type"
        if keyword == "class":
            after_name = skip_angle_brackets(line, found.end() + identifier.end())
            constructor = KOTLIN_CONSTRUCTOR_HEAD.match(line, after_name)
            if constructor:
                constructor_open = constructor.end() - 1
        matches.append(
            _Match(
                found.start(),
                KOTLIN_KINDS[keyword],
                unquote(identifier.group(1)),
                scope_kind=scope_kind,
                constructor_open=constructor_open,
            )
        )
    if len(PUBLIC_WORD.findall(line)) > len(KOTLIN_PUBLIC.findall(line)):
        unreadable = True
    return matches, unreadable


def extract(platform: Platform, path: str, text: str) -> Extraction:
    """1 つのソースの文面から、公開の宣言を拾う。"""
    swift = platform.extension == ".swift"
    raw_lines = text.splitlines()
    declarations: list[Declaration] = []
    unparsed: list[Unparsed] = []

    stack: list[_Scope] = []
    paren_depth = 0
    # 囲みを作る宣言を読んだが、まだ "{" に届いていない。
    pending: _Scope | None = None
    spi_pending = False
    # Kotlin の最初のコンストラクタの中にいる: (括弧の深さ, 波括弧の深さ, 型の名前)。
    constructor: tuple[int, int, str] | None = None
    previous_code = ""

    def hidden() -> bool:
        return any(scope.hidden for scope in stack)

    def owner() -> str:
        return ".".join(scope.name for scope in stack if scope.name)

    def add(number: int, kind: str, name: str | None, owner_name: str | None = None) -> None:
        declarations.append(
            Declaration(path, number, kind, name, owner() if owner_name is None else owner_name, raw_lines[number - 1].strip())
        )

    def read_scope_text(scope: _Scope | None, text_: str, number: int) -> None:
        """囲みの直下に書かれた文面から、public と書かれない宣言 (列挙の値など) を拾う。"""
        if scope is None or hidden():
            return
        if swift and scope.kind == "enum":
            case = SWIFT_CASE.match(text_)
            if case:
                for part in case.group("rest").split(","):
                    name = LEADING_IDENTIFIER.match(part)
                    if name:
                        add(number, KIND_ENUM_VALUE, unquote(name.group(1)))
        elif not swift and scope.kind == "enum" and scope.entries_open:
            head, separator, _ = text_.partition(";")
            for part in head.split(","):
                part = KOTLIN_ANNOTATION.sub("", part).strip()
                if not part:
                    continue
                if re.fullmatch(IDENTIFIER, part):
                    add(number, KIND_ENUM_VALUE, unquote(part))
                else:
                    scope.entries_open = False
                    break
            if separator:
                scope.entries_open = False

    def read_constructor_text(text_: str, number: int, owner_name: str) -> None:
        for part in text_.split(","):
            parameter = KOTLIN_PROPERTY_PARAMETER.search(part)
            if parameter is None:
                continue
            before = part[: parameter.start()]
            # public と書かれた引数は、行の宣言として拾ってある。
            if RESTRICTED_WORD.search(before) or PUBLIC_WORD.search(before):
                continue
            add(number, KIND_PROPERTY, unquote(parameter.group(1)), owner_name)

    for number, line in enumerate(code_lines(text), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        continued = (
            paren_depth > 0 or stripped.startswith(CONTINUATION_STARTS) or previous_code.endswith(CONTINUATION_ENDS)
        )
        if pending is not None and not continued:
            # 中身を持たない型の宣言だった。後ろの無関係な "{" に、囲みを渡さない。
            pending = None
        if swift and SWIFT_SPI in line:
            spi_pending = True

        in_implicit_scope = bool(stack) and stack[-1].kind == "implicit" and paren_depth == 0
        matches, unreadable = swift_matches(line, in_implicit_scope) if swift else kotlin_matches(line)
        if unreadable and not hidden() and not spi_pending:
            unparsed.append(Unparsed(path, number, raw_lines[number - 1].strip()))
        starts: dict[int, list[_Match]] = {}
        for match in matches:
            starts.setdefault(match.start, []).append(match)
        constructor_opens = {match.constructor_open: match.name for match in matches if match.constructor_open is not None}

        scope_buffer: list[str] = []
        constructor_buffer: list[str] = []

        def flush_scope() -> None:
            text_ = "".join(scope_buffer)
            scope_buffer.clear()
            if text_.strip():
                read_scope_text(stack[-1] if stack else None, text_, number)

        def flush_constructor() -> None:
            text_ = "".join(constructor_buffer)
            constructor_buffer.clear()
            if constructor is not None and text_.strip() and not hidden():
                read_constructor_text(text_, number, constructor[2])

        for index, char in enumerate(line):
            for match in starts.get(index, ()):
                # 印は、その次に現れた宣言 1 つに掛かる。
                skip = hidden() or spi_pending
                spi_pending = False
                if match.scope_kind is not None:
                    pending = _Scope(
                        name=match.name,
                        kind=match.scope_kind,
                        hidden=skip,
                        entries_open=not swift and match.scope_kind == "enum",
                    )
                if match.kind and not skip:
                    # コンストラクタの引数として書かれたプロパティは、そのクラスのものである。
                    add(number, match.kind, match.name, constructor[2] if constructor is not None else None)

            in_constructor = (
                constructor is not None and paren_depth == constructor[0] and len(stack) == constructor[1]
            )
            if char == "(":
                paren_depth += 1
                if index in constructor_opens:
                    type_name = constructor_opens[index] or ""
                    constructor = (paren_depth, len(stack), ".".join(filter(None, [owner(), type_name])))
            elif char == ")":
                if in_constructor:
                    flush_constructor()
                    constructor = None
                paren_depth = max(0, paren_depth - 1)
            elif char == "{":
                flush_scope()
                if paren_depth == 0 and pending is not None:
                    stack.append(pending)
                    pending = None
                else:
                    stack.append(_Scope())
            elif char == "}":
                flush_scope()
                if stack:
                    stack.pop()
                pending = None
            else:
                if in_constructor:
                    constructor_buffer.append(char)
                if paren_depth == 0:
                    scope_buffer.append(char)
        flush_scope()
        flush_constructor()
        previous_code = stripped

    return Extraction(tuple(declarations), tuple(unparsed))


def source_files(root: str, platform: Platform) -> list[str]:
    """プラットフォームの本体のソースを、リポジトリのルートからの "/" 区切りの相対のパスで返す。"""
    base = os.path.join(root, *platform.source_root.split("/"))
    found: list[str] = []
    for directory, _, names in os.walk(base):
        for name in names:
            if name.endswith(platform.extension):
                relative = os.path.relpath(os.path.join(directory, name), root)
                found.append(relative.replace(os.sep, "/"))
    return sorted(found)


def collect(root: str, platform: Platform) -> Extraction:
    """今の作業ツリーのソースから、プラットフォームの公開の宣言を拾う。"""
    declarations: list[Declaration] = []
    unparsed: list[Unparsed] = []
    for path in source_files(root, platform):
        with open(os.path.join(root, *path.split("/")), encoding="utf-8") as f:
            extraction = extract(platform, path, f.read())
        declarations.extend(extraction.declarations)
        unparsed.extend(extraction.unparsed)
    return Extraction(tuple(declarations), tuple(unparsed))
