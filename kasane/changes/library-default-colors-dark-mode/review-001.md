# レビュー結果: library-default-colors-dark-mode (001 回目)

**日付**: 2026-10-06
**判定**: APPROVED

## サマリー

4 つのデルタスペックの要求は両プラットフォームで実装されており、テストは 4 系統とも絞り込みなしで失敗 0 だった (自分で流し直した)。既定の色の値は承認 mock の色の表と一致し、`ui/verification/` の 16 枚の画素を自分で数え直して照合記録を再現できた。Critical / Major は無く、優先度の低い Minor 1 件と Suggestion 2 件だけである。

## 照合した規約

- handbook/cross/comment-policy (always。コメントを書き換えているため全節を照合)
- handbook/cross/test-execution (テストを足し、実行結果を報告しているため)
- handbook/cross/sample-parity (`samples/` の両「リスト」を触っているため)
- handbook/android/performance-verification・handbook/ios/performance-verification (適用範囲に当たるかの確認。Android は proposal の Impact でオーナー判断の例外。歯止めの条件を下で確かめた)
- lessons/code-review.md [L-001] [L-002]

ロードしたスキル: ksn-review、ksn-verify、kotlin-impl-skill

## 確認した観点

**ビルドとテスト (自分で実行。2026-10-06)**

| 系統 | 環境 | 結果 |
|---|---|---|
| iOS 本体 | iPhone 17・iOS 27.0 (作業専用に作り、終了後に削除) | 567 tests / 0 failures |
| iOS Sample | 同上 | 48 tests / 0 failures (ユニット 37 + UI 11) |
| Android 本体 | Robolectric (`--rerun-tasks`) | 512 tests / 0 failures (31 クラス。`KsDefaultSeparatorColorTest` 9・`KsImageDefaultColorTest` 14・`KsImageShownFrameTest` 5 を含む) |
| Android Sample | 同上 | 163 tests / 0 failures (21 クラス) |
| iOS 本体 (参考) | iPhone 15・iOS 17.5 (作業専用に作り、終了後に削除) | 567 tests / 1 件のテストが失敗 (アサーション 2 つ) |

iOS 17.5 で失敗するのは `KsLoadingIndicatorColorTests` の「色を指定した一覧の表示モードが変わると PullToRefresh の部品の色が追随する」だけである。変更前のソース (HEAD を作業ツリーの外へ書き出したもの) で同じテストクラスを iOS 17.5 で流し、同じ 1 件が同じ形で失敗することを確かめた (14 tests / 同じテスト 1 件が失敗)。この変更による退行ではない。この変更で足したテストは iOS 17.5 でもすべて成功した。

**仕様充足**

- デルタスペックの Requirement / Scenario: 満たしている (対応は `verify-001.md`)
- 既定の色の値: 両プラットフォームのソース (`ios/Sources/KsCollectionView/KsDefaultColors.swift:13-26`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsListSeparator.kt:18-21`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:573-588`) と両プラットフォームのテストの期待値が、承認 mock の色の表 (#D9D9DE / #38383A、#E5E5EA / #2C2C2E、#D1D1D6 / #3A3A3C、#8E8E93 / #8E8E93) と一致
- tasks.md の虚偽チェック: 無し。1.1〜4.4 の各項目に対応する実装・テスト・証跡がある
- 足場の書き換え: 無し。proposal.md・specs/・ui/mock/・kasane/decisions・handbook・concepts に HEAD との差分は無い。tasks.md の差分はチェックの付け替えだけ、ui/brief.md の差分は「照合記録」の節の追加だけ
- 無断の仕様逸脱: 見つからない
- 付随修正 (`KsCollectionView.kt:746` の不要な `?.` の除去): 同梱条件に収まる (本務で触るファイル・公開 API に触れない・1 行・動きが変わらず既存のテスト 512 件の通過で担保・選択の分岐なし)

**proposal の Impact の歯止め (項目ごとの仕事量)**

- Android の区切り線: 画面の構成を読むのは一覧ごとに 1 回 (`KsCollectionView.kt:440`)。その値を区切り線とスクロールインジケータで共用しており、変更前より読む回数は増えていない。項目ごとに線を描く処理は変わっていない
- Android の画像: 既定の表示を出す箇所でだけ、画像ごとに 1 回読んで色を 1 つ渡す (`KsImage.kt:320`・`533`・`539`)。利用者の表示を出すときは読まない。先読みを待つ経路は、色が変わったときに宣言を渡し直して描画を無効化するだけで、部品は作り直さない (`KsImage.kt:360-363`)
- iOS: 色は静的な定数 1 つずつで、外観の解決は OS が行う。外観の切り替えでセルは作り直されず、線の色も書き込み直されない (テストが書き込み回数とセルの同一性を見ている)。セルの生成・再利用・自己サイズ・レイアウト生成・snapshot 適用の経路に変更は無い
- 判定: 歯止めの条件を満たす。性能検証を例外にした前提は崩れていない

**テスト**

- Scenario 対応のテスト: ある (Android のタップの色と Sample の値の一致は、提案どおり自動テストではなく証跡とソースの突き合わせ)
- 待ち方: 新しいテストの待機は、実時間の期限・実行機会の譲り・期限超過時の実測値つきの失敗の 3 つを満たす (test-execution「収束を待つアサーション」)。「起きないこと」の検査だけが決まった回数の周回を使っており、用途はコメントに書かれている
- 描画を見る Android のテスト: 3 クラスとも `@GraphicsMode(GraphicsMode.Mode.NATIVE)` 付き
- 期待値の固定: 両プラットフォームとも、ライブラリの定数を読まずにテスト側へ値を直接書いている

**証跡の再現 ([L-001])**

- 1 周目のため「直前のサイクルで修正されたコードの計測値」には当たらないが、`ui/brief.md` の照合記録は自分で再現した: `ui/verification/` の 16 枚について、色の表の各値と一致する画素を数えた。区切り線 (両プラットフォーム・ライト / ダーク)、画像の読み込み中、失敗の下地と印のどれも、該当の画像に色の表の値どおりの画素がまとまって存在し、ダークの画像に変更前の Android の灰色 (#E0E0E0 / #BDBDBD) の面は無かった
- `evidence/android-touch-feedback-opacity.md` (波紋の濃さ) は再実行していない。エミュレータで不透明な色へ一時的に書き換えたビルドが要り、レビューの制約 (実装コードを書き換えない) の中では再現できないためである。該当のコード (`KsCollectionView.kt:452-454`) はコメントの追加だけで動きは変わっていない

**動きの過程 ([L-002])**

- この変更が足すのは色の選び方で、スクロール・高さの変化・レイアウトの切り替えのような過程のある動きは足していない。対象外と判断した

**設計品質**

- accepted の ADR との整合: core/ADR-0010 の色の項は core/ADR-0036 (proposed) が置き換える前提で、提案の段階でオーナーが承認している。core/ADR-0035 (読み込み中の表示の色) には触れていない。衝突は無い
- comment-policy: 公開 doc コメントに ADR ID などの内部用語は無い (ADR の参照は非公開の実装側コメントだけ)。禁止参照・履歴記述は無い。`scripts/comment-policy-lint.py` は禁止 0 件で、要確認 7 件はどれもこの変更が触っていない既存の行
- sample-parity: 両「リスト」が同じ名前のトークンに同じ不透明度 (10%) を掛けた値を渡している
- オーバーエンジニアリング: 無し。新しい型は内部の定数置き場だけで、公開 API は増えていない
- Kotlin の観点 (null 安全・イディオム・コード衛生): 問題なし。`Color.Unspecified` を「既定の表示を描かない」の表現に使う形は、真偽値と色の 2 つを持つより引数が少なく、`remember` のキーも 1 つで済んでいる
- 入力検証・機密情報: 該当なし。`scripts/local-path-lint.py`・`scripts/identity-lint.py` は検出 0 件
- エッジケース: iOS の外観が未指定のときはライトの値になる。Android で `loading` を表示中に付け外ししたときは、変更前と同じく宣言が置き換わるだけである

## 指摘事項

### [🟡 Minor] 並べ替えの持ち上げの証跡画像 4 枚が、どの文書からも参照されていない

**該当箇所**: `evidence/android-reorder-lift-light.png`・`evidence/android-reorder-lift-dark.png`・`evidence/ios-reorder-lift-light.png`・`evidence/ios-reorder-lift-dark.png`
**問題点**: tasks 4.3 (オーナーの目視の準備) の画像と読めるが、change の中のどの文書にも、何をどの環境で撮ったか・何を見るための画像かの記述が無い。ksn-core の references/evidence.md は、証跡を該当の文書から change 相対で参照する形を求めている。蒸留の時点で画像の意味を追えなくなる。優先度は低い (実装とテストには影響しない)。
**推奨修正**: `ui/brief.md` の照合記録か `evidence/` の短いテキストに、4 枚の撮影環境・画面・状態と「影は今回直さず、見え方の確認だけ」であることを 2〜3 行で書く。

### [🔵 Suggestion] iOS で、半透明の指定色がセルのフィードバックまで届くことを 1 本で見るテストが無い

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsPublicAPITests.swift:61`
**問題点**: Scenario「半透明の色を指定する (iOS)」は、足したテスト (設定に不透明度ごと入る) と既存のテスト (`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:364` — 指定した色がセルのフィードバックに入り前面に出る。色は不透明) の 2 本の組み合わせで押さえられている。tasks 1.5 が認めた形で、契約は満たしている。ただし、半透明の色が設定からセルまで通る経路を 1 本で見てはいない。
**推奨修正**: 任意。既存のエンジン側のテストで渡す色を半透明にし、セルのフィードバックの色の不透明度まで見ると、途中で不透明度を落とす変更が入ったときに 1 本で気づける。

### [🔵 Suggestion] Android で、利用者が `LocalContext` ごと差し替えて表示モードを切り替える場合の扱いが書かれていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:213`
**問題点**: 画像の要求の準備は `context` をキーにしている (この変更の前から)。アプリが画面を作り直さずに、構成を上書きした `Context` を `LocalContext` に与え直して表示モードを切り替えると、キーが変わって引き当てからやり直しになる。スペックの約束は「表示モードの切り替えだけでは取得し直さない」で、テストは `LocalConfiguration` だけを差し替える形で確かめており、約束の範囲では満たしている。`Context` ごと差し替える使い方は約束の外だが、利用者への案内の材料にはなる。
**推奨修正**: 実装の修正は不要。蒸留のときに、concepts の利用者への案内の原料へ 1 行足すかを判断する。

## アクションプラン

1. (任意・蒸留までに) 並べ替えの持ち上げの画像 4 枚の説明を change の中に書く
2. (任意) Suggestion 2 件は、採否を蒸留で判断する

未確認として残るもの (この変更の合否には使っていない): iOS 16 (最低対応の版。実行環境が無い)、Android 10・11 の波紋の濃さ (proposal のリスクに記載済み)、`ui/brief.md` のオーナーの最終承認 (照合記録に「まだ受けていない」とある)。
