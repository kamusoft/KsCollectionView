---
kind: rule
applies-when:
  always: false
  paths: ["**/build.gradle.kts", "**/settings.gradle.kts", "ios/Package.swift", "verification/ios/Package.swift.template"]
  tasks: [公開識別子・配布座標の決定, 利用者が依存に書く値 (Maven の座標・SwiftPM の Package URL と package の名前) を載せている README・Skill のインストール例の変更]
title: 公開識別子と配布座標
description: 所有主体・製品・成果物の役割を各エコシステムの識別子へ写像する規約と、利用者が依存に書く値 (Maven の座標・SwiftPM の Package URL と package の名前)、その値を載せている場所 (利用者役・README・利用者向け Skill のインストール例) と同時に直すもの
timestamp: 2026-10-10
---

# 公開識別子と配布座標

この文書は、KsCollectionView の製品名・名前空間・アプリケーション ID・配布座標の命名規約を定める。読むと、識別子を全エコシステムで同じ文字列にせず、所有主体・製品・用途をそれぞれの慣例へどう写像するかが分かる。

決定の根拠と却下案は [cross/ADR-0003](../../decisions/cross/0003-public-identifier-namespace.md) にある。本文書はその決定を作業時に引ける形へ落としたものであり、規範の正は ADR である。SwiftPM の Package URL と、利用者が書く package の名前は、配信用の別リポジトリから配る決定 ([cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md)) から決まる。

## 命名方針

公開識別子は、所有主体・KsCollectionView 製品・成果物またはアプリケーションの用途を区別する。Apple / Android は lowercase の reverse-DNS、Swift の package / product は PascalCase、Maven の座標と Gradle の project 名は lowercase を使う。

| 対象 | 規則または値 | 表すもの |
|---|---|---|
| SwiftPM のマニフェストの `name` | `KsCollectionView` | 製品 |
| SwiftPM の Package URL (利用者が依存に書く) | `https://github.com/kamusoft/KsCollectionView-SPM` | 所有主体 + 製品 + 配信用であること |
| 利用者が target の依存に書く package の名前 | `KsCollectionView-SPM` | Package URL の末尾から決まる名前 (配信用リポジトリの名前) |
| SwiftPM product | `KsCollectionView` を接頭辞とする PascalCase | 製品内の公開層 |
| Maven 座標 | `jp.kamusoft:kscollectionview` | 所有主体 + 製品 |
| Gradle `group` / project 名 | `jp.kamusoft` / `kscollectionview` | 上記座標と同値 |
| Android library namespace | `jp.kamusoft.kscollectionview.*` | 所有主体・製品・層 |
| Apple bundle ID / Android application ID | `jp.kamusoft.kscollectionview.*` | 所有主体・製品・アプリケーション用途 |
| Sample アプリケーション | `jp.kamusoft.kscollectionview.samples.ios` / `.android` | Sample とプラットフォームの区別 |

`kscollectionview` は Android の命名要件に合わせて lowercase で連結する。SwiftPM product は `KsCollectionView` の 1 本である ([ios/ADR-0005](../../decisions/ios/0005-single-swiftpm-product.md))。product を足すことになっても、接頭辞の規則はこの表に従う。後続のモジュール・Sample・ツールも独自の体系を作らず、上表の接頭辞と各エコシステムの表記規則から用途を導く。

## Maven 座標

Android の配布座標は `jp.kamusoft:kscollectionview` の 1 点とする。groupId が所有主体、artifactId が製品を表す。

- **artifactId はブランド名を 1 トークンとして扱い、内部にハイフンを入れない**。Maven の慣例では、ハイフンはブランドとサブモジュールの境目にのみ使う
- 層ごとの複数 artifact に分けない。Android は Compose Lazy 系の薄いラッパーで層分割の前提を持たず、分けても利用者に推移する依存は減らない
- Gradle の `group` には ADR と同じ `jp.kamusoft` を設定する。ADR の規範値と実装値を最初から一致させ、配布直前に座標を是正する作業を発生させない
- version の宣言元は 1 箇所に定める (バージョンカタログ `android/gradle/libs.versions.toml` の `kscollectionview`)。Sample や利用者役から本体の版を参照する場合も、その宣言元を読む形にする
- 座標を変えるときは、下の「値を載せている場所」のすべてを、同じ変更で直す

利用者に見せる例 (README と `SKILL.md`) では、版の位置に `{version}` を置き、具体の版を書かない ([cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md))。座標の 1 行は、次の形になる。

```kotlin
implementation("jp.kamusoft:kscollectionview:{version}")
```

## SwiftPM の Package URL と package の名前

SwiftPM の配布物は、配信用のリポジトリ `kamusoft/KsCollectionView-SPM` から配る ([cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md))。利用者がマニフェストに書くのは、次の 2 行である。

```swift
.package(url: "https://github.com/kamusoft/KsCollectionView-SPM", exact: "<版>"),
```

```swift
.product(name: "KsCollectionView", package: "KsCollectionView-SPM"),
```

利用者に見せる例 (README と `SKILL.md`) では、版の位置を `exact: "{version}"` と書く。具体の版を書かない ([cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md))。

SwiftPM で「package の名前」と呼ばれ得る値は、3 つある。値が違うので、分けて扱う。

| 名前 | 値 | 決めているもの |
|---|---|---|
| マニフェストの `name` | `KsCollectionView` | cross/ADR-0003 (SwiftPM package 名を製品名にする決定)。`ios/Package.swift` に書いてある |
| Package URL | `https://github.com/kamusoft/KsCollectionView-SPM` | cross/ADR-0015 (配信用リポジトリの場所) |
| 利用者が `.product(…, package:)` に書く名前 | `KsCollectionView-SPM` | SwiftPM の挙動。SwiftPM は、package を Package URL の末尾の名前で見分ける。マニフェストの `name` では見分けない |

cross/ADR-0003 の「package 名は `KsCollectionView`」は、マニフェストの `name` についての決定で、今もそのとおりである。利用者が書く名前が製品名そのものにならないことは、cross/ADR-0015 が、配信用リポジトリから配ることの帰結として受け入れている。

- product の名前と、`import` するモジュールの名前は、`KsCollectionView` のままである
- 配信用リポジトリの名前を変えると、利用者が書く package の名前が変わる。公開の後は変えない
- 利用者役 (`verification/ios/`。配布物を利用者と同じ書き方で取る最小のプロジェクト) は、この 2 行と同じ書き方で配布物を取る
- 書き方を変えるときは、下の「値を載せている場所」のすべてを、同じ変更で直す

配信用リポジトリは、2026-10-09 時点ではまだ無い。URL は決めた値で、取得できることは確かめていない。確かめたのは、この 2 行を持つマニフェストを SwiftPM が読めることと、同じ package の名前で手元の写しを参照する利用者役がビルドできることである ([利用者の立場のビルドの確認](consumer-build-check.md))。

## 値を載せている場所

利用者が依存に書く値は、次の場所に載っている。値を変える・書き方を変えるときは、すべてを同じ変更で直す。

| 場所 | 載っている値 | 食い違ったとき |
|---|---|---|
| 利用者役のひな形 (`verification/ios/Package.swift.template`) と、iOS の確認のスクリプト (`scripts/ci/verify-consumer-ios.py`) | Package URL・package の名前・product の名前 | 利用者の立場のビルドの確認が、決めた値と違う書き方で配布物を取る。インストール例の検査は、この値を正として README と Skill を比べるので、README と Skill の側が違反として出る |
| Android の利用者役の依存の行 (`verification/android/app/build.gradle.kts`) | Maven の座標 | 同上 |
| ルートの README の 2 枚 (`README.md`・`README_ja.md`) のインストールの節 | Package URL・package の名前・product の名前・Maven の座標 | インストール例の検査 (`scripts/ci/check-readme-examples.py`) が落ちる。検査は、利用者役の値と比べる |
| 利用者向け Skill の `SKILL.md` (`skills/{en,ja}/kscollectionview-ios/`・`skills/{en,ja}/kscollectionview-android/`) の導入の節 | iOS は Package URL・package の名前・product の名前、Android は Maven の座標 | 同じ検査が落ちる |
| 許可する URL の一覧 (`scripts/ci/user-docs-rules.json`) | Package URL・本リポジトリの URL | Skill 自身の整合の検査が、Skill に書いた URL を、一覧に無い URL として落とす |

- 検査が比べる相手は、利用者役の値である。この文書の値と利用者役の値が食い違っていても、検査は気付かない。値を変えるときは、この文書を先に直し、利用者役・README・Skill を同じ変更で合わせる
- 検査が数えるのは、コードブロックの中の依存の宣言の行だけである。本文の中に書いた Package URL や座標 (iOS の `SKILL.md` の、Xcode から足す手順の文など) は、インストール例の検査が見ないので、目で直す
- コードブロックの中で Package URL か座標に触れる行は、決めた 1 行の形でなければ、検査が違反にする。座標を分けて書く形 (group・name・version を別々に書く宣言、version catalog) は、検査が拾えない
- インストール例の書き方 (版の位置・行の形・置き換えの説明・最新の版の確かめ先) は、[利用者向け Skill と README の書き方](user-docs-writing.md) にある

## 保証すること

- 完全な識別子から、kamusoft・KsCollectionView・成果物またはアプリケーションの用途を判別できる
- Swift の package / product は PascalCase、Android の namespace とアプリケーション ID は lowercase reverse-DNS、Maven 座標は lowercase を使う
- Sample アプリケーションは `jp.kamusoft.kscollectionview.samples.*` の下でプラットフォームを区別する
- 利用者への Android の案内は `implementation("jp.kamusoft:kscollectionview:<版>")` の 1 行で足りる。README と Skill の例では、版の位置に `{version}` を置く
- 利用者への iOS の案内は、Package URL `https://github.com/kamusoft/KsCollectionView-SPM` と、package `KsCollectionView-SPM` の product `KsCollectionView` への依存で足りる
- README と利用者向け Skill のインストール例の値は、利用者役が配布物を取るときに使う値と同じである (検査が、検証 CI が起動する push のたびに確かめる)

## してはいけないこと

- 各エコシステムの大小文字や区切りを無視して、識別子の文字列表現を一律にしない
- Maven の `groupId` と `artifactId` の責務を混同しない (製品名を座標内で二重に持たせない)
- artifactId のブランド名の内部にハイフンを入れない
- ADR の規範値と実装値 (Gradle の `group` 等) を食い違わせたまま進めない。食い違いに気づいたら、どちらに合わせるかを判断してから直す
- 公開後の識別子変更は事実上不可能なため、既に公開した識別子を新しい規則で書き換えない
- 利用者役・README・利用者向け Skill のうち、一部だけの値を変えて終えない。依存の書き方を変える変更は、値を載せているすべての場所を同じ変更で直す
- README と利用者向け Skill のインストール例に、具体の版を書かない

## 関連

- [cross/ADR-0003](../../decisions/cross/0003-public-identifier-namespace.md) — 公開識別子の名前空間と配布座標の決定
- [cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) — `ios/` `android/` を独立したビルドルートとする決定
- [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) — SwiftPM を配信用の別リポジトリから配る決定
- [cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md) — インストール例に具体の版を書かず、`{version}` を置く決定
- [配布物の形と作り方](package-distribution.md) — 配布物の中身と、手元での作り方
- [利用者向け Skill と README の書き方](user-docs-writing.md) — インストール例の書き方と、検査が見るもの
- [利用者の立場のビルドの確認](consumer-build-check.md) — 利用者と同じ書き方で配布物を取る利用者役と、その確かめ方

出典: ../KsSettingsView/kasane/handbook/cross/public-identifiers.md (命名方針・写像表・保証すること / してはいけないこと の構成) / kasane/changes/archive/2026-10-09-package-distribution/evidence/consumer-ios.md (利用者が書く 2 行を持つマニフェストを SwiftPM に読ませた結果) / kasane/changes/archive/2026-10-10-user-docs/evidence/local-completion.md (README の例の検査の結果。違反なし・確かめた依存の宣言の行 12 行)
