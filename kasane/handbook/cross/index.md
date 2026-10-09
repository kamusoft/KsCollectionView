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
| [公開識別子と配布座標](public-identifiers.md) | 公開識別子・配布座標を決めるとき (ビルド定義・パッケージ宣言を触るとき) | rule |
| [ローカル開発環境と Sample の実行](local-development-setup.md) | clone した後の準備をするとき・作業用のブランチや worktree を作るとき・環境構築・Sample の起動・本体のビルド・本体 source へのステップインをするとき | guide |
| [ブランチの運用と GitHub の設定](branch-and-github-settings.md) | `develop` へ push するとき・`main` 宛ての Pull Request を作る / マージするとき・GitHub のリポジトリの設定やブランチの保護を変える / 確かめ直すとき | guide |
| [検証 CI](verification-ci.md) | `.github/workflows/`・`scripts/ci/` を触るとき・検証 CI の失敗を調べるとき・検証 CI に検査を足す / 外すとき・CI の緑を完了の根拠に使うとき | guide |
