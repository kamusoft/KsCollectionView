# 議論履歴

## 2026-09-01: 対称性の粒度

- 選択肢: A) 語彙・構造を揃え記法は各プラットフォームの流儀 / B) 記法まで完全対称の独自 DSL / C) 機能セットだけ揃え API は独立設計
- 採用: A。コンポーネント名・パラメータ名・宣言構造を1対1対応させ、modifier 記法・状態保持・非同期処理は流儀に従う
- 理由: 主読者は KMP 量産時に「片方で書いた画面をもう片方に書き写す人」であり、揃えるべきは宣言の頭の中のモデル。B は標準機能 (modifier / `@State` / `remember`) との接続を遮り実装保守コストが跳ねる。C は機能の探し直しが発生し書き写しコスト削減という主目的に反する
- 前提: core/ADR-0001「対称性は公開 DSL の層で担保」の粒度を具体化したもの

## 2026-09-01: コレクションの状態モデル

- 選択肢: A) プレーンな配列 + 安定 ID 必須 + ライブラリが自動差分 / B) スナップショット・差分命令を利用者に明示的に組ませる / C) 安定 ID を要求しない位置ベース
- 採用: A。Swift は `Identifiable` 準拠、Kotlin は `key` ラムダで ID を宣言し、差分計算・アニメ適用はライブラリの責務。内容変更検知は iOS が `Equatable` 同値比較で再構成 (reconfigure)、Android は再コンポーズで自動
- 理由: 両プラットフォームの標準契約 (SwiftUI `ForEach` / Compose `key`) と同型で利用者が既知。iOS diffable / Compose key の内部要求とも一致。B は Compose に対応概念がなく対称性が破綻、C は差分アニメ・再利用・phase-6 の D&D が成立しない

## 2026-09-01: テンプレート種別の宣言方法

- 選択肢: A) データ型ごとの明示登録 DSL / B) 単一コンテンツビルダー内で利用者が switch / when 分岐 / C) データ型自身にテンプレート提供 protocol / interface を実装させる
- 採用: A。`Template(for: Message.self) { msg in MessageRow(msg) }` / `template<Message> { msg -> MessageRow(msg) }` の形でデータ型 → View の対応表を宣言させる。型がそのまま再利用種別になり、iOS の型別 `CellRegistration` / Compose の `contentType` をライブラリが自動導出。クロージャはキャスト済みで型安全
- 理由: 再利用機構は種別の申告を必要とし、B では全アイテムが同一種別に見え異種セルの再利用が劣化 (別途申告させると宣言が二重)。C はデータ層のモデルに UI 依存を強制する。A は宣言構造が両言語で1対1対応し ADR-0002 に整合
- 補足: 議論中に「Message / AdBanner は View か?」の確認があり、データ型 (モデル) であること・View は対応表の右辺で作ることを明確化した

## 2026-09-01: ページング契約の外形

- 選択肢: A) 利用者所有の公開 enum + コールバック (ライブラリはトリガーと標準フッター) / B) ライブラリがページング全体を内包 (データソース抽象 loadPage を渡す) / C) enum を定めず bool フラグ群
- 採用: A。5状態 enum (idle / refreshing / appending / failed / endReached) を VM が所有し、DSL に状態とコールバックを渡す。ライブラリは末尾近傍発火・多重発火抑止・標準フッター (差し替え可)・Pull to Refresh 接続を担う
- 理由: 主目的の KMP 量産では取得ロジック・状態遷移を共有 VM に置きたい。B はデータ所有権がライブラリに移り検索・フィルタとの合成や KMP 統合が悪化。C は不正状態 (refreshing かつ appending 等) が表現できてしまう
- 補足1: 両言語の利用サンプルを提示して確認 (VM 構造がほぼ同一になり KMP 共有可能なことを確認)
- 補足2: 記法差の質疑 — SwiftUI は挙動設定も modifier チェーンが流儀、Compose は Modifier が見た目・レイアウト装飾限定で挙動設定は名前付き引数が流儀。よって Swift `.paging()` / Kotlin `paging =` と渡し方が分かれるのは ADR-0002 の適用として正当
- 残課題: failed にエラー内容を持たせるかは phase-5 (またはサンプル作成時) に詰める

## 2026-09-01: レイアウト指定の DSL

- 選択肢: A) 単一コンポーネント + layout 値1引数 (向き別列数を値で一級サポート) / B) リストとグリッドを別コンポーネントに分ける / C) クロージャで動的計算
- 採用: A。`.list` / `.grid(columns: .fixed(3))` / `.grid(columns: .adaptive(minItemWidth:))` / `.grid(columns: .fixed(portrait:landscape:))` の語彙。内部は iOS が Compositional Layout で全形態を表現、Android はラッパー内で LazyColumn / LazyVerticalGrid に分岐
- 理由: 単一コンポーネントならリスト⇔グリッド表示切替が値の差し替えだけで済み状態が飛ばない。phase-4 のセクション別レイアウトに同じ語彙で拡張できる。向き別列数の一級サポートで利用者の画面サイズ監視ボイラープレートを排除 (自社実績機能)。C は過剰で宣言から静的に読めない (必要になれば値にエスケープハッチとして後付け可)

## 2026-09-01: ソートの表現

- 選択肢: A) DSL に何も足さない (データ層の並べ替え + 自動差分アニメで完結) / B) DSL にソート記述子 (sortedBy 宣言) / C) ソート操作 UI まで提供
- 採用: A。サンプルに「ソート切替」レシピを載せる
- 理由: ADR-0003 の自動差分により配列差し替えだけで移動アニメ付きソートが既に成立。B は配列順と表示順の真実が二重化し phase-6 の D&D と衝突する火種。C は守備範囲超え。後から足すのは追加的変更なので必要が実証されてからで遅くない
- ADR 対象外の判断: 覆すコストが低い (追加的に拡張可能) ため起票しない

## 2026-09-01: スクロール制御

- 選択肢: A) 制御ハンドル + ID ベース命令 → 改訂 A') 命名統一 + VM 直接所有サポート / B) スクロール先を状態として渡す (scrollTarget) / C) 提供しない
- 採用: A'。`KsScrollController` を両プラットフォーム同名で提供。plain オブジェクトで所有位置自由 (View / VM / イベント方式)。未接続 no-op + データ反映後実行の順序保証をライブラリが担う。ドキュメント標準は View 所有、VM 所有もサンプルに載せる
- 経緯: 初案は Kotlin 側を Compose 慣習に寄せて `state` 引数としたが、オーナーが「スクロール専用窓口を state と呼ぶのは意味が違いすぎる。慣習のレベルではない」と指摘し命名統一へ。さらに ColorAnalyzer の ICameraController (VM が interface を直接操作、実装内部で完結) と同構造にできないかの質問を受け、plain オブジェクト化 + 順序保証で VM 直接所有を成立させる A' に改訂
- 一般性の確認: 命令ハンドル方式は Flutter (ScrollController 等) が実証済みの標準設計。「VM 所有」は Compose / SwiftUI 公式ガイドの主流 (イベント方式) から半歩外だが、禁止の実質理由 (UI ライフサイクル縛りのオブジェクトを VM が持つリスク・テスト困難) は plain 化で消えている。残るトレードオフは VM がライブラリ型に依存すること (KMP 共有 VM では利用者が interface を1枚挟んで絶縁)
- B の却下理由: 一度きりの命令を状態で表すとリセット契約 (誰がいつ nil に戻すか) が利用者に漏れる。C は iOS エンジンが UICollectionView のため ScrollViewReader が効かず対称性が破綻

## 2026-09-01: 画像プリフェッチのリソース宣言と専用画像コンポーネント (DSL 外形)

- 選択肢: A) アイテム → リソースのクロージャ宣言 + 専用 KsImage の対 / B) データ型にリソース列挙プロトコルを実装させる / C) 画像を守備範囲外とする
- 採用: A。`prefetchResources` クロージャ (旧 AiForms.CollectionView の実績語彙の継承) と、同一ローダ・キャッシュを見る `KsImage` を対で提供
- 理由: 表示予測はライブラリ・必要リソースは利用者しか知らない分担をクロージャで接続。B はデータ層がライブラリ型に準拠する結合 (ADR-0004 の C 却下と同根)。C はプリフェッチのタイミング情報がライブラリ外に出せず、プリフェッチ⇔描画のキャッシュ分断で二重ダウンロードになる
- 詳細 (ローダ選定・キャッシュ設計・KsImage の機能範囲) は phase-8-image-loading に委ねる

## 2026-09-01: 訂正 — prefetchResources の出典

- 旧 AiForms.CollectionView README の精読により、「prefetchResources は旧ライブラリの実績語彙」という前提が誤りと判明 (旧ライブラリは画像機能を持たず FFImageLoading 推奨のみ)。core/ADR-0008 の出典記述を「外部依存推奨の内蔵化」に訂正した

## 2026-09-01: 旧 AiForms.CollectionView 公開契約の棚卸し

- README-ja.md の全公開語彙を8つの既決定と突き合わせ、引き継ぐ/捨てるを確定 (対応表は agenda 決定事項)
- 発見: 旧 ScrollController (IScrollController を VM が持ち ScrollTo を直接呼ぶ) は ADR-0007 と同設計の実績だった。逆に「prefetchResources が旧実績」は誤りで ADR-0008 を訂正済み (旧は FFImageLoading 推奨のみ)
- 議論による調整2件:
  - TouchFeedbackColor はオーナー要望で「捨てる」から「引き継ぐ」に格上げ。タップ検知とセットで onItemTap / onItemLongTap + フィードバック色指定として提供 (ロングタップも含める判断。iOS は UICollectionView のセル選択・ハイライトの正道で提供できる)
  - 水平レイアウト: 素の Compose は LazyRow で性能込みで書けるが、SwiftUI の LazyHStack は再利用プールなし (本ライブラリの動機と同じ弱点)。ただし実務の水平は少数カルーセルが大半で素で足りるため v1 は縦のみとし、必要になったら roadmap 改訂で追加。端へのスクロール命令名は将来の水平追加で壊れないよう向き中立の scrollToStart / scrollToEnd (旧実績語彙) を採用し、ADR-0007 を改訂
- グループ化一式は phase-4、セル自己サイズ計測 (ColumnHeight 系の廃止根拠) は phase-2、LoadMoreMargin 相当は phase-5 への申し送り
