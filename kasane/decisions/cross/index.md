# cross ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-two-platform-declarative-library-scope.md) | KsCollectionView を SwiftUI / Compose の2プラットフォームライブラリとして新設する (MAUI 非対応) | accepted | 価値命題はリスト・グリッドの定型機能を両プラットフォームで同じ書き味で提供すること。MAUI facade は持たない。 |
| [0002](0002-monorepo-platform-build-roots.md) | モノレポとプラットフォーム別ビルドルート | accepted | 単一リポジトリで公開 DSL の変更を一元管理し、`ios/` `android/` を独立ビルドルートとする。ルートに共通ビルドファイルを置かない。 |
| [0003](0003-public-identifier-namespace.md) | 公開識別子の名前空間と配布座標 | accepted | groupId は `jp.kamusoft`、Android は `jp.kamusoft:kscollectionview` の 1 artifact。bundle ID / namespace は `jp.kamusoft.kscollectionview.*`。 |
| [0004](0004-sample-cross-platform-parity.md) | Sample をプラットフォーム間パリティ検証装置と位置づける | accepted | 両プラットフォームで同一文言・同一画面構成を優先する。一致は収束状態への要求で、追跡付きの片側先行を許容する。 |
| [0005](0005-user-docs-as-agent-skills-and-root-readme.md) | 利用者向けドキュメントは Agent Skills (skills/、en/ja 2 版) で提供し、README はルート 2 枚に集約する | accepted | platform 別 2 Skill × en/ja、閉世界性と翻訳ロックステップ。開発者向けは契約 = concepts、規範・手順 = handbook。 |
| [0006](0006-perceived-smoothness-as-performance-gate.md) | スクロール性能の完了判定は基準機でのオーナーの体感を合否とし、計測器の数値は証跡として残す | accepted | 合否はオーナーの手動フリック、計測器の数値は合格線を置かない証跡。退行検出のゲート・窓や閾値の調整・手動のみ・自動駆動の足場改善を却下。fixture は機能ごとの Sample 画面で 10,000 件のまま、メモリの件数比は解放の確認へ差し替え。Android の相対基準は別系統。 |
| [0007](0007-sample-light-dark-within-parity.md) | Sample のライト / ダーク対応は、両プラットフォーム同値の 2 組の配色と同じ切り替えで行い、パリティの範囲内とする | accepted | `SampleTheme` にライト / ダーク 2 組の同値 RGBA を持ち、Sample 内の同じ切り替えで選ぶ。sample-parity の「dark mode 追随より一致を優先」を改める。semantic color での追随は引き続き禁止。 |
| [0008](0008-test-suite-ten-minute-budget.md) | テスト全系統の合計を 10 分以内に保ち、Sample の UI テストは実際の操作でしか確かめられないものに絞る | accepted | 4 系統を順に流した待ち時間の合計をビルド込みで 10 分以内に保つ。UI テストは実際の操作を通す確認を機能ごとに 1 件残し、本体のテストとの重複を置かない。完了判定の全件実行は変えない。 |
| [0009](0009-publish-existing-history-as-is.md) | 公開リポジトリには既存の履歴を書き換えずにそのまま載せる | accepted | 履歴に個人のメールアドレスもローカル絶対パスも無いため、作り直さずそのまま push する。公開前に証跡の画像の目視と gitleaks の走査を行う。 |
| [0010](0010-develop-and-main-branch-roles.md) | 開発は develop、リリース候補は main の 2 本のブランチに分ける | accepted | develop は直接 push して事後に検証し、main は develop からの PR だけを受けてリリースの起動元にする。main 宛ての PR をリリースの節目とする。 |
| [0011](0011-contributions-via-issues-no-external-pull-requests.md) | 貢献は Issue で受け、外部からの Pull Request は受け付けない | accepted | PR を作れる人を共同作業者に限り、貢献は実際に動かした証拠を必須にした Issue で受ける。変更フローの外から実装が入らないようにする。 |
| [0012](0012-mit-license.md) | ライセンスは MIT License とする | accepted | 名義は `kamusoft`。兄弟ライブラリと条件を揃え、利用者に求める条件を最小にする。Apache License 2.0 は採らない。 |
| [0013](0013-ci-runs-no-simulator-or-device-tests.md) | 検証 CI では Simulator・エミュレータ・実機を使うテストを走らせず、iOS はビルドの確認、Android は JVM のテストの全件通過までを保証する | accepted | iOS は本体・Sample とそのテストのコードがビルドできることまで、Android は JVM のユニットテストの全件と Sample の組み立てまで。iOS のテストの実行・端末のテスト・性能検証は手元の完了条件に残す。 |
| [0014](0014-ci-reusable-platform-workflows-and-fixed-check-names.md) | 検証 CI は、プラットフォーム別の再利用 workflow と入口 1 本で構成し、検査の名前を固定する | accepted | iOS / Android の検証は入力なしの再利用 workflow、入口が lint を持つ。検査の名前は `lint`・`ios / verify`・`android / verify`。`main` 宛ての Pull Request では変更したパスで絞り込まない。 |
| [0015](0015-swiftpm-via-distribution-repository.md) | SwiftPM の配布物は、配信用の別リポジトリに本体の写しを置いて配る | accepted | 配信用の公開リポジトリ `KsCollectionView-SPM` のルートに `ios/` の本体の写しを置く。本リポジトリのルートにはマニフェストを置かず、`ios/Package.swift` を 1 枚のまま使う。ルートから直接配る案とバイナリで配る案を却下。 |
| [0016](0016-consumer-build-check-on-main-pull-requests.md) | 配布物は、利用者と同じ書き方で参照する専用の利用者役を、main 宛ての Pull Request でビルドして確かめる | accepted | 専用の小さな利用者役が公開の前の成果物を参照してビルドする。`main` 宛ての Pull Request のときだけ走らせて必須の検査にし、起動はしない。Android はコード縮小を有効にする。Sample の流用・中身の照合だけ・必須にしない・push ごと・リリースのときだけを却下。 |

採番規則は [../index.md](../index.md) を参照。
