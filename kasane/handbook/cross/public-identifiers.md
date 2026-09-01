---
kind: rule
applies-when:
  always: false
  paths: ["**/build.gradle.kts", "**/settings.gradle.kts", "ios/Package.swift"]
  tasks: [公開識別子・配布座標の決定]
title: 公開識別子と配布座標
description: 所有主体・製品・成果物の役割を各エコシステムの識別子へ写像する規約
timestamp: 2026-09-01
---

# 公開識別子と配布座標

この文書は、KsCollectionView の製品名・名前空間・アプリケーション ID・配布座標の命名規約を定める。読むと、識別子を全エコシステムで同じ文字列にせず、所有主体・製品・用途をそれぞれの慣例へどう写像するかが分かる。

決定の根拠と却下案は [cross/ADR-0003](../../decisions/cross/0003-public-identifier-namespace.md) にある。本文書はその決定を作業時に引ける形へ落としたものであり、規範の正は ADR である。

## 命名方針

公開識別子は、所有主体・KsCollectionView 製品・成果物またはアプリケーションの用途を区別する。Apple / Android は lowercase の reverse-DNS、Swift の package / product は PascalCase、Maven の座標と Gradle の project 名は lowercase を使う。

| 対象 | 規則または値 | 表すもの |
|---|---|---|
| SwiftPM package | `KsCollectionView` | 製品 |
| SwiftPM product | `KsCollectionView` を接頭辞とする PascalCase | 製品内の公開層 |
| Maven 座標 | `jp.kamusoft:kscollectionview` | 所有主体 + 製品 |
| Gradle `group` / project 名 | `jp.kamusoft` / `kscollectionview` | 上記座標と同値 |
| Android library namespace | `jp.kamusoft.kscollectionview.*` | 所有主体・製品・層 |
| Apple bundle ID / Android application ID | `jp.kamusoft.kscollectionview.*` | 所有主体・製品・アプリケーション用途 |
| Sample アプリケーション | `jp.kamusoft.kscollectionview.samples.ios` / `.android` | Sample とプラットフォームの区別 |

`kscollectionview` は Android の命名要件に合わせて lowercase で連結する。SwiftPM product の分割粒度は iOS エンジン基盤の実装時に決めるが、接頭辞の規則はこの表に従う。後続のモジュール・Sample・ツールも独自の体系を作らず、上表の接頭辞と各エコシステムの表記規則から用途を導く。

## Maven 座標

Android の配布座標は `jp.kamusoft:kscollectionview` の 1 点とする。groupId が所有主体、artifactId が製品を表す。

- **artifactId はブランド名を 1 トークンとして扱い、内部にハイフンを入れない**。Maven の慣例では、ハイフンはブランドとサブモジュールの境目にのみ使う
- 層ごとの複数 artifact に分けない。Android は Compose Lazy 系の薄いラッパーで層分割の前提を持たず、分けても利用者に推移する依存は減らない
- Gradle の `group` には ADR と同じ `jp.kamusoft` を設定する。ADR の規範値と実装値を最初から一致させ、配布直前に座標を是正する作業を発生させない
- version の宣言元は 1 箇所に定める。Sample から本体を開発用座標で参照する場合も、その宣言元を読む形にする (宣言元の具体は Android ラッパー基盤の実装時に確定する)

## 保証すること

- 完全な識別子から、kamusoft・KsCollectionView・成果物またはアプリケーションの用途を判別できる
- Swift の package / product は PascalCase、Android の namespace とアプリケーション ID は lowercase reverse-DNS、Maven 座標は lowercase を使う
- Sample アプリケーションは `jp.kamusoft.kscollectionview.samples.*` の下でプラットフォームを区別する
- 利用者への Android の案内は `implementation("jp.kamusoft:kscollectionview:x.y.z")` の 1 行で足りる

## してはいけないこと

- 各エコシステムの大小文字や区切りを無視して、識別子の文字列表現を一律にしない
- Maven の `groupId` と `artifactId` の責務を混同しない (製品名を座標内で二重に持たせない)
- artifactId のブランド名の内部にハイフンを入れない
- ADR の規範値と実装値 (Gradle の `group` 等) を食い違わせたまま進めない。食い違いに気づいたら、どちらに合わせるかを判断してから直す
- 公開後の識別子変更は事実上不可能なため、既に公開した識別子を新しい規則で書き換えない

## 関連

- [cross/ADR-0003](../../decisions/cross/0003-public-identifier-namespace.md) — 公開識別子の名前空間と配布座標の決定
- [cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) — `ios/` `android/` を独立したビルドルートとする決定

出典: ../KsSettingsView/kasane/handbook/cross/public-identifiers.md (命名方針・写像表・保証すること / してはいけないこと の構成)
