# 議論履歴

## 2026-09-01: agenda 整理 (議論開始)

- 論点 9 個 + phase-1 申し送り 5 項目で定量トリガー (8 論点以上) に該当したが、膨張ではなく単一 change の側面の細分列挙と判断。分割 (ksn-split) は不適 (サブフェーズが単独完了できない) として、論点統合を採用
- 申し送り 5 項目を親論点の子項目に吸収 (安定 ID・未登録型 → テンプレートマッピング、自己サイズ・タップ/ハイライト → セルホスティング、スクロール順序保証 → DSL ラッパー)。「旧 AiForms 先行実装参照」は論点から参考資料に降格。結果 7 論点に整理
- 議論順: 依存の要であるエンジン構成から開始

## 2026-09-01: エンジン構成 — 先行実装の取り込み方

- ksn-scout で KsSettingsViewUI と旧 AiForms.CollectionView のエンジン構成を調査。流用可能な骨格 (identity/内容分離の diffable・型解決機構・`UIHostingConfiguration` ホスティング・diff 駆動の SwiftUI ラッパー・実行時参照レイアウト) と設定画面特化部分 (セクション箱装飾・Theme 契約・list 固定レイアウト) の切り分けを得た
- 選択肢: A) 設計パターンの翻案移植 (コピーして汎用化、依存なし) / B) 共通基盤をパッケージに切り出し両者で共有 / C) ゼロから新規設計
- 採用: **A**。理由: 流用可能な骨格は汎用化がほぼ済んだ形で存在する一方、データモデル (セクション必須・セル型有限) とレイアウト (list 固定) は要件と根本的に違うため、コード共有より「コピーして汎用化」が安く安全。KsSettingsView 移植時 (kasane-initial-assets) と同じ方式。B の共通化は将来共通部分が増えた時点で改めて判断
- ios/ADR-0001 として起票 (proposed)。旧 AiForms からは方式面で持ち帰るものなし (レンダラ寿命管理・手動フレーム・固定高さの 3 課題が `UIHostingConfiguration` 方式で解消済みという位置づけを確認)

## 2026-09-01: セルホスティング — セル再利用時の state の扱い

- 適用方式・自己サイズ・はみ出し対策・タップ/ハイライト (core/ADR-0009) は翻案移植の実証済みパターンで解消。残る設計判断は再利用時の SwiftUI state のみ
- 選択肢: A) 状態は保持されない仕様とし、残したい状態はデータモデル側に持たせる / B) 再利用をまたいで状態を保つ独自機構を作る
- 採用: **A**。理由: core/ADR-0003 (プレーン配列 + ライブラリ責務) の思想と一貫。先行実装 KsSettingsView も同方針 (ホスティング作り直し、コストは実測で許容)。SwiftUI には `@State` を退避・復元する公式の口がなく、B は複雑なわりに壊れやすい
- 付帯: 利用者向けドキュメントに明記が必要な仕様。ios/ADR-0002 として起票 (proposed)

## 2026-09-01: テンプレートマッピング (a) — 混在配列と安定 ID の取り出し方

- 初案は phase-1 の ADR-0004 (データ型ごとの登録) を前提に「合成 protocol (`KsItem` = Identifiable & Equatable) 準拠の `[any KsItem]` を渡す」を提示 → **オーナーが棄却**。理由: (1) ライブラリ protocol の強制でモデルが View に引っ張られ純粋なデータでなくなる、(2) 異種混在の配列を持たせる開発は実態と合わない — 想定は「配列は単一型、`item.kind` のような種別プロパティでテンプレートを分ける」だった
- 練り直し案: **値キーによるテンプレート切り替えを基本形にする** (`template: \.kind` + `Template(キー値)`)。キーは `Hashable` なら何でもよく有限個推奨 (enum が最安全)。キー値ごとに `CellRegistration` / `contentType` を自動導出し、再利用両立の本質は維持。型ベース切り替えは副次変種として残す。単一型配列になるため Swift 存在型の問題 (型消去・ID 衝突・比較) 自体が消滅
- 追加論点 (オーナー指摘): KMP 共有モデルは `Identifiable` / `Equatable` に準拠できない → ID 宣言を **`Identifiable` 準拠 or `id:` キーパス指定の二本立て** (`ForEach` と同型) に拡張。`Equatable` 相当は Kotlin/Native の equals→isEqual 写像で data class なら自動成立。Android 側は KMP モデルがそのまま Kotlin なので課題なし (key ラムダ・contentType・再コンポーズで成立) と確認
- 採用: 上記 4 点セット。core/ADR-0004 を値キー基本形に改訂、core/ADR-0003 の ID 宣言を二本立てに改訂 (いずれも proposed のため in-place 改訂)。dsl-samples.md の追随を TODO 化

## 2026-09-01: テンプレートマッピング (b) — 未登録キーの挙動

- 選択肢: A) debug は assertion で即停止 / release は最小高の空セル + 警告ログ、B) 常にクラッシュ、C) 該当アイテムを非表示
- 採用: **A**。理由: 登録漏れは開発時バグなので debug では最大の音量で知らせ、release ではライブラリ起因でアプリを落とさない (サーバー由来 String キーに未知の値が来る運用起因もありうる)。C は静かに消えて気づけない上、件数・indexPath 整合を崩すフィルタ層が必要
- ADR-0004 の Consequences に残していた残課題をこの決定で解消 (本文更新)。新規 ADR は不要と判断 (ADR-0004 の一部として記録)

## 2026-09-01: レイアウト — システム list に乗せるか自前統一か

- 選択肢: A) 全レイアウトを自前 compositional セクションで統一 (リスト = 1 列グリッド) / B) リストだけシステム list (`.list(using:)`)、グリッドは自前
- 採用: **A**。理由: layout 値切り替え・向き別列数を単一 sectionProvider + 実行時参照方式で完結でき、レイアウト・セル基底の二系統跨ぎ (描画乱れの再来リスク) を避けられる。システム list の恩恵 (スワイプアクション等) は v1 非ゴール
- オーナー修正: 区切り線は「提供しない」ではなく **list レイアウト専用のオプションとしてライブラリが自前描画で提供する** (グリッドは非対象)。Android も divider をライブラリが描き、同じ宣言・既定で対称にする。既定値 (表示/非表示) は継続論点
- ios/ADR-0003 として起票 (proposed)。区切り線オプションの DSL 外形は既定値決定後に core/ADR-0006 へ反映する

## 2026-09-01: レイアウト (続) — 区切り線の既定値と流用範囲

- 選択肢: A) list は既定で表示 (opt-out) / B) 既定は非表示 (opt-in)
- 採用: **A**。理由: リストを選ぶ利用者の大多数は区切り線を期待する (無指定で期待通り)。Android も同じ既定でライブラリが描くため対称性は保たれる。core/ADR-0006 に反映
- オーナーから「KsSettingsView の区切り線実装を流用できそう」の示唆 → 実物確認の結果、同実装はシステム list 専用機構 (`UIListSeparatorConfiguration` + `itemSeparatorHandler`、KsSettingsViewController.swift:511・:868) のため、システム list を使わない方針 (ios/ADR-0003) では**描画機構は流用不可**。位置判定・インセット規則・Theme 色解決のロジックのみ翻案流用と整理

## 2026-09-01: SwiftUI DSL ラッパー — 内部構成とルートヘッダー/フッター

- 選択肢: A) KsSettingsViewSwiftUI の Store + 独自 diff 計算層 (`DSLDiffCalculator`) まで踏襲 / B) 薄い Coordinator 直結 (差分計算は diffable data source に任せる)
- 採用: **B**。理由: KsSettingsView に独自 diff 層が必要だったのはモデルが階層ツリー + 可視性 projection の特殊構造だったため。今回はプレーンな配列 + 安定 ID (core/ADR-0003) なので差分計算は diffable の本来の仕事。内容変更検知のみ `FullSnapshotContentTargets` 方式を翻案。スクロール命令の順序保証 (core/ADR-0007) は Coordinator のコマンドキュー + apply completion で flush
- オーナー追加要望: **ルートヘッダー/フッターの入れ物** (KsSettingsView と同種の体験)。`header:` / `footer:` クロージャで提供し、iOS は boundary supplementary、Android は Lazy 系の先頭・末尾 item で実現。KsSettingsView の当該機構は設定画面特化 (scout 確認) のため仕様のみ踏襲し実装は新規。phase-1 に無かった DSL 語彙のため dsl-samples 追随 TODO に追加
- ios/ADR-0004 として起票 (proposed)

## 2026-09-01: Sample scaffold — デモ画面構成 / スペーシングの抜けの検出

- デモ画面は決定事項と 1 対 1 対応の案 (リスト / グリッド固定列 / グリッド adaptive / 向きで列数変更 / テンプレート切り替え / ルートヘッダー・フッター / スクロール制御 / 大量件数) を提示し、オーナー承認
- 承認と同時にオーナーが **phase-1 の抜け**を検出: スペーシング・余白の議論が漏れている。棚卸し (core/ADR-0009) を確認した結果、`BothSidesMargin` / `SpacingType` 等は「contentPadding / spacing へ簡素化 (詳細 phase-4)」と先送り、**`RowSpacing` / `ColumnSpacing` は棚卸し表から漏れ**ていた。グリッドのデモに必須のため、基本のスペーシング・余白は本フェーズで決めると整理 (グループ単位余白のみ phase-4 のまま)
- デモ画面に「スペーシングと余白」を追加して **9 画面で確定**。新論点 8「スペーシングと余白の DSL」を agenda に追加

## 2026-09-01: スペーシングと余白の DSL

- 提案: 行間・列間は layout 値のパラメータ (`rowSpacing` / `columnSpacing`)、画面端余白はコンポーネントレベルの `contentPadding` (4 辺) の 2 段構成。旧語彙対応: `RowSpacing`→`rowSpacing`、`ColumnSpacing`→`columnSpacing` (有効レイアウトの制約撤廃)、`BothSidesMargin`→`contentPadding` (左右→4 辺に一般化)、`SpacingType`→廃止 (adaptive は Between 相当のみ、需要が出たら後付け)、`GroupFirstSpacing`/`GroupLastSpacing`→phase-4。既定値は 0
- 採用: **上記の通り確定**。オーナー補足で意味論を明確化: `contentPadding` は「本体とスクロールコンテンツの間の内側余白」であり外側マージンではない。**スクロールバーは padding に左右されず本体の端に留まる** (iOS `contentInset` 系 / Compose `contentPadding` の標準挙動と一致)
- core/ADR-0006 (layout 値へのスペーシング語彙追加) と core/ADR-0009 (棚卸し表の漏れ修正) を in-place 改訂

## 2026-09-01: 性能検証方法

- 提案: Sample「大量件数」画面 (10,000 件グリッド、画像なし) を土俵に、実機 + Instruments Animation Hitches (合格 = hitch time ratio 5ms/s 未満) + メモリ非比例の確認。手順は handbook/ios/ に規約化 (KsSettingsView の performance-verification の翻案)。シミュレータは目安のみ
- オーナー回答: 手持ち実機は iPhone 11 / iPhone 15 / Pixel 4a / Pixel 6a → **iOS 基準機 = iPhone 11 (15 は参考)、Android 基準機 = Pixel 4a (6a は参考、phase-3 申し送り)**
- オーナー追加: **可変行高セルを土俵に混ぜる** — 自己サイズ計測 (`UIHostingConfiguration` self-sizing) が最も計測コストの乗る部分のため、固定高のみでは本丸を測り損ねる。「大量件数」デモは固定高 + 可変行高 (テキスト長ランダム) の混在で確定
- 以上で全論点が決定事項へ昇格。残 TODO は spec 化系 (dsl-samples 追随・ksn-propose) のみ

## 2026-09-01: 提案化 (ksn-propose) と spec-review 由来の追加決定

- change [ios-engine-foundation](../../../../changes/archive/2026-09-04-ios-engine-foundation/proposal.md) を L 級で作成 (proposal / design / specs 3 能力 / tasks / ui)。モックは案 A「システム調」を承認 (SampleTheme トークン確定)
- ksn-second-opinion (codex / spec-review) が NEEDS_DISCUSSION — 仕様の穴 9 件を採用して spec に反映 (詳細は change の second-opinion-spec-001.md)。オーナー判断 3 件:
  1. **前提 ADR 12 件 (core/0002〜0009・ios/0001〜0004) を accepted に一括昇格** (内容は phase-1/2 の議論でオーナー承認済みのため)
  2. **型ベーステンプレート変種は v1 実装から除外** (存在型の設計がまるごと必要になる一方、値キー + enum で全て書ける。API の将来余地としてのみ残す — proposal の Non-Goals)
  3. **向き別列数はコンテナ縦横比基準** (高さ > 幅 = portrait。CSS orientation と同義、端末の物理向きではない)。命名は `narrow`/`wide` 等への改名を検討の上、「主語が曖昧になる・portrait/landscape は形を 1 語で的確に表す・CSS 先例と旧 API 連続性」を理由に **portrait / landscape を維持**。core/ADR-0006 に意味論と却下案を明文化して accepted へ
