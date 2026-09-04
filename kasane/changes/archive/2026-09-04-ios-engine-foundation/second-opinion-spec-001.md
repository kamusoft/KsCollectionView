# セカンドオピニオン: ios-engine-foundation (spec-001)
**相方**: codex / **label**: so-spec-ios-engine-foundation / **日付**: 2026-09-01 / **対象**: 提案一式 (proposal / design / specs 3能力 / tasks / ui-brief)
---
# レビュー結果: ios-engine-foundation

**判定**: NEEDS_DISCUSSION  
**指摘件数**: Critical 1 / Major 8 / Minor 2 / Suggestion 0

## サマリー

中核となる identity・内容変更・テンプレート再利用の契約が閉じておらず、現状の仕様をすべて満たす実装は定義できません。また、前提 ADR の大半が未 accepted のまま「確定」と扱われています。実装開始前に仕様判断と受け入れ基準の改訂が必要です。

静的レビューのため、ビルド・テストは未実施です。依頼どおりレビュー結果ファイルも作成していません。

## 照合した規約

- ソースコメント規約（always）
- 公開識別子と配布座標
- Sample のプラットフォーム間一致
- テスト実行規約
- ローカル開発環境と Sample の実行
- core/ADR-0001・0002・0003・0004・0006・0007・0008・0009
- ios/ADR-0001〜0004
- `swift-ui-impl-skill` の Swift Concurrency・状態管理・性能・アクセシビリティ観点

## 指摘事項

### [🔴 Critical] identity と内容変更の境界が未定義で、差分更新契約を実装できない

**該当箇所**: `specs/collection-core/spec.md:6`, `specs/collection-core/spec.md:19`, `specs/collection-core/spec.md:24`, `specs/collection-core/spec.md:29`, `specs/collection-core/spec.md:32`, `design.md:23`, `kasane/decisions/core/0003-collection-state-model.md:17`

**問題点**: 要素に要求されるのは安定 ID だけですが、「同じ ID で内容が変わった要素だけを再構成し、無関係な要素は再描画しない」ためには内容同値性が必要です。core/ADR-0003 自身も `Equatable` が事実上必要と認めていますが、spec と公開 API 契約にはありません。

加えて次の境界も未定義です。

- 同じ ID のままテンプレートキー／実行時型が変わった場合、「セルインスタンス維持」と「同一キー間でのみ再利用」が両立しない
- 同一 snapshot 内の重複 ID は diffable data source の前提を壊すが、一意性要求とエラー挙動がない
- 非 `Equatable` 型や参照比較しか持たない KMP モデルの内容変更検知方法がない

**推奨修正**: 次を明示的に決定してください。

- ID は snapshot 内で一意・安定・`Hashable`
- 内容変更検知は `Item: Equatable`、利用者提供 comparator、または content-version/key path のどれで行うか
- テンプレートキー不変時は reconfigure、キー／型変更時は reload・セル置換、などの遷移規則
- 重複 ID の debug/release 挙動
- 上記を満たさない場合は「無関係な要素は再描画されない」という SHALL を緩和するか

### [🟠 Major] 未 accepted の ADR 群を確定済み前提としている

**該当箇所**: `proposal.md:5`, `design.md:5`, `design.md:69`, `kasane/decisions/core/index.md:6`, `kasane/decisions/ios/index.md:5`

**問題点**: proposal/design は phase-1・phase-2 の判断を「確定」「全論点解消済み」としていますが、core/ADR-0002〜0009 と ios/ADR-0001〜0004 はすべて `proposed` です。Kasane 規約上、`proposed` は AI ドラフトであり、人間確認済みの決定ではありません。

**推奨修正**: 本提案の前提となる ADR をオーナー確認後に `accepted` へ昇格するか、未確定事項として Open Questions に戻してください。少なくとも未 accepted の ADR を拘束力のある実装基準として扱わないよう整合させる必要があります。

### [🟠 Major] 型ベース変種を成立させるデータモデルが設計されていない

**該当箇所**: `specs/collection-core/spec.md:44`, `design.md:23`, `design.md:24`, `design.md:26`, `tasks.md:11`, `kasane/decisions/core/0004-template-per-type-registration.md:36`

**問題点**: spec は異なる型が混在する配列を必須提供としていますが、design Decision 2 は「配列は単一型なので型間 ID 衝突はない」と仮定しています。Swift の異種配列には存在型／型消去が必要であり、ID 抽出、内容比較、型間 ID 衝突、型付きテンプレートへの復元方法が決まっていません。

**推奨修正**: 初版から提供するなら、異種配列の公開入力型、identity の名前空間、内容比較、テンプレートへの安全な型復元を design/spec に追加してください。そこまで扱わないなら、副次変種 Requirement と task 2.4 を後続 change へ移すのが安全です。

### [🟠 Major] adaptive・向き判定・不正値のレイアウト計算が決まっていない

**該当箇所**: `specs/collection-layout/spec.md:6`, `specs/collection-layout/spec.md:14`, `specs/collection-layout/spec.md:16`, `specs/collection-layout/spec.md:19`, `specs/collection-layout/spec.md:32`, `design.md:39`

**問題点**:

- adaptive の「余りは列間へ均等配分」と、指定 `columnSpacing` をそのまま空ける契約の関係が不明
- 列数計算に `contentPadding` と spacing を含める順序・計算式がない
- `.fixed(0)`、負の spacing、ゼロ以下の `minItemWidth`、非有限値などの許容範囲と失敗方法がない
- portrait/landscape をコンテナの縦横比から導出する場合、iPad Split View、正方形、ウィンドウリサイズ時の意味が端末向きと一致しない

**推奨修正**: 利用可能幅・列数・アイテム幅・余剰幅の計算式、各値の有効範囲、不正値の挙動を Scenario 化してください。向き別列数については「物理的な端末向き」か「コンテナの縦長／横長」かを公開契約として決める必要があります。

### [🟠 Major] 動的レイアウト切り替え時のスクロール保持が検証不能

**該当箇所**: `specs/collection-layout/spec.md:23`, `specs/collection-layout/spec.md:29`, `tasks.md:22`

**問題点**: 「スクロール位置を保つ」「表示中だった要素が表示範囲内に留まる」では、どの要素・どのオフセットを保持するのか判定できません。列数や行高が変われば content offset の維持と item anchor の維持は異なる結果になります。`invalidateLayout()` だけでこの保証が得られるとも限りません。

**推奨修正**: 例えば「切り替え直前に先頭で可視だった ID と、そのセル上端から viewport 上端までのオフセットを維持する」のように anchor を定義してください。anchor が削除済みの場合、list→grid／grid→list、アニメーション有無も Scenario に含めてください。

### [🟠 Major] セル内の対話要素とアイテムタップの競合規則がない

**該当箇所**: `specs/collection-interaction/spec.md:5`, `specs/collection-interaction/spec.md:13`, `tasks.md:32`

**問題点**: テンプレートは任意の SwiftUI View なので、セル内の `Button`、Toggle、リンク、スクロール gesture とアイテムタップ／ロングタップが競合します。子 Button の操作でも `onItemTap` が発火するか、長押し中の移動・スクロール・セル再利用でキャンセルするか、タップだけ／ロングタップだけ宣言した場合の feedback が未定義です。

カスタム色、ハンドラ未宣言時の非表示、VoiceOver activation についても Requirement はありますが Scenario がありません。

**推奨修正**: gesture の優先順位、子コントロール操作時の伝播、キャンセル条件、通常タップとロングタップの排他、feedback の発火条件、アクセシビリティ activation を契約化してください。

### [🟠 Major] KsScrollController の接続・並行性・エラー意味論が不足している

**該当箇所**: `specs/collection-interaction/spec.md:18`, `specs/collection-interaction/spec.md:26`, `design.md:18`, `tasks.md:33`

**問題点**: 次が未定義です。

- 存在しない ID への命令
- attach 後、detach 前後、1 controller を複数 View に接続した場合
- 複数命令の順序／coalescing
- 連続 snapshot apply 中に発行した命令が、どの apply 完了を待つか
- target が apply 中に削除された場合
- Swift 6 strict concurrency 下の actor isolation

「同一処理内で連続実行」はテスト可能な時間・順序契約ではありません。

**推奨修正**: `@MainActor` を含む公開隔離契約と、接続状態・pending apply・command queue の状態遷移を定めてください。unknown ID、detach、複数接続、複数 apply/command の Scenario を追加してください。

### [🟠 Major] Scenario と検証手段が受け入れ基準を閉じていない

**該当箇所**: `specs/collection-core/spec.md:11`, `specs/collection-core/spec.md:63`, `specs/collection-core/spec.md:69`, `specs/collection-core/spec.md:74`, `design.md:53`, `tasks.md:35`, `tasks.md:47`

**問題点**:

- 「100件全てが描画」は仮想化と用語上衝突する。data source 件数とスクロール到達可能性を検証すべき
- 画面外へ出ただけではセルが実際に再利用された保証がなく、`@State` 初期化 Scenario が非決定的
- 3回の hitch 計測を平均・最大・全回のどれで判定するか不明
- 「メモリ増分が定常化」に数値、観測期間、許容傾きがない
- 可変行高データの分布と gesture が固定されておらず、手動計測の再現性がない
- debug 未登録キー、footer、カスタム feedback、`scrollToStart/End` など、Requirement の SHALL に対応する Scenario がない
- 「全 Scenario の単体テスト」では UIKit の再利用・アニメーション・実機性能を検証できない
- 早期性能ゲートを掲げながら、性能タスクは Sample 完成後の第8節に置かれている

**推奨修正**: Requirement の各 SHALL と、unit／Simulator integration／UI test／実機手動検証の対応表を tasks に追加してください。性能 fixture、trial 集約規則、メモリ数値基準、evidence 形式を固定し、早期計測をレイアウト完成直後へ明示的に移動してください。

### [🟠 Major] Sample の画面数と実装対象が自己矛盾している

**該当箇所**: `proposal.md:13`, `ui/brief.md:7`, `ui/brief.md:10`, `tasks.md:44`

**問題点**: 3つのモック対象に加え、`ui/brief.md:10` は「他6画面」としながら7画面を列挙しています。合計は10画面となり、proposal/tasks の9画面と一致しません。また task 7.3 は change 外の「agenda 決定の表」に依存しており、確定タイトル・画面順・データ・検証対象が変更一式だけでは分かりません。

**推奨修正**: 正となる9画面を、タイトル・順序・検証 API・fixture・モック有無の表として `ui/brief.md` に確定してください。Android 追随時に一字一句照合できる値もここで閉じる必要があります。

### [🟡 Minor] prefetch 接続口だけが仕様・設計・テストから孤立している

**該当箇所**: `proposal.md:12`, `proposal.md:24`, `tasks.md:13`

**問題点**: 内部 protocol を先行実装するとしていますが、prefetch／cancel の責務、ID への変換、snapshot 更新との競合、呼び出し actor、テスト方法が design/spec にありません。利用者から観測できない「口だけ」の実装は、phase-8 の設計と合わず作り直す可能性があります。

**推奨修正**: phase-8 まで延期するか、内部 seam の最小契約と unit test を design/tasks に追加してください。

### [🟡 Minor] performance handbook の作成経路が Kasane 規約と一致しない

**該当箇所**: `design.md:53`, `tasks.md:49`

**問題点**: 実装タスク中に `handbook/ios/performance-verification.md` を直接起草・index 更新する計画ですが、handbook は手編集せず `ksn-concept`／`ksn-lesson`／`ksn-distill` の経路を通す規約です。また未検証の計測手順を先に長命規範へ固定すると、初回計測で判明した現実とずれるおそれがあります。

**推奨修正**: まず change 内の design/evidence として計測手順を検証し、オーナー確認後に `ksn-distill` で handbook へ昇格するタスクへ変更してください。

## アクションプラン

1. ADR の承認状態と、identity／内容比較／テンプレート変更契約を先に確定する。
2. 型ベース変種を初版に残すか判断し、残す場合は型消去モデルを設計する。
3. レイアウト計算、anchor 保持、interaction、controller の状態遷移を Scenario 化する。
4. Scenario と検証層の対応表、再現可能な性能基準を作る。
5. Sample の正確な9画面を確定し、prefetch・handbook タスクのスコープを整理する。
6. 改訂後、実装開始前に再レビューする。

---

## 突き合わせ結果 (2026-09-01)

ホスト側自己レビュー (2周、指摘なしで通過) との突き合わせ。相方のみの指摘が大半で、根拠の強いものを採用した。

**採用 — 提案へ反映済み:**
- [Critical] identity と内容変更の境界: Equatable / isEqual による内容比較・ID の Hashable + 配列内一意 (重複は debug assertion)・テンプレートキー変更時のセル置換 (reload) を collection-core spec と design Decision 2 に明文化
- [Major] レイアウト計算・不正値: 利用可能幅の定義・不正入力の debug assertion・adaptive の余剰幅配分 (アイテム幅へ) を collection-layout spec に追記
- [Major] 動的切り替えのアンカー: 「先頭可視要素をアンカーとして維持、削除時は近傍」を Requirement 化
- [Major] セル内対話要素との競合: 子コントロール優先・スクロールでのキャンセル・tap/longTap 排他を Requirement + Scenario 化
- [Major] KsScrollController: MainActor 契約・unknown ID / detach 後 no-op・複数接続は最後優先・pending apply 待ち規則・対象削除時 no-op を Requirement + Scenario 化
- [Major] 検証可能性: 100 件描画の文言修正 (件数 + 到達可能性)・hitch 3 回すべて合格・メモリ判定手順 (1 往復基準 + 増分定常)・固定シードデータ・検証層対応表タスク (6.5)・性能早期計測のグループ 4 直後実施を明記
- [Major] Sample 画面数の矛盾: brief.md に 9 画面の確定表 (タイトル・検証対象・モック有無) を追加、「他 6」の誤記を修正
- [Minor] prefetch 口: 最小契約の unit test をタスクに追加
- [Minor] handbook 直接起草: evidence で検証 → ksn-distill で昇格に変更 (design Decision 6 / tasks 8.2)

**部分降格:**
- レイアウト計算の完全な式化 (アイテム幅の丸め等): 利用可能幅の定義までを spec 化し、端数処理は実装 + テストに任せる (観察可能な契約の粒度を超えるため)

**ユーザー判断へ (NEEDS_DISCUSSION の実体):**
1. [Major] 前提 ADR (core/0002〜0009・ios/0001〜0004) が proposed のまま — accepted への一括昇格の可否
2. [Major] 型ベーステンプレート変種 — v1 実装から除外して後続へ移すか
3. [Major] 向き別列数の意味論 — 物理端末向きか、コンテナの縦長/横長か

**未解決 (矛盾による割れ):** なし

## ユーザー判断の解決 (2026-09-01)

1. ADR 昇格 → **承認**: core/0002〜0009・ios/0001〜0004 の 12 件を accepted へ昇格 (index 更新済み)
2. 型ベース変種 → **v1 から除外**: spec の Requirement と該当タスクを削除、proposal の Non-Goals に理由付きで記録
3. 向き意味論 → **コンテナ縦横比基準 + portrait/landscape の命名維持**: core/ADR-0006 に意味論 (CSS orientation と同義)・却下案 (物理向き判定 / narrow・wide 改名) を明文化し accepted へ。spec / design に反映

以上で NEEDS_DISCUSSION は解消。判定を実質 APPROVED (全指摘処理済み) として実装ハンドオフへ進む。
