> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/public-identifiers.md`
> - proposal の「蒸留時に反映」にある、依存の書き方を変えるときに同時に直すものに、README と Skill のインストール例を足すための草稿である
> - 追記は 4 個ある。それぞれの見出しに、追記先の節と、足すのか置き換えるのかを書いてある
> - 文書の中のリンクは、追記先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - 追記先は規約 (`kind: rule`) で、規範の正は cross/ADR-0003 と cross/ADR-0015 である。この草稿は、識別子の値も規則も変えない。足すのは、値を書いている場所の一覧と、同時に直すものである
> - 値の根拠: README の 2 枚と 4 つの `SKILL.md` のインストール例の実物と、インストール例の検査 (`scripts/ci/check-readme-examples.py`。2026-10-10 に「違反なし (確かめた依存の宣言の行 12 行)」)
> - リンク先の cross/ADR-0018 は、書いた時点では proposed である。蒸留で accepted にしてから置く
> - リンク先の「利用者向け Skill と README の書き方」は、同じ変更で新設する文書 (草稿は `user-docs-writing.md`)。置き先の名前が変わるなら、リンクも直す
> - `applies-when` の `paths` に README と `SKILL.md` を足すかは、蒸留で決める。足すと、README や Skill の本文だけを直す作業でもこの文書が読まれる。足さない場合でも、「利用者向け Skill と README の書き方」のインストール例の節が、この文書を指している (追記 1 は、足さない案で書いた)
> - 配信用リポジトリは、書いた時点ではまだ無い。追記先の、取得できることを確かめていないという段落は、そのまま残す
> - `timestamp` は、蒸留で置く日にする

---

## 追記 1: frontmatter の直し

`applies-when` の `tasks` に、次の 1 つを足す。`paths` は変えない。

```
利用者が依存に書く値 (Maven の座標・SwiftPM の Package URL と package の名前) を載せている README・Skill のインストール例の変更
```

`description` の末尾に、次を足す。

```
、その値を載せている場所 (利用者役・README・利用者向け Skill のインストール例) と同時に直すもの
```

## 追記 2: 節「Maven 座標」の箇条の最後に、足す

> - 利用者に見せる例では、版の位置に `{version}` を置き、具体の版を書かない ([cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md))。座標の 1 行は `implementation("jp.kamusoft:kscollectionview:{version}")` の形になる
> - 座標を変えるときは、利用者役の依存の行 (`verification/android/app/build.gradle.kts`) と、README の 2 枚・Android の 2 つの `SKILL.md` のインストール例を、同時に直す

## 追記 3: 節「SwiftPM の Package URL と package の名前」の直し

利用者がマニフェストに書く 2 行の、1 つ目のコードブロックの下に、次を足す。

> 利用者に見せる例 (README と `SKILL.md`) では、版の位置を `exact: "{version}"` と書く。具体の版を書かない ([cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md))。

箇条の「書き方を変えるときは、利用者役のひな形 (`verification/ios/Package.swift.template`) と、確認のスクリプト (`scripts/ci/verify-consumer-ios.py`) が持つ値も同時に直す」を、次に置き換える。

> - 書き方を変えるときは、次を同時に直す。利用者役のひな形 (`verification/ios/Package.swift.template`)、確認のスクリプト (`scripts/ci/verify-consumer-ios.py`) が持つ値、README の 2 枚と iOS の 2 つの `SKILL.md` のインストール例、許可する URL の一覧 (`scripts/ci/user-docs-rules.json`) の Package URL

箇条の後ろに、小節を 1 つ足す。

### 値を載せている場所

利用者が依存に書く値は、次の場所に載っている。値を変える・書き方を変えるときは、すべてを同じ変更で直す。

| 場所 | 載っている値 | 食い違ったとき |
|---|---|---|
| 利用者役のひな形 (`verification/ios/Package.swift.template`) と、iOS の確認のスクリプト (`scripts/ci/verify-consumer-ios.py`) | Package URL・package の名前・product の名前 | 利用者の立場のビルドの確認が、決めた値と違う書き方で配布物を取る。インストール例の検査は、この値を正として README と Skill を比べるので、README と Skill の側が違反として出る |
| Android の利用者役の依存の行 (`verification/android/app/build.gradle.kts`) | Maven の座標 | 同上 |
| ルートの README の 2 枚 (`README.md`・`README_ja.md`) のインストールの節 | Package URL・package の名前・product の名前・Maven の座標 | インストール例の検査 (`scripts/ci/check-readme-examples.py`) が落ちる。検査は、利用者役の値と比べる |
| 利用者向け Skill の `SKILL.md` (`skills/{en,ja}/kscollectionview-ios/`・`skills/{en,ja}/kscollectionview-android/`) の導入の節 | iOS は Package URL・package の名前・product の名前、Android は Maven の座標 | 同じ検査が落ちる |
| 許可する URL の一覧 (`scripts/ci/user-docs-rules.json`) | Package URL・本リポジトリの URL | Skill 自身の整合の検査が、Skill に書いた URL を、一覧に無い URL として落とす |

- 検査が比べる相手は、利用者役の値である。この文書の値と利用者役の値が食い違っていても、検査は気付かない。値を変えるときは、この文書を先に直し、利用者役・README・Skill を同じ変更で合わせる
- 検査が数えるのは、コードブロックの中の依存の宣言の行だけである。本文の中に書いた Package URL や座標 (iOS の `SKILL.md` の、Xcode から足す手順の文など) は、検査が見ないので、目で直す
- インストール例の書き方 (版の位置・置き換えの説明・最新の版の確かめ先) は、[利用者向け Skill と README の書き方](user-docs-writing.md) にある

## 追記 4: 節「保証すること」「してはいけないこと」「関連」の直し

節「保証すること」の、次の箇条を置き換える。

- 前: 利用者への Android の案内は `implementation("jp.kamusoft:kscollectionview:x.y.z")` の 1 行で足りる
- 後: 利用者への Android の案内は `implementation("jp.kamusoft:kscollectionview:<版>")` の 1 行で足りる。README と Skill の例では、版の位置に `{version}` を置く

節「保証すること」に、次の箇条を足す。

> - README と利用者向け Skill のインストール例の値は、利用者役が配布物を取るときに使う値と同じである (検査が、push のたびに確かめる)

節「してはいけないこと」に、次の箇条を足す。

> - 利用者役・README・利用者向け Skill のうち、一部だけの値を変えて終えない。依存の書き方を変える変更は、値を載せているすべての場所を同じ変更で直す
> - README と利用者向け Skill のインストール例に、具体の版を書かない

節「関連」に、次の 2 行を足す。

> - [cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md) — インストール例に具体の版を書かず、`{version}` を置く決定
> - [利用者向け Skill と README の書き方](user-docs-writing.md) — インストール例の書き方と、検査が見るもの
