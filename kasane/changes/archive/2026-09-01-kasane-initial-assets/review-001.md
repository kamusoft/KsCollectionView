# レビュー結果: kasane-initial-assets (001 回目)

**日付**: 2026-09-01
**判定**: **APPROVED** (初回判定は CHANGES_REQUESTED。修正適用後の再確認で更新 — 末尾「再確認 (2026-09-01)」節を参照)

M 級のため ksn-verify を本レビューに統合した。デルタスペックが存在しない (proposal.md に承認済み逸脱として申告) ため Scenario 対応表は作れず、代わりに tasks.md を代替仕様として完了条件を 1 行ずつ機械照合し、「検証」節に記録する。

## サマリー

成果物そのものの品質は高い。handbook 5 本・ADR 4 本を翻案元 `../KsSettingsView/` と実地照合したところ、翻案元固有の実測値・製品名・MAUI 前提・旧 artifactId 規則の混入はなく、ADR は決定記録として自立しており (ロードマップの Phase 番号を本文に持ち込まず機能名で書いている点は ksn-core references/decisions.md のガードレールに正確に従っている)、相対リンクは全件解決し、標準 lint 4 本も報告どおりの結果を再現した。

一方、**完了検査 (tasks 4 節) の実行記録に穴がある**。specs/ を省く根拠が「tasks.md が代替仕様として成果物別の完了条件を持つ」である以上、この節の記録精度が本 change の唯一の適合証跡であり、そこに (a) 記録が存在しない完了条件、(b) 数と実体が食い違う受入基準、(c) 取りこぼしのある走査、(d) 空振りを PASS と書いた lint 記録がある。いずれも成果物の内容を変える必要はなく、記録の是正で閉じる。

加えて、作業ツリーには proposal.md が申告していない同梱物 (comment-policy lint 一式・identity lint の scope 拡張) が残っており、コミット単位の確定が要る。

## 照合した規約

`kasane/handbook/index.md` → `cross/index.md` (作業ドメイン = cross。domains 定義プロジェクトのため cross のみ) を開き、以下を判定した。

| 文書 | 判定 | 理由 |
|---|---|---|
| handbook/cross/comment-policy.md | 適用 (always) | always: true。本 change はソースコードを触らないため実質の適用面はない |
| handbook/cross/test-execution.md | 適用 | 「テスト実行・テスト結果の報告」= 完了検査で lint を走らせ結果を記録する作業に当たる (指摘 4) |
| handbook/cross/sample-parity.md | 適用外 | `samples/` が存在せず、本 change はデモ画面・文言を触らない |
| handbook/cross/runtime-behavior-verification.md | 適用外 | 実行時挙動の不具合調査・修正ではない |
| handbook/cross/public-identifiers.md | 適用外 | ビルド定義・パッケージ宣言を触らない (指摘 8 は本文書自身への指摘) |
| handbook/cross/local-development-setup.md | 適用外 | 環境構築・Sample 起動・ビルドを行わない |

ksn-core references: `handbook.md` (ファイル形式・index 規約)・`decisions.md` (ADR フォーマット・ガードレール・footer)・`domain-axis.md` (index 構造・採番・参照形式)・`paths.md` (パス記述)・`delta-spec.md` (足場凍結・合意済み差分)。
`kasane/lessons/` は未設置のため `lessons/code-review.md` の読み込みは該当なし。
`kasane/decisions/index.md` から core/ADR-0001・cross/ADR-0001 を、`kasane/concepts/index.md` から概念を確認 (概念は未作成)。
`kasane/config.yaml` の `skills.code-review` は空・`domain-skills.<cross>` は定義しない規約のため、ドメイン固有レビュースキルの読み込みは該当なし (本 change はコードを含まない)。

## 検証 (tasks.md を代替仕様とした完了条件の機械照合)

ビルド・テストは対象外 (ドキュメントのみの変更)。代わりに標準 lint 4 本とリンク解決を本レビューで再実行した。

**lint 再実行結果 (本レビューでの実測)**

| lint | 結果 |
|---|---|
| `scripts/local-path-lint.py` | exit 0 / 違反 0 |
| `scripts/identity-lint.py` | exit 0 / 違反 0 |
| `scripts/doc-structure-lint.py` | exit 1 / 1 件 — `kasane/handbook/cross/comment-policy.md:56` のみ (本 change のスコープ外と tasks 4.1 に明記済み。新規 10 本と roadmap 改訂分に違反なし) |
| `scripts/comment-policy-lint.py` | exit 0 / 禁止 0 件 — **ただし検査対象 0 ファイル** (指摘 4) |

**tasks 完了条件の対応表**

| tasks | 成果物 | 状態 |
|---|---|---|
| 1.1 ADR cross/0002 | `kasane/decisions/cross/0002-monorepo-platform-build-roots.md` | ✅ 2 面構成・ルートに共通ビルドファイルを置かない旨を Decision に明記。翻案元 cross/0001 と照合し、3 ディレクトリ→2 面への縮約と KMP 非ゴール化が Context / Alternatives に正しく反映 |
| 1.2 ADR cross/0003 | `.../0003-public-identifier-namespace.md` | ✅ groupId `jp.kamusoft` / artifactId `kscollectionview` / `jp.kamusoft.kscollectionview.*` / Sample 2 種を全て記載。翻案元 android/0016 が `status: proposed` である事実を出典行で確認 (実地照合済み) |
| 1.3 ADR cross/0004 | `.../0004-sample-cross-platform-parity.md` | ✅ 収束境界 (基盤フェーズの責務 / 両フェーズ完了が最初のゲート / 以降は各変更内) を Decision に明文化。追跡付き片側先行の許容を保持 |
| 1.4 ADR cross/0005 | `.../0005-user-docs-as-agent-skills-and-root-readme.md` | ⚠️ 決定点 5 種 (分割軸と本数 / ロックステップ / README 2 枚と skills/ の関係 / concepts・handbook への読み替え / 持ち込まない条件) は全て本文にある。ただし「翻案元 Decision ごとの採否をドラフト提示時に示す」の提示記録は change 配下に残っていない (指摘 1 と同種) |
| 1.5 ADR 共通規律 | 全 4 本 | ✅ 出典行あり (`出典: <パス> (該当節)` 形式・` / ` 区切り)。翻案元のみの検討は全 4 本で「参考 (翻案元での検討)」として区別。翻案元 cross/0001・cross/0022・android/0016 を実地照合し、捏造なしを確認 |
| 1.6 accepted 昇格ゲート | frontmatter | ✅ 4 本とも `status: accepted` / `date: 2026-09-01`。proposal.md が「status: proposed」と書いたまま据え置かれている点は足場凍結が守られた証跡として妥当 |
| 2.1 sample-parity.md | `kasane/handbook/cross/sample-parity.md` | ✅ 一致必須項目・SampleTheme 方式・許容差異 4 種・収束状態の緩衝設計を保持。翻案元の MAUI 具体例 (`AccessoryViewsDemoPage` 等)・`MinimalDiffableDemoView`・模範例のパスは全て除去され、参照は cross/ADR-0004 と自リポジトリへ張り替え済み |
| 2.2 test-execution.md | `.../test-execution.md` | ✅ 現行規範 2 節 (実行件数確認・収束待ちアサーション) を保持。MAUI 節削除。翻案元の実測件数 (88/338・1261×2・516) は 1 つも持ち込まれず、Simulator scheme は `<パッケージ全体の scheme>` に一般化。iOS / Android 節は「翻案元での実測知見 (KsCollectionView では未検証)」の見出し配下 |
| 2.3 runtime-behavior-verification.md | `.../runtime-behavior-verification.md` | ✅ 前半の一般規約 (再現→解消→証跡・真因断定禁止) を保持し、対象挙動をスクロール・セル再利用へ拡張。翻案元の iOS Basic Cell 目視表 6 行は削除され、追記方針の注記に置換 |
| 2.4 local-development-setup.md | `.../local-development-setup.md` | ✅ 骨格宣言を冒頭に明記。翻案元の具体コマンド・版 (Xcode 16 / JDK 17 / SDK 35 等) は 1 つも持ち込まず、記載する下限は roadmap 前提 (iOS 16+ / minSdk 29) に一致。「版の定義元」「デモ画面一覧は `SampleScreen` 実装が正」の原則を保持 |
| 2.5 public-identifiers.md | `.../public-identifiers.md` | ✅ 翻案元の `ks-settingsview-*` 規則と「Maven 座標の現在地 (drift)」節は不採用。cross/ADR-0003 と整合する現在形で記述 |
| 3.1 decisions/index.md | `kasane/decisions/index.md` | ✅ ドメイン一覧 + 1 行説明のみの薄い地図に再構成 (domain-axis 準拠)。ADR の列挙を撤去 |
| 3.2 core/cross の index 新設 | `kasane/decisions/core/index.md` / `cross/index.md` | ✅ core/0001、cross/0001〜0005 を収載。ID / タイトル / status / 概要の 4 列 |
| 3.3 handbook/cross/index.md | `kasane/handbook/cross/index.md` | ✅ 5 本追記。`always` の comment-policy を先頭に置き「常時 —」と明示 (handbook.md の index 規約どおり)。frontmatter の `always: true` とも一致 |
| 4.1 標準 lint | (記録は tasks.md 本文のみ) | ⚠️ 結果は本レビューで再現。ただし comment-policy が検査対象 0 ファイルの空振り (指摘 4) |
| 4.2 残存検査 | (記録なし) | ❌ 受入基準の数と実体が不一致 (指摘 2)、走査が本 change の変更行を取りこぼし (指摘 3) |
| 4.3 参照検査 | (記録なし) | ✅ 本レビューで機械再検査 — `kasane/` 配下の Markdown 相対リンク全件を解決し、broken 0 件 |
| 4.4 決定対応表 | **不在** | ❌ 「1 件ずつ照合して記録」の記録が change 配下に存在しない (指摘 1)。実体としては本表の 1.1〜3.3 が exploration.md「決定事項」5 項目を全て満たすことを本レビューで確認済み |

判定: **INVALID** (❌ 2 件)。ただし ❌ はいずれも実体の欠落ではなく記録の欠落であり、成果物の修正を要しない。

## 指摘事項

### [🟠 Major] tasks 4.4 の「決定対応表」が完了扱いだが、記録が存在しない

**該当箇所**: `tasks.md:35`

**問題点**: 4.4 は「exploration.md『決定事項』の各項目と成果物の対応を 1 件ずつ照合して**記録**」を完了条件としているが、change ディレクトリには対応表を記録したファイルがない (`exploration.md` / `proposal.md` / `second-opinion-spec-001.md` / `tasks.md` の 4 点のみ)。tasks.md 本文にも照合結果は書かれていない。

本 change は proposal.md:40-42 で「コードの能力に触れないため specs/ を作らない。成果物の正しさは tasks.md の改変チェックリストとレビューで担保する」という逸脱をオーナー承認で通している。その代償措置が tasks.md の完了条件であり、4.4 はその中で唯一「記録」という成果物を要求する項目である。記録がないと、蒸留 (ksn-distill) やアーカイブ後に「何を根拠に決定事項の網羅を確認したか」が辿れない。1.4 の「翻案元 Decision ごとの採否をドラフト提示時に示す」も同様に痕跡が残っていない。

なお実体としては、本レビューの「検証」節で exploration.md「決定事項」5 項目 (handbook 5 本の改変移植 / 根拠の翻案元明記と初期 4 決定の自 ADR 化 / artifactId 先取り / ロードマップ改訂 / 二本立て実施) が全て成果物に対応することを確認済みであり、内容面の欠落はない。

**推奨修正**: 照合結果を change 配下に残す。本レビューの「検証」節の対応表をそのまま流用してよい (`tasks.md` の 4.4 直下に表を書く、または `verify-001.md` を起こす)。1.4 の採否提示についても、翻案元 cross/0022・0023 の Decision 項目ごとの採否行を同じ記録に含めると、ADR-0005 の「持ち込まない条件」が何を落としたのかが後から辿れる。

### [🟡 Minor] tasks 4.2 の許容箇所リストが「3 箇所」と書きながら 4 件を列挙している

**該当箇所**: `tasks.md:33`

**問題点**: 「以下の許容 **3 箇所** …以外に無いこと」と宣言した直後に 4 件 (cross/0005 の MAUI 非対応宣言 / cross/0003 Context の `ks-settingsview-*` 経緯 / decisions/cross/index.md の ADR-0001 タイトル転記 / cross/0002 の「参考 (翻案元での検討)」行) を列挙しており、4 件目には「同一意図のため許容に含める」という後付けの但し書きが付いている。許容箇所リストそのものは合意済み差分として扱うが、**数と実体の食い違いは残る**。この受入基準を後から再実行する人 (drift 検査・別プロジェクトへの再翻案) は、リストが確定版なのか作業中に膨らんだ途中版なのかを判定できない。

**推奨修正**: 「4 箇所」に直し、4 件目の但し書きを他 3 件と同じ体裁 (許容理由の明示) に揃える。

### [🟡 Minor] tasks 4.2 の残存検査が、本 change が書き換えた行を取りこぼしている

**該当箇所**: `kasane/roadmaps/v1-foundation/roadmap.md:28`、`kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:8`

**問題点**: 4.2 は「**全成果物を走査**し『MAUI』『SettingsView』『settingsview』『AiForms』の出現が翻案元参照 (`../KsSettingsView/...` と `出典:` 行) と許容箇所以外に無いこと」を完了条件としている。しかし本 change が書き換えた `roadmap.md:28` は `KsSettingsViewUI` と `../AiForms.CollectionView/` を含み、`../KsSettingsView/` にも `出典:` 行にも許容箇所リストにも該当しない。同じく本 change が編集した phase-3 agenda のファイルにも `ks-settingsview-compose` が残っている (当該行自体は未変更)。

**内容としては問題ない** — どちらも先行実装を指す正当な参照であり、`../AiForms.CollectionView/` は ksn-core references/paths.md の他リポジトリ表記に適合している。問題は、受入基準が literal に実行されていれば必ず引っかかる箇所が [x] のまま素通りしていることで、4.2 の走査が新規作成の 9 本 + index に限定して行われた可能性を示す。走査範囲が宣言 (「全成果物」) と食い違ったまま完了印が付くと、この検査が後から再現できない。

**推奨修正**: どちらかに寄せる。(a) 4.2 の走査対象を「本 change が新規作成した handbook 5 本・ADR 4 本・index 4 本」と明記して範囲を閉じる、または (b) 走査対象を変更ファイル全体のままとし、先行実装参照 (`KsSettingsViewUI` / `../AiForms.CollectionView/` / `ks-settingsview-compose`) を許容箇所として追加する。

### [🟡 Minor] tasks 4.1 の comment-policy lint「PASS」は検査対象 0 ファイルの空振り

**該当箇所**: `tasks.md:32`

**問題点**: 本レビューで再実行したところ `scripts/comment-policy-lint.py` の出力は `合計: 0 ファイル / 禁止 0 件 (検査対象 0 ファイル)` だった。本プロジェクトにはまだソースコードが 1 行も無いため当然の結果だが、tasks 4.1 は 4 本まとめて「全て実行し PASS」とだけ記録している。

これは本 change が導入する `kasane/handbook/cross/test-execution.md:19` の「テストが 1 件も実行されなくてもコマンド自体は成功で終わるため、終了コードだけでは検証したことにならない。**実行件数を確認するところまでが検証**」に正面から当たる形である。自分が現行規範として据えた規律を、その同じ change の完了検査記録が満たしていない。同様に `lint.identity.scope` に追加された `skills` / `samples` も現時点では実体がなく空振りする。

**推奨修正**: 4.1 の記録に検査件数を併記する (例: comment-policy = 検査対象 0 ファイル / 対象ソース未成立のため実質未検証、doc-structure = 既存違反 1 件のみ)。実質未検証であることが読み取れれば足りる。

### [🟡 Minor] 作業ツリーに proposal が申告していない同梱物が残っている (コミット単位の確定が要る)

**該当箇所**: `proposal.md:38`、`kasane/config.yaml:74-76`、`kasane/config.yaml:59-63`、`scripts/comment-policy-lint.py` (新規)、`.claude/settings.json`、`.codex/hooks.json`、`kasane/handbook/cross/comment-policy.md` (新規)

**問題点**: proposal.md:38 は前セッション由来の残存編集として「config.yaml の maui ドメイン除去・各 index の maui 除去修正」だけを本 change に含めると申告している。しかし作業ツリーにはそれ以外に次が未コミットで残っており、このまま commit すれば本 change の成果物として一体化する。

- comment-policy 一式: `scripts/comment-policy-lint.py` (新規)、`.claude/settings.json` / `.codex/hooks.json` への PreToolUse フック登録、`kasane/config.yaml` の `lint.comment-policy` 節 (opt-in 採用宣言)、`kasane/handbook/cross/comment-policy.md` (新規)
- `kasane/config.yaml` の `lint.identity.scope` を `[kasane]` → `[kasane, skills, samples]` へ拡張

`comment-policy.md` の frontmatter は `managed-by: ksn-update` であり、直近コミット「Kasane 標準装備を配布元の最新へ同期 (ksn-update)」の残りと読める。これはハーネス標準装備の導入であって本 change の翻案移植とは別系統の作業であり、ksn-core の「付随修正」の同梱条件 (本務で触るファイル / 本務と同じ能力内) にも当たらない。deviation.md も存在しないため、記録なしの同梱になる。exploration.md:43 が「作業ツリーに残る前セッション由来の編集のコミット単位」を未決の論点として挙げたまま、proposal ではその半分しか解決されていない。

**推奨修正**: comment-policy 一式 + identity scope 拡張を別コミット (ksn-update の続き) に分ける。分けない判断を採るなら、proposal.md ではなく deviation.md に付随物として記録する (proposal は足場として凍結されているため書き換えない)。

### [🟡 Minor] ロードマップ側の参照が、確定済みの ADR ではなく進行中の change を指したままになっている

**該当箇所**: `kasane/roadmaps/v1-foundation/roadmap.md:30`、`kasane/roadmaps/v1-foundation/phases/phase-7-samples-distribution/agenda.md:9`

**問題点**: roadmap.md:30 は「規約と根拠 ADR は [kasane-initial-assets](../../changes/kasane-initial-assets/exploration.md) の change で**整備する**」、phase-7 agenda:9 は「方針 ADR は kasane-initial-assets change で**起草済み**の前提」と、いずれも足場である change を指している。しかし指示対象の長命層は本 change で確定済みであり (cross/ADR-0004・cross/ADR-0005・`kasane/handbook/cross/sample-parity.md`)、読み手を短命層へ迂回させる形になっている。パス自体は ksn-core references/paths.md の archive 解決規則で辿れるが、**確定した知識を足場経由で参照する**のは層モデルの向きに反する。

**推奨修正**: roadmap.md:30 を `kasane/decisions/cross/0004-sample-cross-platform-parity.md` と `kasane/handbook/cross/sample-parity.md` への参照に、phase-7 agenda:9 を `cross/ADR-0005` への参照に張り替える (経緯の出典として change を併記するのは可)。

### [🟡 Minor] concepts/rules.md を改訂しているが timestamp が未更新

**該当箇所**: `kasane/concepts/rules.md:7`

**問題点**: 本 change は rules.md の「ドメイン定義」節から maui を除去する実質改訂を行っているが、frontmatter の `timestamp: 2026-08-26` はそのままである。timestamp は最終検証日であり、ksn-drift の棚卸し判断 (config の `drift.timestamp-threshold-days: 90`) が読む値である。あわせて、proposal.md:38 の申告は「各 **index** の maui 除去修正」であって rules.md は index ではないため、申告範囲からも外れている (指摘 5 と同根)。

**推奨修正**: `timestamp: 2026-09-01` に更新する。

### [🔵 Suggestion] public-identifiers.md の applies-when.paths が bundle ID の宣言箇所を含まない

**該当箇所**: `kasane/handbook/cross/public-identifiers.md:5`

**問題点**: 本文は Apple bundle ID・Android application ID・Sample 識別子まで規定しているが、`paths` は `**/build.gradle.kts` / `**/settings.gradle.kts` / `ios/Package.swift` の 3 つで、Apple bundle ID が実際に宣言される Xcode プロジェクトファイル (`**/*.pbxproj` 等) と Android の `AndroidManifest.xml` を含まない。`tasks: [公開識別子・配布座標の決定]` が受け皿になるが、Sample の識別子を機械的に設定するだけの作業では発火しないおそれがある。翻案元から継承した範囲の問題であり (翻案元も `**/*.csproj` を足しただけ)、対象ファイルがまだ存在しないため実害は出ていない。

**推奨修正**: Sample プロジェクトが生まれる基盤フェーズの時点で `paths` に Xcode プロジェクトファイルと `AndroidManifest.xml` を追加する (今は不要)。

### [🔵 Suggestion] Sample 完了条件が roadmap 前提にしかなく、各フェーズ agenda に落ちていない

**該当箇所**: `kasane/roadmaps/v1-foundation/roadmap.md:32`

**問題点**: exploration.md:21 の決定は「以降の全フェーズ (4〜6, 8) の完了条件に『デモ画面を両プラットフォームへ sample-parity 準拠で追加』」だが、実装では roadmap 前提の包括記述 1 行だけで、phase-4 / 5 / 6 / 8 の agenda は未編集である (phase-2 / 3 には初手タスクとして追記済み)。ksn-agenda はフェーズ議論時に roadmap を読むため実運用上は届くが、agenda 単体を入力にした提案化 (ksn-propose のフェーズ由来入力) では見落としうる。

**推奨修正**: 各フェーズの議論に入る時点で agenda 側にも 1 行落とす (今すぐ全 agenda を編集する必要はない — フェーズ議論の入口で拾えば足りる)。

### [🔵 Suggestion] (スコープ外・既存) agenda の他リポジトリ参照がパス規約から外れている

**該当箇所**: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/agenda.md:15`、`phase-2-ios-engine-foundation/agenda.md:12-13`

**問題点**: `../../../../../AiForms.CollectionView/README-ja.md` のようにファイル位置からの相対で他リポジトリを指しており、ksn-core references/paths.md が定める `../<リポジトリ名>/<相対パス>` (リポジトリルート基準) から外れている。ロードマップがアーカイブへ移動すると段数が狂う。本 change 以前からある行であり、本 change の diff 対象外。

**推奨修正**: 本 change では扱わない。phase-1 / phase-2 の議論でこれらの行に触れる際に `../AiForms.CollectionView/README-ja.md` 形式へ直す。

## アクションプラン

1. **(Major) 4.4 の照合記録を残す** — 本レビュー「検証」節の対応表を `tasks.md` の 4.4 直下か `verify-001.md` へ書き起こす。1.4 の翻案元 Decision 採否も同じ記録に含める
2. **(Minor・優先) 4.2 の受入基準を確定させる** — 「3 箇所」→「4 箇所」に訂正し、走査範囲を「新規 9 本 + index」に限定するか、先行実装参照 (`KsSettingsViewUI` / `../AiForms.CollectionView/` / `ks-settingsview-compose`) を許容箇所に追加する
3. **(Minor・優先) コミット単位をオーナーに諮る** — comment-policy 一式 + identity scope 拡張を別コミットに分けるか、deviation.md に付随物として記録するか
4. **(Minor) 4.1 の lint 記録に件数を併記する** — comment-policy が検査対象 0 ファイルであることを明示
5. **(Minor) roadmap.md:30 と phase-7 agenda:9 の参照を確定済み ADR / handbook へ張り替える**
6. **(Minor) `kasane/concepts/rules.md` の timestamp を 2026-09-01 に更新する**
7. (Suggestion) 8・9・10 はいずれも将来のフェーズで拾えばよく、本 change では対応不要

---

## 再確認 (2026-09-01)

**判定**: CHANGES_REQUESTED → **APPROVED**

修正差分のみを再確認した。初回の Major 1 件・Minor 5 件はすべて閉じている。Suggestion 3 件の見送りは `second-opinion-code-001.md` の突き合わせ結果に採否が記録されており、いずれも将来フェーズで拾える性質のため妥当と判断する。相方セカンドオピニオン由来の 2 件 (roadmap のフェーズ列挙・config.yaml のフェーズ記述) も併せて確認し、どちらも記述の正確性を上げる修正であることを確認した。

### 修正の確認結果

| # | 指摘 | 修正内容の確認 | 判定 |
|---|---|---|---|
| 1 | 🟠 4.4 決定対応表の記録欠落 | `tasks.md` の 4.4 直下に「決定対応表 (2026-09-01 記録)」表を追加。4 行が 4.4 の列挙 (handbook 5 本移植 / ADR 4 本翻案 / artifactId 先取り / 二本立て実施) と 1:1 対応し、exploration.md「決定事項」5 項目のうちロードマップ改訂は「二本立て」行に成果物 (roadmap.md・history.md・phase-2/3/7 agenda) として畳み込まれている。網羅に漏れなし | ✅ 解消 |
| 2 | 🟡 4.2 の「3 箇所」宣言と 4 件列挙の不一致 | 個数宣言を削除し「以下の許容箇所」へ。列挙との矛盾が消えた | ✅ 解消 |
| 3 | 🟡 4.2 が本 change の変更行を取りこぼし | 許容箇所に「roadmap.md の先行実装参照 (`KsSettingsViewUI`・`../AiForms.CollectionView/`)」を追加。許容理由の語彙にも「先行実装参照」を追記。roadmap.md:28 は許容内に入った | ✅ 解消 (残る未変更行については後述の残指摘 B) |
| 4 | 🟡 4.1 の comment-policy lint が空振り PASS | 「各 lint は検査対象の件数まで記録する — comment-policy は検査対象 0 ファイル (ソースコード未存在)」と明記。本 change が導入する test-execution.md の規律に沿う形になった | ✅ 解消 |
| 5 | 🟡 未申告の同梱物 | `proposal.md` Impact に「comment-policy 一式は別セッションの成果で本 change の対象外 — コミット単位はオーナーが分ける」と `lint.identity.scope` 拡張の帰属を追記。同梱物の帰属が明文化された | ✅ 解消 (置き場について残指摘 A) |
| 6 | 🟡 ロードマップが確定済み ADR でなく change を参照 | `roadmap.md:30` を cross/ADR-0004 + handbook/cross/sample-parity.md へ、`phase-7 agenda:9` を cross/ADR-0005 (accepted 済み) へ張り替え。相対リンクは両方とも実在パスに解決することを機械検査で確認 | ✅ 解消 |
| 7 | 🟡 concepts/rules.md の timestamp 未更新 | `timestamp: 2026-09-01` へ更新 | ✅ 解消 |
| 8 | 🔵 Suggestion 3 件 | 見送り。採否と理由は `second-opinion-code-001.md` の突き合わせ表に記録済み | ✅ 妥当 |
| 追加 | (相方) roadmap の「phase-4 以降」が phase-7 を巻き込む | 「phase-4〜6 および phase-8 の機能フェーズ … (phase-7 は配布・ドキュメント専業で対象外)」へ変更し、`history.md` の同表現も同期。phase-7 agenda の「本フェーズの対象外」記述と整合が取れた | ✅ 妥当 |
| 追加 | (相方) config.yaml の identity コメントが旧計画 | 「samples は各プラットフォームの基盤フェーズ、skills は配布・ドキュメントのフェーズで作られる予定」へ分離。現行ロードマップと一致し、Phase 番号にも依存しない書き方になった | ✅ 妥当 |

### 再検査 (本レビューでの実測)

| 検査 | 結果 |
|---|---|
| `scripts/local-path-lint.py` | exit 0 / 違反 0 |
| `scripts/identity-lint.py` | exit 0 / 違反 0 |
| `scripts/doc-structure-lint.py` | exit 1 / 1 件 — `kasane/handbook/cross/comment-policy.md:56` のみ (既知・スコープ外) |
| `scripts/comment-policy-lint.py` | exit 0 / 禁止 0 件 (検査対象 0 ファイル) |
| Markdown 相対リンク全件解決 | broken 0 件 (張り替えた 3 リンクを含む) |
| 残存語の走査 (本 change が触れた 21 ファイル) | 許容箇所リストで説明できない新規混入なし (詳細は残指摘 B) |

### 残指摘

いずれも成果物の内容に影響せず、APPROVED を妨げない。

#### [🟡 Minor・低優先] proposal.md の改訂は逆流検査に当たる形になっている

**該当箇所**: `proposal.md:38`

初回の指摘 5 に対し「comment-policy 一式は対象外・コミット単位はオーナー」という結論を `proposal.md` の Impact に書き足している。結論そのものは正しく、記録の精度も上がっているが、proposal は実装期間中に凍結される足場であり、ksn-verify の逆流検査 (実装期間中に proposal / design / specs が書き換えられていないか) には形式上抵触する。初回レビューの推奨修正も「proposal ではなく deviation.md に記録する」だった。

今回の改訂は実装済み作業を後から正当化するものではなく、受入基準を緩めてもいないため実害はない。コミット前にオーナーが (a) この改訂を意図的な proposal 訂正として合意済み扱いにする、(b) 同じ 2 文を `deviation.md` へ移して proposal を元に戻す、のどちらかを選べば閉じる。

#### [🔵 Suggestion] 4.2 の走査範囲が「全成果物」のままで、既存行 4 件が許容リスト外に残る

**該当箇所**: `tasks.md:31`

4.2 は走査対象を「全成果物」と書いており、本 change が編集したファイルの**未変更行**まで含めて読むと次の 4 件が許容リストの外に残る。本レビューで 4 件すべてを確認し、いずれも正当な参照であることを検証済みのため実害はない。

- `kasane/roadmaps/v1-foundation/roadmap.md:17` — 非ゴールとしての「MAUI 対応 (cross/ADR-0001)」。cross/index.md に与えた許容 (非対応宣言としての意図的言及) と同型
- `phase-2-ios-engine-foundation/agenda.md:12` (`KsSettingsViewSwiftUI`) / `:13` (`../AiForms.CollectionView/`) / `phase-3-android-wrapper-foundation/agenda.md:8` (`ks-settingsview-compose`) — roadmap.md:28 に与えた許容 (先行実装参照) と同型

この検査を後から再現する人 (drift 検査・別プロジェクトへの再翻案) のために、走査対象を「本 change が新規作成・改変した行」と明記するか、上記 4 件を許容箇所へ追記しておくとよい。今回の commit で対応する必要はない。

### アクションプラン (再確認後)

1. コミット前に残指摘 A (proposal 改訂の置き場) をオーナーが確定する — proposal 訂正として合意するか、deviation.md へ移すか
2. comment-policy 一式 (`scripts/comment-policy-lint.py` / hook 登録 / `handbook/cross/comment-policy.md`) を別コミットへ分ける (proposal Impact の申し送りどおり)
3. 残指摘 B は任意。次に 4.2 相当の検査を回すときに走査範囲を明記すれば足りる
