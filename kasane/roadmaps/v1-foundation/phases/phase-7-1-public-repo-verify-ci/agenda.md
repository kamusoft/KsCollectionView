# 公開の準備 / 検証 CI

リポジトリを公開できる状態にし、検証 CI を動かす。

## 論点

(残りなし。2026-10-08 にすべて決定事項へ移した)

## 決定事項

### 履歴の扱い (2026-10-08)

- 今の履歴を書き換えも捨てもせず、そのまま公開リポジトリへ push する ([cross/ADR-0009](../../../../decisions/cross/0009-publish-existing-history-as-is.md)、proposed)
- gitleaks を導入する。公開の直前に履歴全体へ掛け、公開後も検査として使い続ける。置き場所は検証 CI の構成の論点で決める

### ブランチの役割 (2026-10-08)

- ブランチを `develop` と `main` の 2 本に分ける ([cross/ADR-0010](../../../../decisions/cross/0010-develop-and-main-branch-roles.md)、proposed)
- `develop` は日々の開発の場所で、直接 push し、検証は push の後に走る
- `main` はリリース候補だけが入る場所で、`develop` からの PR でしか入れず、リリースは `main` から起動する

### 外部からの貢献の受け方 (2026-10-08)

- 外部からの PR は受け付けず、貢献は Issue で受ける ([cross/ADR-0011](../../../../decisions/cross/0011-contributions-via-issues-no-external-pull-requests.md)、proposed)。GitHub の設定で、PR を作れる人を共同作業者に限る
- Issue のフォームは英語で 3 本 (バグ報告・提案・質問)。実際に動かした証拠を必須にし、本文は英語でも日本語でもよい
- 貢献の案内 (`CONTRIBUTING`) は英日 2 枚。Discussions は開かず、質問も Issue で受ける
- README の「貢献」の節の文面は phase-7-3-user-docs で書く (その議論で拾う)

### ライセンス (2026-10-08)

- MIT License で提供し、著作権の名義は `kamusoft` とする ([cross/ADR-0012](../../../../decisions/cross/0012-mit-license.md)、proposed)。`LICENSE` をルートに置く
- Sample にサードパーティの通知が要る素材があるかは、README の「ライセンス」の節を書くときに確かめる (phase-7-3-user-docs の議論で拾う)

### 公開の時期 (2026-10-08)

- リポジトリは最初から public で作る。公開前の確認 (証跡の画像の目視・gitleaks) は、最初の push の前に済ませる
- README ができるまでの間は、準備中と分かる短い案内を英日 2 枚で置く (議論側が置いた既定。オーナーの指示があれば変える)

### 検証 CI が走らせる範囲 (2026-10-08)

- iOS 本体と Android 本体のテストは全件、Sample は両プラットフォームともビルドとユニットテストまでを走らせる ([cross/ADR-0013](../../../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md)、proposed)
- Sample の UI テストは CI に載せず、手元の完了判定に残す。手元で 4 系統を全件流す決まりは変えない

### 実機が要るテストと性能計測 (2026-10-08)

- 端末をつないで走らせるテスト (Android の画像のデコードの 4 件) と性能検証は CI に載せず、手元の完了条件のままにする (cross/ADR-0013 に含めた)。phase-8 の申し送りへの答え
- CI が使うのは GitHub の標準のランナーだけにする。組織の Mac mini に基準機をつなぐ案は、初回リリースの後に別の変更として取り上げられる
- 性能計測の CI での自動化 (phase-2 の申し送り) は、受け皿を作らないので再訪しない。きっかけは cross/ADR-0006 の見直しの条件に残る

### macOS のランナーと Xcode の版 (2026-10-08)

- iOS の検証は GitHub の標準のランナー `xcode-27` (Xcode 27、iOS 27.0 の Simulator) だけで行う。手元と翻案元と同じ環境
- Xcode 26 でビルドできるかは CI で確かめない。対応する Xcode の案内の書き方は、配布物の形と README の議論で拾う (phase-7-2・phase-7-3)

### lint の中身 (2026-10-08、議論側の既定)

- lint のジョブは、翻案元から MAUI・配布・README の分を除いた 5 つにする: `main` 宛て PR の head が `develop` であることの検査、gitleaks、ローカル絶対パスの lint、識別子の lint、コメント規約の lint
- gitleaks は追跡中の内容を取り出して走査し、版と配布物の checksum を固定する (翻案元と同じ)。手元の commit 時の gitleaks は、Kasane の標準の hook で既に動いている
- 文書の構造 lint は CI に入れない (hook にも登録していない検査で、`kasane/` だけの push では CI を起動しないため)
- GitHub の側の secret の検査と push の保護を有効にする

### 構成とトリガーの細部 (2026-10-08、議論側の既定)

- platform 別の再利用 workflow (iOS / Android) と入口 1 本で構成し、リリースからも同じ workflow を呼べる形にする (翻案元 cross/0025)
- `develop` への push では lint と両 platform の検証を走らせ、新しい push が走行中の古い実行を打ち切る。`kasane/` と Issue のフォーム・貢献の案内だけの push では起動しない
- `main` 宛ての PR では絞り込みなしで同じ検証を走らせ、lint・iOS・Android を必須の検査にする。`develop` は必須の検査を持たず、強制 push と削除だけを禁じる
- テストの実行が 0 件なら失敗にする。ジョブには時間の上限を置き、検査の名前は固定する
- Android の検証は Linux の標準のランナーと JDK 21 (手元と同じ) で行う

## TODO

- [x] 論点の解消
- [ ] 公開の前に、履歴に残る証跡の画像 (約 100 件) を目で確かめ、画面内に個人の情報が無いことを確認する
- [ ] 公開の直前に gitleaks を履歴全体へ掛け直す
- [ ] `develop` を作り、作業用のブランチの基点を `main` から移す切り替えの手順を提案に含める
- [ ] 端末をつないで走らせるテストの流し方と、流す時点 (画像のデコードに触る変更) を handbook に書くことを提案に含める
- [ ] GitHub の側の secret の検査と push の保護が、public で無料に使える範囲を提案のときに確かめる
- [ ] iOS Sample を CI でビルドとユニットテストだけ流す指定 (UI テストを除く) を提案で決める
- [ ] 検証 CI の構成 (再利用 workflow と入口、リリースからも同じ検証を呼ぶ) は ADR の候補。オーナーが既定を確かめたら起票する
- [ ] ksn-propose で変更提案を起こす

## 実装結果 (2026-10-08 反映)

変更 `public-repo-verify-ci` で実装し、公開した。記録は `kasane/changes/archive/2026-10-08-public-repo-verify-ci/` にある。

- GitHub に `kamusoft/KsCollectionView` を公開した。履歴は書き換えずにそのまま載せた (cross/ADR-0009)。公開前の 5 つの確認はすべて通った
- ブランチを `develop` と `main` に分け、保護を入れた。本変更は `develop` から `main` 宛ての最初の Pull Request で `main` に入った (cross/ADR-0010)
- ライセンス・準備中の README・貢献の案内・Issue のフォーム 3 本を置き、Pull Request を作れる人を共同作業者に限った (cross/ADR-0011・0012)
- 検証 CI は、決定事項「検証 CI が走らせる範囲」と違う形になった。最初の実行で、手元では通る iOS 本体のテスト 1 件がランナーの Simulator で落ち、オーナーが CI では Simulator を使うテストを走らせないと決めた。iOS はビルドの確認だけ、Android は JVM のテストの全件を走らせる (cross/ADR-0013 を実装後の内容に書き直して確定)
- 検証 CI の構成と検査の名前の固定は、cross/ADR-0014 として確定した
- 手順と値は handbook の `cross/branch-and-github-settings.md` と `cross/verification-ci.md` にある

### 申し送り

| 項目 | 受け皿 |
|---|---|
| リリースの workflow から、同じ検証 (再利用 workflow) を呼ぶ | phase-7-4-release-pipeline の agenda (phase-7-1 からの申し送り) |
| 管理者が `main` の保護を迂回してよい条件とやり方、マージの後に `main` を `develop` へ取り込み直すか、リリース候補にする節目の基準、secret が検出されたときにすること | phase-7-4-release-pipeline の agenda (同上) |
| `main` の workflow の時間の上限が暫定の値のまま (決め直した値は `develop` にある) | phase-7-4-release-pipeline の agenda (同上。次の `main` 宛ての Pull Request で入る) |
| 公開物を利用者の立場でビルドする確認を、`main` 宛ての Pull Request に足す | phase-7-2-package-distribution の agenda (既存の論点。再利用 workflow の形で足せることを申し送り) |
| README の本文と `skills/` | phase-7-3-user-docs (既存の範囲。今あるのは準備中の案内だけ) |
| ランナーで落ちた iOS 本体のテスト 1 件の原因の調査 | 見送り。CI では走らせないことにし、手元では通る (公開の後に全件を流して確認)。手元で同じ落ち方をしたら簡易起票する |
| 端末をつないで走らせるテストを、今の 4 件で Gradle のタスクから流した記録が無い | 見送り。handbook の `cross/test-execution.md` に「確かめていないこと」として書いた。次に流すときに記録する |
| Android SDK がランナーに無いときの取得の手順が、1 度も通っていない | 見送り。ランナーに SDK がある間は通らない。handbook の `cross/verification-ci.md` に書いた |
| Android のテストのクラスの導き方の制限 (行末のコメントなど) | 見送り。handbook の `cross/verification-ci.md` の既知の制限に書いた |

