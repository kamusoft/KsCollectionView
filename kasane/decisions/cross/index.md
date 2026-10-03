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

採番規則は [../index.md](../index.md) を参照。
