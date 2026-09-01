# セカンドオピニオン: kasane-initial-assets (spec-001)
**相方**: codex / **label**: so-spec-kasane-initial-assets / **日付**: 2026-09-01 / **対象**: 提案一式 (proposal.md / tasks.md / exploration.md。デルタスペックなしは逸脱申告済み)
---
# レビュー結果: kasane-initial-assets

**日付**: 2026-09-01
**判定**: **NEEDS_DISCUSSION**
**指摘件数**: Critical 0 / Major 7 / Minor 2 / Suggestion 0

## サマリー

移植の方向性自体は合理的ですが、承認されていない判断を handbook の現行規範にする順序、domain-axis との構造衝突、未構築環境に対する手順書の先行作成など、実装前にオーナー判断が必要な穴があります。

`specs/` を作らない技術的理由は妥当です。観察可能なコード挙動がないため、無理にデルタスペックを作るべきではありません。ただし、M 級の必須成果物を省略する規約上の例外としては、自己申告だけでなく明示的な承認と代替検証基準が必要です。

## 照合した規約

- ksn-core の層モデル・S/M/L 判定
- delta-spec の用途と M 級成果物
- domain-axis の ADR index 構造・採番規則
- decisions の proposed → 人間確認 → accepted パイプライン
- handbook の規範性・品質基準・書き込み時 lint
- paths の参照形式
- ソースコメント規約（always。今回はソース変更がないため実質適用外）
- core/ADR-0001、cross/ADR-0001
- v1-foundation の roadmap / agenda / history
- 翻案元の該当 handbook 5 本と ADR 6 本

## 指摘事項

### [🟠 Major] デルタスペック省略の理由は妥当だが、規約上の例外承認と代替仕様がない

**該当箇所**: `proposal.md:36`、`tasks.md:26`

**問題点**: M 級はデルタスペック必須ですが、今回の文書変更には観察可能な挙動契約がなく、`specs/` を作っても意味のある Scenario になりません。この判断自体は妥当です。一方、proposal の自己申告だけでは規約例外が承認済みにならず、代替となる tasks も文書単位の必須内容・禁止内容・完了条件を十分に固定していません。

**推奨修正**: `specs/` は作らず、「文書のみの M 級例外としてオーナー承認済み」であることを proposal に記録してください。そのうえで、各成果物について必須節、持ち込まない固有記述、必須参照、完了検査を tasks に列挙し、tasks を代替仕様として成立させてください。

### [🟠 Major] ADR index の方針が domain-axis 規約と衝突している

**該当箇所**: `proposal.md:20`、`proposal.md:42`、`tasks.md:23`、`kasane/config.yaml:10`

**問題点**: `config.yaml` は domains 運用を宣言しています。この場合、ルート `decisions/index.md` は薄いドメイン地図とし、`decisions/core/index.md`、`decisions/cross/index.md` に ADR を列挙するのが規定構造です。ところが tasks は domain 別 index を作らないと明記しています。また proposal は「index 3 本」と数えていますが、What Changes と tasks には2本しかありません。

**推奨修正**: domain-axis に合わせて root index を薄い地図へ変更し、少なくとも `decisions/core/index.md` と `decisions/cross/index.md` を作るタスクを含めてください。更新・新設する全 index をファイル名で列挙し、数量も一致させてください。

### [🟠 Major] proposed ADR を根拠に handbook rule を即時有効化する順序になっている

**該当箇所**: `tasks.md:11`、`tasks.md:15`、`tasks.md:19`

**問題点**: 全 ADR を `status: proposed` で作る一方、同じ変更で、それらを根拠とする handbook rule を現行規範として設置します。特に public-identifiers の翻案元 `../KsSettingsView/kasane/decisions/android/0016-single-module-single-maven-artifact.md:4` 自体も proposed です。また、「翻案元に存在する代替案を使う」という指示では、KsSettingsView で検討された案をKsCollectionViewでも検討済みだったかのように記録する危険があります。

**推奨修正**: ADR ドラフト作成後にオーナー確認を置き、accepted への昇格後に対応する handbook rule を有効化するゲートを tasks に追加してください。Alternatives はこのプロジェクトで実際に再検討したものだけを記載し、翻案元のみの議論は「参考」と明示してください。標準の footer は `Referencing` ではなく必須の `出典:` 形式に揃える必要があります。

### [🟠 Major] 未構築のビルド・テスト環境に対して実装固有手順を先行移植しようとしている

**該当箇所**: `proposal.md:11`、`proposal.md:13`、`proposal.md:29`、`tasks.md:16`、`tasks.md:18`

**問題点**: 現在は `ios/`、`android/` の実構成がありません。それにもかかわらず、test-execution は Simulator scheme、テストターゲット、Robolectric、Gradle task を保持する計画です。翻案元の同文書は「実際に実行して確かめた手順だけを書く」規範であり、この段階ではKsCollectionView用として検証できません。local-development-setup も、利用者が開いたときに実行可能な手順を得られない「骨格だけの現行 guide」になります。

**推奨修正**: 現時点では「実行件数まで確認する」「条件ベースで収束を待つ」などプロジェクト非依存の規律だけを移植してください。具体コマンド、scheme、task、Robolectric固有制約、local setup guide は phase-2/3 で実測後に作るか、今回の対象から外してください。

### [🟠 Major] CI・バージョン・配布方針が roadmap と Non-Goals で矛盾している

**該当箇所**: `proposal.md:26`、`proposal.md:27`、`kasane/roadmaps/v1-foundation/roadmap.md:26`、`kasane/roadmaps/v1-foundation/phases/phase-7-samples-distribution/agenda.md:7`

**問題点**: proposal は lockstep、配布、CI を phase-7 の未決論点として除外しています。一方 roadmap は CI構成・lockstep・配布方式を「前提 / 制約」として踏襲済みと断定しています。phase-7 で判断するはずの事項が、既に決定済みの前提として後続フェーズを縛っています。

**推奨修正**: 今回決めない事項は roadmap でも「候補・phase-7 で決定」に戻してください。前提として残すなら、今回ADR化してオーナー承認を通し、phase-7 では再決定ではなく実装論点だけを扱う構造にしてください。

### [🟠 Major] Sample パリティの収束境界が曖昧で phase-2/3 を相互ブロックし得る

**該当箇所**: `tasks.md:9`、`exploration.md:21`、`kasane/roadmaps/v1-foundation/roadmap.md:29`

**問題点**: ADR タスクは「各フェーズの完了条件化」としていますが、phase-2 は iOS、phase-3 は Android の個別フェーズで並行可能です。各フェーズ単独に「両プラットフォームのSample一致」を課すと、片方の責務外実装まで要求するか、互いに完了できなくなります。翻案元の規約が許容する「追跡付き片側先行」を、新ADR・tasksで保持することも明示されていません。

**推奨修正**: phase-2/3 は各自の scaffold と追随タスクを責務とし、両フェーズ完了時を最初のパリティ収束ゲートにする、と明文化してください。phase-4〜6・8は各変更内で両プラットフォームを揃える、などフェーズ別の完了条件を固定してください。

### [🟠 Major] 利用者ドキュメントADRの翻案範囲が不足している

**該当箇所**: `proposal.md:19`、`tasks.md:10`

**問題点**: 翻案元ADRには、MAUIを含むSkill数、AiForms移行Skill、manifest、docs-refresh、閉世界性、skills配下とルートのREADMEの区別、開発者知識の配置など多数の決定があります。現在の1行だけでは、何を採用し何を破棄するか決まりません。特に「開発者向け知識は concepts」は、現在のKasaneでは契約は concepts、規範・手順は handbook という層分離へ読み替える必要があります。

**推奨修正**: 翻案元のDecision項目ごとに採用／変更／対象外の対応表を作ってください。最低でもSkillの本数・名称、en/ja構造、知識源、更新方式、閉世界性、ルートREADMEとSkill索引の関係、開発者向け契約と手順の配置を確定してください。MAUI・SettingsView・AiForms・翻案元固有docs-refreshを持ち込まない条件も明記してください。

### [🟡 Minor] 前セッション由来の編集を本変更へ含めるか未決のまま残っている

**該当箇所**: `exploration.md:7`、`exploration.md:43`

**問題点**: config、concepts/index、decisions/index、handbook/index、roadmapなどに既存の未コミット編集がありますが、どれを本変更へ含めるか proposal/tasks に引き継がれていません。実装時に変更範囲へ混入するか、必要な前提だけ取り残される可能性があります。

**推奨修正**: 対象ファイル一覧に「本変更へ含める／別変更／既存変更として維持」を明記し、含めるものは What Changes と tasks に追加してください。

### [🟡 Minor] 改変チェックが事後判定可能な形になっていない

**該当箇所**: `tasks.md:15`、`tasks.md:28`、`tasks.md:29`、`tasks.md:30`

**問題点**: 「61行」は移植元の行数であり、翻案後の品質基準になりません。「決定事項4点」も exploration の箇条書き数と一致しません。リンク切れ確認の方法がなく、handbook作成時に必須の identity・doc-structure lint もありません。実際に現状の `doc-structure-lint.py` は、今回改訂された `kasane/roadmaps/v1-foundation/roadmap.md:29` を違反として検出します。

**推奨修正**: 行数条件を削除し、照合対象を名称で列挙してください。標準 lint 4本、Markdown相対リンク解決、ADR・handbook frontmatter検査、各決定と成果物の対応表を完了条件にしてください。

## アクションプラン

1. `specs/` を作らない文書変更例外についてオーナー承認を記録する。
2. ADRの承認順序、今回決める事項とphase-7へ送る事項を確定する。
3. domain-axis準拠のindex構造と、既存未コミット編集の所属を確定する。
4. 未検証のtest/setup文書を今回作るかphase-2/3へ延期するか決める。
5. Sampleの収束ゲートと利用者ドキュメント方針を具体化する。
6. tasksを事後判定可能な検査項目へ書き直し、doc-structure違反を解消する。

制約に従い、`review-NNN.md` は作成していません。

---

## 突き合わせ結果 (ホスト側判定: 2026-09-01)

ホスト側の自己レビュー (2周) との突き合わせ。裏取り: domain-axis 規約 (M2) と doc-structure-lint 実行 (Min2) はホスト側で再現確認済み。

| 指摘 | 採否 | 対応 |
|---|---|---|
| M1 スペック省略の例外承認 | 採用 | オーナー承認 (2026-09-01、propose Step 3 の方向性確認で承認) を proposal に記録 |
| M2 domain-axis の index 構造衝突 | 採用 (確定) | 規約で裏取り。decisions/index.md を薄い地図へ再構成し core/cross のドメイン別 index を新設する方針に変更。現行のインライン表構造の方が規約乖離だった |
| M3 proposed ADR → handbook 即時規範化の順序 | 採用 | ADR ドラフトのオーナー確定 (accepted 昇格) を handbook 最終化の前ゲートとしてタスク化。Alternatives は翻案元の検討を「参考 (翻案元での検討)」と明示、footer は `出典:` 形式 |
| M4 未検証手順の先行移植 | 一部採用 | 削除ではなく「翻案元での実測知見 (KsCollectionView では未検証、phase-2/3 で検証)」の注記付きで移植する。プロジェクト非依存の規律 (実行件数確認・収束待ち) のみ現行規範。phase-2/3 の agenda に検証追随を明記 |
| M5 roadmap 前提と Non-Goals の矛盾 | 採用 | roadmap 前提の CI・lockstep を「候補 (phase-7 で確定)」表現に改訂。skills/ 方式は本 change の ADR で確定するため前提に残す |
| M6 phase-2/3 の相互ブロック | 採用 | 「phase-2/3 は各自 scaffold + 追随タスク、両者完了時が最初の収束ゲート、phase-4 以降は各変更内で両プラットフォームを揃える」を roadmap 前提と ADR タスクに明文化 |
| M7 docs ADR の翻案範囲不足 | 一部採用 | 完全な対応表は作らず、ADR ドラフトで確定すべき決定点 (Skill 構成・en/ja・README との関係・concepts/handbook への読み替え・持ち込まない条件) をタスクに列挙。ドラフト提示時に翻案元 Decision ごとの採否を示す |
| Min1 前セッション編集の帰属 | 採用 | proposal Impact に「本 change に含めて確定する」を明記 |
| Min2 検査の事後判定可能性 | 採用 | 行数条件を削除し、標準 lint 実行・リンク解決・決定対応表を完了条件化。roadmap.md の lint 違反 (:28/:29) は本セッションで修正 |

降格: なし / 未解決: なし。判定 NEEDS_DISCUSSION の討議点はすべて上記の採用形でオーナーに提示し確認を得る。
