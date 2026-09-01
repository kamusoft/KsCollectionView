# Design: ios-engine-foundation

## Context

phase-2 の議論で確定した方式 (ios/ADR-0001〜0004、core/ADR-0003・0004・0006 改訂) を前提に、実装レベルの残judgment を確定する。エンジンの骨格判断 (翻案移植・state 非保持・自前レイアウト統一・薄いラッパー) は ADR 済みのため本書では繰り返さず、パッケージ構成・内部設計・計測手順の実装判断のみを Decision として扱う。

## Goals / Non-Goals

proposal.md の通り (リスト・グリッドの表示・操作まで。ページング/セクション/D&D/画像は後続フェーズ)。

## Decisions

### Decision 1: SwiftPM product は `KsCollectionView` 単一とする

**採用案:** package `KsCollectionView` に product を 1 つ (`KsCollectionView`) だけ置き、公開 DSL とエンジンを同一モジュールに収める (エンジン型は `internal`)。
**理由:** 利用者の import は常に 1 行で足り、公開契約 (handbook/cross/public-identifiers.md) の「接頭辞規則」内で最小。Android 側も単一 artifact と決まっており (同 handbook)、対称になる。
**代替案:**
- **A: `KsCollectionViewCore` / `KsCollectionViewUI` の 2 product 分割** — 却下。KsSettingsView は Core にモデル層を持つため分割意味があったが、本ライブラリのモデルは利用者の型そのもので Core に置くものがほぼ無い。分割は import の説明コストだけ増やす
- **B: エンジンを別 package に切る** — 却下。翻案移植 (ios/ADR-0001) の方針でエンジンは本ライブラリ専用。共有先が無い

### Decision 2: diffable の識別子は `AnyHashable` 化した安定 ID を直接使う

**採用案:** `UICollectionViewDiffableDataSource<KsSectionID, AnyHashable>` とし、item identifier には利用者の安定 ID (`Identifiable.id` または `id:` キーパスの値) を `AnyHashable` に包んで渡す。テンプレートの値キーは識別子に含めず、別引き (ID → item → キー) で解決する。section は v1 では単一 (`KsSectionID.main`)。
**理由:** 配列は単一型 (core/ADR-0004 改訂) なので ID の型内衝突は利用者契約 (安定 ID 必須・配列内一意) が排除し、複合キーは不要。identity と内容の分離 (ios/ADR-0001 の流用骨格) がそのまま成立する。
**補足 (spec-review 反映):** 内容変更検知は `Equatable` (NSObject 継承型は `isEqual`) の同値比較。ID 重複は debug assertion。同一 ID でテンプレートキーが変わった要素は reconfigure ではなく reload (セル置換) 経路 — 先行実装の「具象型が変わったときのみ `reloadItems`」と同型。
**代替案:**
- **A: 型 + ID の複合キー** — 却下。混在配列案 (棄却済み) の遺物で、単一型配列では冗長
- **B: item そのものを identifier にする (Hashable 全体)** — 却下。内容変更が identity 変更と区別できず reconfigure が効かない (先行実装が identity/内容分離で回避した問題の再来)

### Decision 3: 区切り線はセル底辺の hairline サブビューで描く

**採用案:** list レイアウト時、各セルの底辺に高さ 1px 相当の区切り線ビューをライブラリが付与し、セルの位置 (最終行は非表示) に応じて表示を切り替える。位置判定・インセット規則は KsSettingsViewUI の `separatorConfiguration` ロジックを翻案する (描画機構はシステム list 専用のため流用不可 — phase-2 history)。
**理由:** セル単位の描画は再利用・自己サイズ・`rowSpacing` との干渉が最も少なく、`configurationUpdateHandler` で状態連動もできる。
**代替案:**
- **A: `NSCollectionLayoutDecorationItem` で行間に描く** — 却下。decoration はセクション単位が基本で行単位の位置制御が煩雑。将来のセクション対応 (phase-4) で装飾の座を sticky ヘッダ等と取り合う
- **B: セルの SwiftUI content 側に Divider を注入** — 却下。利用者テンプレートの描画領域に干渉し、テンプレートが背景を持つ場合に破綻する

### Decision 4: 向き別列数は sectionProvider の environment 参照で解決する

**採用案:** `.fixed(portrait:landscape:)` は sectionProvider に渡る `NSCollectionLayoutEnvironment` のコンテナ寸法から縦横比 (高さ > 幅 = portrait) を導出して列数を選ぶ — 公開契約は「コンテナ縦横比基準」(core/ADR-0006 に明文化済み、CSS orientation と同義)。変化は `invalidateLayout()` で再評価 (ios/ADR-0001 の実行時参照方式)。
**理由:** environment はレイアウト再計算のたびに正しい寸法を運ぶため、回転通知の購読・手動ハンドリングが不要。
**代替案:**
- **A: `viewWillTransition` で向きを検出して layout 値を差し替える** — 却下。レイアウト差し替えは描画乱れの実績があり (ios/ADR-0001 の Context)、検出タイミングとアニメーションの同期も難しい

### Decision 5: Sample は Xcode プロジェクト直置き + Local Package 参照とする

**採用案:** `samples/ios/` に Xcode プロジェクトを置き、`ios/` の package を Local Swift Package として参照する。bundle ID は `jp.kamusoft.kscollectionview.samples.ios` (handbook/cross/public-identifiers.md)。`SampleScreen` (NavigationStack 共通ラッパー) / `SampleTheme` (共通 RGBA トークン) / ルートメニューの構造は sample-parity 規約の通り。
**理由:** KsSettingsView と同型で、ステップイン開発 (handbook/cross/local-development-setup.md の想定) がそのまま成立する。
**代替案:**
- **A: サンプルも SwiftPM executable にする** — 却下。iOS アプリは SwiftPM 単独で実機実行できず、性能検証 (実機必須) が成立しない

### Decision 6: 性能計測は Instruments テンプレート + 固定シナリオの手動計測とする

**採用案:** 「大量件数」デモ画面 (固定高 + 可変行高混在の 10,000 件、固定シード生成で再現可能なデモデータ) を土俵に、iPhone 11 実機 + Instruments (Animation Hitches) で「3 秒間の連続フリックスクロール × 3 回」の hitch time ratio を計測し、**3 回すべて** 5ms/s 未満を合格とする。メモリは全体 1 往復スクロール後を基準に、さらに 1 往復して増え続けないこと (再利用プール分で定常化) を Xcode Memory Report で確認。手順・基準はまず本 change の evidence/ に計測結果と共に記録して検証し、handbook への規約昇格は ksn-distill で行う (未検証の手順を長命規範に先行固定しない — spec-review 反映)。
**理由:** XCTest の automated performance test は実機 + Instruments の hitch 計測と同精度にならず、初版は再現手順の固定 (機種・操作・回数) で十分。
**代替案:**
- **A: XCUITest + `XCTOSSignpostMetric` で自動化** — 却下 (今回は)。CI に実機がなく自動化の受け皿が無い。phase-7 (CI 整備) で再訪してよい

## Risks / Trade-offs

- `UIHostingConfiguration` self-sizing ×可変行高×10,000 件が基準未達のリスク → エンジン中核完成直後に性能検証タスクを前倒しで実施 (tasks の並び)
- `AnyHashable` 識別子は型情報を失うため、デバッグ時の可読性が落ちる → debug 用の description 付与で緩和

## Migration Plan

新規実装のため移行なし。dsl-samples.md の追随 (phase-2 決定の反映) を本 change のタスクに含める。

## Open Questions

なし (phase-2 議論で全論点解消済み)

## ADR 候補

- Decision 1 (product 単一構成): 公開契約で覆すコストが高い — 蒸留時に ios ドメインで起票検討
- 他は局所的な実装判断のためコード + テストに任せる (ADR 済みの骨格判断は agenda/history 経由で起票済み)
