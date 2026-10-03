# Exploration: android-build-jdk-range

## 課題 / 動機

Android のビルド定義 3 か所が、ビルドを動かす JDK を 17 に固定している (`jvmToolchain(17)`)。JDK 21 だけを入れた Mac では、本体も Sample も構成の段階で失敗し、ビルド・テスト・導入のどれも実行できない (JDK 17 の取得元は設定していない)。

`sample-group-header-spacing-color` のライブ調整 (2026-10-03) で、Android の Sample を専用エミュレータへ入れようとして見つかった。オーナーの「JDK 21 でビルドできるようにできないか」という依頼で扱う。

- 該当箇所: `android/kscollectionview/build.gradle.kts`、`samples/android/app/build.gradle.kts`、`samples/android/benchmark/build.gradle.kts` の `kotlin { jvmToolchain(17) }`

## 検討した選択肢 (却下案と理由を含む)

| 判断軸 | 案 A: JDK の固定を外し、出力だけ Java 17 向けに固定 (採用) | 案 B: 固定を 21 に変える | 案 C: 出力も Java 21 向けに上げる |
|---|---|---|---|
| ビルドできる JDK | 17 以上のどれでも | 21 だけ | 21 だけ |
| ライブラリの出力 (利用者が要る Java の版) | 17 向けのまま | 17 向けのまま | 21 向けに上がる |

- 案 B の却下理由: JDK 17 だけの環境でビルドできなくなる
- 案 C の却下理由: 配布するライブラリが利用者に求める Java の版が上がる

## 決定事項

- 3 か所の `jvmToolchain(17)` を、Kotlin の出力先の指定 (`compilerOptions` の `jvmTarget` を Java 17) に置き換える。Java 側の `sourceCompatibility` / `targetCompatibility` (17) は変えない
- 完了の目安: JDK 21 で、本体のビルドとユニットテスト、Sample のビルド・ユニットテスト・導入が通る
- 蒸留時に反映: handbook・`kasane/handbook/cross/local-development-setup.md` — 必要環境の JDK を「17」から「17 以上」にし、`jvmToolchain(17)` が要求するという記述と `java_home -v 17` の前置きの案内を改める
- 蒸留時に反映: handbook・`kasane/handbook/cross/local-development-setup.md` — 「版の定義元」の表の JDK の行を、ビルド定義が宣言するのは出力の対象 (Java 17) だけであることに合わせて改める
- 蒸留時に反映: decisions・android/ADR-0008 — accepted に昇格し、android/ADR-0002 に `amended-by: 0008` と index の「一部改訂: 0008」を足す
- 蒸留時に反映: handbook・`kasane/handbook/cross/test-execution.md` — 「JDK 17 が既定でない環境では…」の案内を同じく改める

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

作成済み: android/ADR-0008 (proposed、amends android/ADR-0002)。accepted の android/ADR-0002 が「JDK 17 (`jvmToolchain(17)`)」を決めており、この change はその 1 項目を置き換えるため、オーナー判断 (2026-10-03) で一部改訂の ADR を起票した。探索の時点では android/ADR-0002 を確かめておらず、独立レビュー (`review-001.md`) の指摘で分かった。

## 未決の論点

- JDK 17 での確認はしていない (この Mac に JDK 17 が無い)
- コンパイル時に見える JDK の API がビルドを動かす JDK の版で変わる (JDK 21 にしか無い API を使うと 21 でだけ通る)。レビューの見立てでは今は対応不要。android/ADR-0008 の負の帰結と Revisit When に書いた

## UI 素材 (ui/references/ の一覧と注釈)

なし。

## 変更級の推奨: S

ビルド定義 3 行の置き換え。公開 API と配布物の出力 (Java 17 向け) は変わらず、可逆。
