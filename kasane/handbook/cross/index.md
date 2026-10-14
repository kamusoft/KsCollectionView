# cross — 規約・ガイド一覧

リポジトリ横断の規約・ガイド (リポジトリ構成・命名・ハーネス運用)。

| 文書 | 適用のきっかけ | 種別 |
|---|---|---|
| [ソースコメント規約](comment-policy.md) | 常時 — ソースにコメントを書く・書き換えるとき | rule |
| [Sample のプラットフォーム間一致](sample-parity.md) | `samples/` を触るとき — Sample のデモ画面・文言を追加・変更するとき | rule |
| [Sample の操作は本体の表示を変えない](sample-debug-controls.md) | `samples/` を触るとき — Sample のデモ画面に操作 (パネル・切り替え・ボタン) を置く・変えるとき、Sample の画面の brief・mock を書くとき | rule |
| [テスト実行規約](test-execution.md) | テストを実行するとき・テスト結果を報告するとき・テストを追加するとき・Android 本体の画像のデコードに触る変更をするとき | rule |
| [実行時挙動の検証規約](runtime-behavior-verification.md) | 実行時挙動の不具合を調査するとき・不具合修正の完了を判定するとき | rule |
| [スクロール性能の体感ゲート](scroll-performance-gate.md) | スクロール性能の完了を判定するとき・手動フリック計測を行うとき・性能の証跡を書くとき・区切り線の既定の太さ・色を変えるとき | rule |
| [公開識別子と配布座標](public-identifiers.md) | 公開識別子・配布座標を決めるとき (ビルド定義・パッケージ宣言を触るとき)・利用者が依存に書く値 (Maven の座標・SwiftPM の Package URL と package の名前) を案内に書く / 変えるとき・その値を載せている README・`SKILL.md` のインストール例を変えるとき | rule |
| [ローカル開発環境と Sample の実行](local-development-setup.md) | clone した後の準備をするとき・作業用のブランチや worktree を作るとき・環境構築・Sample の起動・本体のビルド・本体 source へのステップインをするとき | guide |
| [ブランチの運用と GitHub の設定](branch-and-github-settings.md) | `develop` へ push するとき・`main` 宛ての Pull Request を作る / マージするとき・GitHub のリポジトリの設定やブランチの保護を変える / 確かめ直すとき | guide |
| [検証 CI](verification-ci.md) | `.github/workflows/`・`scripts/ci/` を触るとき・検証 CI の失敗を調べるとき・検証 CI に検査を足す / 外すとき・CI の緑を完了の根拠に使うとき・`CI script tests` が README か利用者向け Skill の検査で落ちたとき | guide |
| [配布物の形と作り方](package-distribution.md) | `scripts/distribution/`・Android の公開の設定 (`android/kscollectionview/build.gradle.kts`)・バージョンカタログ・`ios/Package.swift` の宣言を触るとき・配布物を手元で作って確かめるとき・検証で使う Xcode の版を上げるとき | guide |
| [利用者の立場のビルドの確認](consumer-build-check.md) | `verification/`・`scripts/ci/verify-consumer-*.py`・`.github/workflows/verify-consumer-*.yml` を触るとき・配布物の形に関わる変更を push する前に手元で確かめるとき・`consumer-ios / verify`・`consumer-android / verify` の失敗を調べるとき・利用者役の画面のファイル (README の最小コード例の元) を変えるとき | guide |
| [利用者向け Skill と README の書き方](user-docs-writing.md) | `skills/`・ルートの `README.md` / `README_ja.md`・`assets/`・`scripts/ci/user-docs-rules.json` を触るとき・利用者向け Skill や README の文面・コード例・インストール例・スクリーンショットを書く / 直すとき | rule |
| [利用者向け Skill の追従](user-skill-refresh.md) | `skills/`・`scripts/docs/`・`.agents/skills/docs-refresh/` を触るとき・利用者向け Skill の追従を頼まれたとき (入口は追従の Skill `docs-refresh`)・公開 API や利用者に見える挙動を変えた変更を蒸留した後に、Skill へ反映するかを判断するとき | guide |
