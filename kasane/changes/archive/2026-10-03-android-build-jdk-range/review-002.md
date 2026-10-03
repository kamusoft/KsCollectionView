# レビュー結果: android-build-jdk-range (002 回目)

**日付**: 2026-10-03
**判定**: APPROVED

## サマリー

前回 (`review-001.md`) の 3 件の指摘はすべて解消している。accepted の android/ADR-0002 との食い違いは、一部改訂の android/ADR-0008 (proposed、amends 0002) と蒸留への申し送りで記録され、ADR-0008 の決定は合意スコープ (exploration.md の決定事項) とも実装 (3 ファイルの `compilerOptions.jvmTarget = JVM_17`) とも矛盾しない。

残るのは蒸留までに片付ければよい優先度の低い Minor 2 件と Suggestion 2 件で、実装の差し戻しは要らない。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always)
- `kasane/handbook/cross/local-development-setup.md` (本体のビルド。申し送りの行が指す箇所との突き合わせ)
- `kasane/handbook/cross/test-execution.md` (申し送りの行が指す箇所との突き合わせ。テストは今回実行していない)
- `kasane/handbook/cross/public-identifiers.md` (ビルド定義を触るとき。1 周目から diff が変わっていないことだけ確認)
- `kasane/decisions/android/0002-single-module-latest-compose-bom.md` (accepted)、`kasane/decisions/android/0008-build-jdk-17-or-later-with-java-17-output.md` (proposed。決定としては扱わず、合意スコープ・実装との整合だけを見た)
- `~/.claude/skills/ksn-core/references/decisions.md` (ADR の形式・amends の規律・昇格ゲート)、`~/.claude/skills/ksn-core/references/change-scope.md` (蒸留送りの行の形)
- `kasane/lessons/code-review.md` (L-001・L-002 とも計測値・動きの過程を扱わない change のため該当なし)

ロードしたスキル: ksn-review、kotlin-impl-skill

## 確認した観点

ビルド・テストは再実行していない (パッケージの指示。実装は 1 周目から無変更で、1 周目に JDK 21 で全件成功を確認済み)。今回実行したのは読み取りと lint だけ。

| 確認 | 結果 |
|---|---|
| 対象 3 ファイルの diff | 1 周目と同じ内容 (`jvmToolchain(17)` → `compilerOptions { jvmTarget.set(JVM_17) }`、`compileOptions` の 17 は無変更) |
| `python3 scripts/doc-structure-lint.py --paths kasane/decisions/android/0008-build-jdk-17-or-later-with-java-17-output.md` | 違反なし (タイトル 66 字) |
| `python3 scripts/comment-policy-lint.py` | 禁止 0 件 |
| `jvmToolchain` / toolchain の取得元の設定の残り (`*.kts` `*.toml` `*.properties` を検索) | 無し。ADR-0008 の Context「JDK 17 の取得元は設定していない」は現状と一致 |
| android/ADR-0002 と handbook の作業ツリー上の変更 | 無し (accepted の本文・長命層は書き換えられていない) |

前回の指摘の解消:

- **Major (ADR-0002 との食い違いが未記録)**: 解消。ADR-0008 が `amends: 0002` を frontmatter に持ち、Decision 節に「android/ADR-0002 の決定のうち『JDK 17 (`jvmToolchain(17)`)』を本決定で置き換える。他の決定は維持する」の 1 文がある (amends の規律どおり)。置き換え範囲は ADR-0002 の Decision の該当 1 項目 (`kasane/decisions/android/0002-single-module-latest-compose-bom.md:19`) と一致する。`kasane/decisions/android/index.md` に 0008 の行 (proposed) があり、0002 の行と frontmatter は未変更 (`amended-by` と「一部改訂: 0008」は accepted 昇格時に足す規約で、exploration.md の決定事項に蒸留送りの行がある)
- **Minor (「版の定義元」の表の漏れ)**: 解消。決定事項に「版の定義元」の表の JDK の行を改める蒸留送りの行が足されている (該当は `kasane/handbook/cross/local-development-setup.md:58`)。JDK 17 を前提にした案内は同文書の 33・37・75 行目と `kasane/handbook/cross/test-execution.md:71` の 4 か所で、申し送りの行はすべてを覆っている
- **Suggestion (JDK の API の見え方の環境差)**: 解消。exploration.md の未決の論点と、ADR-0008 の負の帰結・Revisit When に書かれている

ADR-0008 と合意スコープ・実装の整合:

- 決定「ビルドを動かす JDK は固定しない・出力は Java 17 向けに固定」は、決定事項の 1 行目と採用案 A に一致する。対象範囲「本体・Sample・計測モジュール」は実装の 3 ファイルと一致する
- 「含まないもの: 利用者に求める Java の版を上げること」は、`compileOptions` の `targetCompatibility` (17) を変えていない実装と一致する
- 却下案の 1・2 件目は exploration.md の案 B・案 C と理由まで一致する。3 件目は指摘 2
- Consequences の 4 行はどれも Decision と Context から導ける (実装後にしか分からない観測は混じっていない)。負の記載あり
- 決定の粒度: Decision 節は方向と境界だけで、手段 (`compilerOptions` の `jvmTarget`) は書いていない。手段を名指しした ADR-0002 と同じ食い違いを将来に残さない書き方になっている
- 出典行はリポジトリ相対。蒸留時に archive 後のパスへ直す必要がある (蒸留の作業で、指摘にはしない)

チェックリスト:

- 仕様充足 (合意スコープ): 1 周目の確認のとおりで、実装は無変更
- 足場の書き換え: exploration.md への追記は ADR 候補・蒸留送り・未決の論点だけで、採用案と実装に渡すスコープ (決定事項の 1・2 行目) は変わっていない。置き場所については指摘 3
- 無断の逸脱: 無し。deviation.md は無い
- 既存 ADR との整合: accepted の ADR-0002 との食い違いは ADR-0008 で扱いが記録された。ADR-0008 が accepted になるまでは食い違いが残るが、蒸留で同時に解消する段取りが記録されている
- テスト: ビルド定義だけの変更で、追加は不要 (1 周目に既存テスト全件成功)
- コメント: 3 か所とも単独で意味が通る。ADR への参照については指摘 1
- kotlin-impl-skill の観点: 1 周目から変化なし (指摘なし)
- オーバーエンジニアリング・セキュリティ・性能・リソース: 該当なし

## 指摘事項

### [🟡 Minor] 実装コードに android/ADR-0008 を指すコメントが無く、昇格ゲートの「埋め込みの証拠」がまだ無い

**該当箇所**: `android/kscollectionview/build.gradle.kts:67`、`samples/android/app/build.gradle.kts:106`、`samples/android/benchmark/build.gradle.kts:50`
**問題点**: 変更由来の ADR は、accepted に上げるときの証拠が「実装コードの `ADR-NNNN` コメント」と決まっている。3 か所のコメントは内容としては ADR-0008 の決定そのものだが、ADR の ID を持たない (実装が ADR の起票より先だったため)。同じファイルの他の決定は `(android/ADR-0002)` の形で参照している。このまま蒸留に入ると昇格ゲートで止まる。
**推奨修正**: 蒸留までに、少なくとも本体の `android/kscollectionview/build.gradle.kts:67` のコメントの末尾に `(android/ADR-0008)` を足す (他の 2 か所も揃えるのが自然)。コメントだけの変更で、ビルドの再確認は要らない。優先度は低く、今回の判定は妨げない。

### [🟡 Minor (ADR 側)] 却下案の 3 件目が、review-001.md の案 2 のうち「toolchain の取得元を設定する」手段に触れていない

**該当箇所**: `kasane/decisions/android/0008-build-jdk-17-or-later-with-java-17-output.md:29`
**問題点**: 出典の `review-001.md` の案 2 は、`jvmToolchain(17)` を残す手段として「toolchain の取得元の設定」と「JDK 17 の導入」の 2 つを挙げていた。ADR-0008 の却下案は「開発機に JDK 17 を入れる」だけを取り上げている。取得元を設定すれば開発機に手で JDK を入れなくても JDK 21 の環境でビルドが通るので、却下理由の「開発機ごとに特定の版の JDK を求める利得が無い」はこの手段には当たりにくい。将来この案が再提案されたとき、検討済みかどうかを ADR から判定できない。あわせて、却下理由の文面 (固定の理由が記録されていない・配布物の出力が変わらない) は exploration.md にも review-001.md にも無く、根拠はオーナーとの会話だけになっている。
**推奨修正**: オーナーの判断が取得元の設定も含めて退けたものなら、却下案の文面にその手段と理由を含める (proposed の間は起票したフローが書き直せる)。含めていなかったなら、検討していない案として却下案に載せず、そのままにする。どちらかをオーナーに確かめる。優先度は低い。

### [🔵 Suggestion] 実装に入った後で気づいた蒸留送りの行が、deviation.md ではなく exploration.md に足されている

**該当箇所**: `exploration.md` (決定事項の 4・5 行目)
**問題点**: スコープ規律は、申し送りの行が無いまま実装に入ったと気づいたときは「記録の主体が deviation.md に蒸留送りの行で書く」としている。今回は 1 周目のレビューの後に exploration.md の決定事項へ足されている。蒸留はどちらの行も入力として読むので実害は無く、exploration.md は凍結の対象 (proposal / design / specs) に挙がっていない。
**推奨修正**: 対応不要。規約の文言と揃えるなら、後から足した行を deviation.md に移す。

### [🔵 Suggestion] 「JDK 17 以上のどれでも」の上端は、ビルドに使う Gradle・AGP・Kotlin が対応する JDK で決まる

**該当箇所**: `kasane/decisions/android/0008-build-jdk-17-or-later-with-java-17-output.md:15`、`android/kscollectionview/build.gradle.kts:67`
**問題点**: 実証済みは JDK 21 だけで、上端は wrapper の Gradle (9.7.0)・AGP (9.4.0)・Kotlin (2.4.10) が対応する JDK の版までになる。ADR-0008 は Context の「前提」でこの条件を書いており、決定としては成り立っている。コードのコメント「17 以上であればよい」は上端を言っていないが、ビルド定義のコメントとしては十分。
**推奨修正**: 対応不要。蒸留で `local-development-setup.md` の JDK の要件を「17 以上」に改めるとき、確認済みの版 (21) を併記すると読み手が迷わない。

## アクションプラン

1. 蒸留までに、3 か所 (少なくとも本体) のコメントに `(android/ADR-0008)` を足す
2. ADR-0008 の却下案の 3 件目について、toolchain の取得元を設定する手段も退けたのかをオーナーに確かめ、必要なら文面を直す (proposed の間に)
3. JDK 17 の環境が手に入った時点で下端を実証する (exploration.md の未決の論点。1 周目から継続)
