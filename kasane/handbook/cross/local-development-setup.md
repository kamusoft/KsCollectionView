---
kind: guide
applies-when:
  always: false
  tasks: [環境構築, Sample の起動, 本体のビルド・lint, 本体 source へのステップイン]
title: ローカル開発環境と Sample の実行
description: iOS / Android のローカル環境設定、Sample の起動、本体のビルドとステップインの手引き。iOS は確定済み手順、Android は構成確定前の骨格を持つ
timestamp: 2026-09-02
---

# ローカル開発環境と Sample の実行

この文書は、リポジトリを clone した開発者が iOS・Android の Sample を開いて実行し、本体をビルドし、本体 source へデバッガでステップインするまでの手順をまとめる。

iOS の SwiftPM パッケージと Sample プロジェクトは成立済みであり、本書には実際に確認した手順を記す。Android はビルド構成の成立後に追記する。**未検証の手順を現行の手引きとして書かないこと** — 動かない手順は、無い手順より読み手の時間を奪う。

[cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) を先に読むと、プラットフォームごとに独立したビルドルートを持つ理由が分かる。

## 必要環境

決定済みの下限は次のとおり。

| 対象 | 決定済みの下限 |
|---|---|
| iOS | iOS 16 以上 (`UIHostingConfiguration` 依存) の Simulator または実機 |
| Android | minSdk 29 (Android 10) 以上の Emulator または実機 |

開発ツール側の要件 (Xcode・Swift・JDK・Android SDK / Build-Tools・Android Studio の版) は、実構成の確定時にここへ追記する。

## 版の定義元

手元の版が要件に合うか調べるときは、**版を書き写した資料ではなく定義元のファイルを見る**。書き写した一覧は更新に追随せず、食い違ったときにどちらが正か分からなくなる。

定義元を追記するときは、次の原則で選ぶ。

- 版ごとに**単一の宣言元**を決め、他の箇所はそれを読む。同じ版を 2 箇所に書かない
- ビルドが実際に読むファイルを定義元にする。ドキュメントや README を定義元にしない
- 定義元が決まっていない版は「未確定」と書く。仮の値を書いて既成事実にしない

定義元の表 (対象 / 定義元ファイル) は、各プラットフォームのビルド構成が成立した時点でこの節へ追加する。

| 対象 | 定義元ファイル |
|---|---|
| Swift tools version・iOS 最低対応版・product / target | `ios/Package.swift` |
| iOS Sample の最低対応版・bundle ID | `samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj` |

## 環境変数と SDK ロケーション

Android SDK の解決方法 (環境変数を使う場合と、ビルドルートごとの設定ファイルを使う場合)、および複数の Xcode を併用する環境での選択の固定方法をここに書く。実構成の確定後に追記する。

Sample と本体を別のビルドルートとして構成する場合、ビルドルートごとに SDK 解決が独立する点に注意が要る。片方だけを設定して解決したつもりになる落とし穴は翻案元でも実際に起きている (参考: `../KsSettingsView/kasane/handbook/cross/local-development-setup.md`)。

## Sample を開く / 実行する

iOS Sample は `samples/ios/KsCollectionViewSamples.xcodeproj` を Xcode で開き、scheme `KsCollectionViewSamples` と利用可能な iOS Simulator を選んで実行する。本体は `../../ios` の Local Package として解決される。

CLI のビルドは `samples/ios/` で `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=<利用可能な機種名>,OS=<利用可能な版>' -configuration Debug CODE_SIGNING_ALLOWED=NO` を実行する。

Sample の識別子は [cross/ADR-0003](../../decisions/cross/0003-public-identifier-namespace.md) の `jp.kamusoft.kscollectionview.samples.ios` / `.android` に従う。

## 本体をビルドする

Sample ではなく本体だけをビルドする場合は `ios/` で `xcodebuild build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` を実行する。

テストの実行方法と完了判定は [テスト実行規約](test-execution.md) が正であり、本節はビルドのみを扱う。本節にテスト実行コマンドを書かないこと (二重管理になり、片方だけが更新される)。

## 本体 source へステップインする

iOS Sample の Xcode project navigator で Package Dependencies の `KsCollectionView` を開くと、`ios/Sources/KsCollectionView/` の source を直接参照できる。そこへ breakpoint を置き、Sample scheme を Debug 実行してステップインする。

## デモ画面一覧はどこを見るか

画面の集合・表示名・遷移先は、**各 Sample の `SampleScreen` 実装が正である**。一覧を書き写した資料は増減に追随しないので、実装ファイルを直接見る。

- 定義元ファイル (iOS / Android それぞれの `SampleScreen`) のパスは、Sample scaffold の成立時にここへ追記する
- iOS の定義元は `samples/ios/KsCollectionViewSamples/SampleScreen.swift`
- プラットフォーム間で揃える範囲と例外は [Sample のプラットフォーム間一致](sample-parity.md) を参照する

## 関連

- [cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) — `ios/` `android/` を独立したビルドルートとする決定
- [テスト実行規約](test-execution.md) — テストの実行方法と完了判定
- [Sample のプラットフォーム間一致](sample-parity.md) — Sample の一致規約
- [実行時挙動の検証規約](runtime-behavior-verification.md) — 実環境での確認が要る不具合の完了判定

出典: ../KsSettingsView/kasane/handbook/cross/local-development-setup.md (章立て・版の定義元の考え方・デモ画面一覧の原則)
