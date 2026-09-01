# Proposal: kasane-initial-assets

## Why

v1-foundation の実装開始前に、同型 monorepo の先行プロジェクト `../KsSettingsView/` が試行錯誤の末に確立した運用規約と初期決定を移植する。開発初期の今なら、翻案元が後から是正コストを払った問題 (artifactId の drift、docs → skills の作り直し、Sample 差異の蓄積後の是正) を最初から正しい形で敷ける。

## What Changes

1. **handbook/cross へ 5 本を改変移植** (翻案元: `../KsSettingsView/kasane/handbook/cross/`)
   - sample-parity — Sample の全プラットフォーム一致規約 (MAUI 前提の例外枠を削除、参照を張り替え)
   - test-execution — 実行件数確認の規律 (MAUI 節削除、実測値は自前値に差し替え)
   - runtime-behavior-verification — 実行時挙動系の完了判定 (SettingsView 固有の目視表を削除)
   - local-development-setup — 開発環境ガイド (骨格のみ。実構成確定後に phase-2/3 で追随)
   - public-identifiers — 公開識別子の写像 (製品名差し替え + 翻案元 android/ADR-0016 の結論を先取りし `jp.kamusoft:kscollectionview` ブランド 1 トークン)
2. **decisions/cross へ ADR 4 本を翻案起草** (status: proposed。移植ではなく自リポジトリの決定として書く。翻案元を Referencing に明記)
   - monorepo + プラットフォーム別ビルドルート (翻案元 cross/0001)
   - 公開識別子の名前空間 (翻案元 cross/0002 + android/0016 を合体)
   - Sample をプラットフォーム間パリティ検証装置と位置づける (翻案元 cross/0016。roadmap 改訂済みの根拠)
   - 利用者ドキュメント方針: skills/ 方式 + README ルート 2 枚 (翻案元 cross/0022 + 0023)
3. **index の再構成・更新 (domain-axis 準拠)** — decisions/index.md を「薄いドメイン地図」へ再構成し、decisions/core/index.md・decisions/cross/index.md を新設 (現行のインライン表構造の方が ksn-core references/domain-axis.md の規定構造から乖離している)。handbook/cross/index.md に 5 本追記

採番: cross は 0001 が使用済みのため 0002〜0005。

共通の改変方針: platform 固有の実測手順・落とし穴 (Simulator scheme・Robolectric 制約等) は削除せず「翻案元での実測知見 (KsCollectionView では未検証、phase-2/3 で検証)」の注記付きで移植する。現行規範として効かせるのはプロジェクト非依存の規律 (実行件数確認・収束待ちアサーション・完了判定) のみ。

## Non-Goals

- 配布・リリース系 ADR (翻案元 cross/0018/0019/0020) — 翻案元でも proposed のまま未実行。phase-7 の agenda に論点として送付済み
- CI 構成 ADR (翻案元 cross/0025/0026) — CI を書く直前で足りる。phase-7 agenda に論点として送付済み
- lessons/ の移植 — プロジェクト非依存の教訓 18 本は有効との調査所見があるが、器 (lessons/) の設置を含め別 change で検討
- local-development-setup の実測コマンド・版の定義元の確定 — 実構成 (phase-2/3) ができてから追随
- comment-policy / aiforms-origin-reference / user-skill-api-listing の移植 — ユーザー指定の対象外 (comment-policy は設置済み)

## Impact

ドキュメントのみ。コード・公開 API への影響なし、破壊的変更なし、全て可逆。リスクは「翻案元固有の記述 (MAUI・実測値・旧 artifactId 規則) の消し忘れ」で、tasks の改変チェックで潰す。

作業ツリーに残る前セッション由来の編集 (config.yaml の maui ドメイン除去と `lint.identity.scope` 拡張・各 index の maui 除去修正) は、本 change の前提と整合するため本 change に含めて確定する。一方、comment-policy 一式 (scripts/comment-policy-lint.py・hook 登録・handbook/cross/comment-policy.md) は別セッションの成果で本 change の対象外 — コミット単位はオーナーが分ける。

## デルタスペックについて (規約からの逸脱申告)

本変更はコードの能力 (capability) に触れないため `specs/` を作成しない。観察可能な挙動の契約が存在せず、成果物の正しさは tasks.md の改変チェックリストとレビューで担保する。この逸脱はオーナー承認済み (2026-09-01、提案ドラフトの方向性確認にて)。tasks.md が代替仕様として成果物別の完了条件を持つ。

## 級: M

コード変更なしだが、handbook 5 本 + ADR 4 本 + index 4 本 (decisions 地図 + core/cross 新設 + handbook/cross) の相互参照整合を要し S の受け持ちを超える。

domain: cross
