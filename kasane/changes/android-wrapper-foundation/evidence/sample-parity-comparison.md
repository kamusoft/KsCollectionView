# Sample のプラットフォーム間照合 (iOS ⇔ Android)

デモ 9 画面と各プラットフォーム固有の検証画面を、iOS Simulator (iPhone 17 Pro / iOS 26.5) と
Android エミュレータ (API 36 相当・1080x2340・density 2.75) で同時に起動し、1 画面ずつ並べて
目視照合した結果。照合日: 2026-09-05。

判定の意味:

- **一致** — 文言・件数・初期値・DSL パラメータ・表示結果がすべて同じ
- **許容差異** — 上記は同じで、差は OS 標準 chrome / 既定フォント / 描画差に限られる
  (handbook `cross/sample-parity.md`「許容される差異」)
- **不一致** — 上記のいずれかがずれている

## 対応表

| # | 画面タイトル | 初期データ | 操作 | DSL パラメータ | 表示結果 | 判定 | 証跡 |
|---|---|---|---|---|---|---|---|
| 1 | リスト | `fruits` 6 件 (Apple〜Fig / detail `ID: n`) | 区切り線 3 択 (なし / 既定 / アクセント)、初期は「既定」。タップ / 長押し | `listSeparators` = 選択が「なし」以外、`listSeparatorColor` = 「アクセント」のときのみ accent、`onItemTap` / `onItemLongTap`、タップのフィードバック色 | 1 列。区切り線は先頭上端・行間・最終行下端に全幅。「アクセント」で全区切り線が accent | **不一致 1 件** (タップのフィードバック色。下記「不一致」節) | `../ui/verification/list-default.png` / `../ui/verification/list-accent.png` / `list-ios.png` |
| 2 | グリッド (固定列) | `fixedGridItems` 9 件 (Item 1〜9) | list ⇔ grid 切替、初期は grid | `layout` = grid(fixed 3) / list、grid のとき色見本セル・list のとき行 | 3 列 × 3 行。セルは色見本 44 + タイトル、最小高 106、上端固定・水平中央 | 許容差異 | `../ui/verification/fixed-grid.png` / `fixed-grid-list-android.png` / `fixed-grid-ios.png` |
| 3 | グリッド (adaptive) | `gridItems` 18 件 | なし | `layout` = grid(adaptive minItemWidth 120) | 両プラットフォームとも 3 列 × 6 行 | 許容差異 | `adaptive-grid-android.png` / `adaptive-grid-ios.png` |
| 4 | 向きで列数変更 | `gridItems` 18 件 | 端末の回転 | `layout` = grid(fixed portrait 2 / landscape 4) | 縦向きで 2 列 | 許容差異 | `orientation-grid-android.png` / `orientation-grid-ios.png` |
| 5 | テンプレート切り替え | `templateItems` 30 件 (5 の倍数が `Notice n`、他は `Message n`) | なし | `template` セレクタ = 種別、種別ごとに 2 テンプレート | 5 件ごとに accent 色の通知行 (先頭に丸い印)、他は既定色の本文行 | 許容差異 | `templates-android.png` / `templates-ios.png` |
| 6 | ルートヘッダー/フッター | `fruits` 6 件 | なし | `header` / `footer` | 先頭に「ルートヘッダー」、末尾に「ルートフッター」。どちらも背景色の上に副文字色 | 一致 | `header-footer-android.png` / `header-footer-ios.png` |
| 7 | スクロール制御 | `scrollItems` 100 件 | 「先頭」「Item 50」「末尾」 | `scrollController` (`scrollToStart` / `scrollTo(id = 50, position = center)` / `scrollToEnd`) | 上部に 3 ボタン (accent)。各操作で該当位置へ移動 | 許容差異 | `scroll-control-android.png` / `scroll-control-ios.png` |
| 8 | スペーシングと余白 | `gridItems` 18 件 | スペーシング 0〜16 (初期 4)、余白 0〜24 (初期 8) | `layout` = grid(fixed 2, rowSpacing / columnSpacing = スペーシング)、`contentPadding` = 余白 | 2 列。滑り操作でセル間と外周の余白が即時に変化 | 許容差異 | `spacing-padding-android.png` / `spacing-padding-ios.png` |
| 9 | 大量件数 | `largeItems` 10,000 件 (7 件ごとに長文 detail) | スクロール | `layout` = grid(fixed 2, rowSpacing 1, columnSpacing 1) | 2 列。長文の行だけ高さが伸び、同じ行の対向セルの余りが背景色で見える | 一致 | `large-data-android.png` / `large-data-ios.png` |
| — | ルートメニュー | デモ 9 + 固有検証 1 | 項目の選択 | — | 9 項目がスペックの順で並び、末尾に固有の検証画面 | 許容差異 | `../ui/verification/root-menu.png` / `root-menu-ios.png` |
| — | 検証: 行の高さ変化 (各プラットフォーム固有) | iOS 5 行 / Android 60 行 | 経路 2 択 / レイアウト 2 択 / 行タップで展開 | `layout` = list / grid(fixed 2, spacing 8)、親の状態経路は `onItemTap` | 見出し・経路・レイアウト・展開中の行数・説明文の 5 要素。展開で本文 4 行が下に伸び、上端よりはみ出さない | 許容差異 | `height-change-android.png` / `height-change-expanded-android.png` / `height-change-ios.png` |

固有検証画面は sample-parity の「プラットフォーム固有の技術検証画面」の例外枠であり、デモ画面の
集合には数えない。iOS 側は「(iOS 固有)」、Android 側は「(Android 固有)」でタイトルだけが異なる。
行数が異なるのは、Android 側が spec の Scenario「テンプレート内の状態による展開」(展開した行を
可視範囲と先読み分を超えて送って戻す) を実行できる行数を要するため。例外枠の画面なのでパリティ
義務を負わず、行数をそろえる必要はない。

## 許容差異の内訳 (全画面共通)

| 差異 | iOS | Android | 根拠 |
|---|---|---|---|
| 画面の枠 | `NavigationStack` の nav bar (中央タイトル) | `Scaffold` + `TopAppBar` (左寄せタイトル + 戻る導線) | OS 標準 chrome |
| メニューの行 | 末尾に chevron | chevron なし | OS 標準 chrome |
| 択一の切り替え | segmented picker (灰の溝 + 白い選択) | Material の segmented (accent の枠 + 塗り) | OS 標準 chrome |
| 値の連続変更 | Slider | Material の Slider (溝が分割された図案) | OS 標準 chrome |
| タップ中の表現 | ハイライト塗り | ripple | brief の許容差異 |
| 既定フォント | San Francisco | Roboto | 描画差 |
| 通知テンプレートの印 | 記号図案 (感嘆符入りの丸) | 同じ意味の丸い印を Sample 側で描画 | 図案の提供元がプラットフォーム固有 |
| 長いタイトルの扱い | nav bar が縮小表示 | `TopAppBar` が 1 行省略 (…) | OS 標準 chrome |

## 不一致

**DSL パラメータの不一致が 1 件ある** — 「リスト」画面のタップのフィードバック色。iOS は
`SampleTheme.accent` を 15% の不透明度で渡し、Android は `SampleTheme.accent` をそのまま渡す。
描画結果は揃うが、利用者が同じ値を書いたときの結果は揃わない。原因は本体の意味論の非対称
(iOS は渡された色をそのまま塗り面の背景にする / Android は material3 の ripple が渡された色へ
自前で不透明度を掛ける) であり、Sample の書き分けでは解消できない。

handbook `cross/sample-parity.md`「本体公開 API のプラットフォーム差で一致が不可能な箇所を
黙認しない」に従い、**本体側の統一課題として `deviation.md` に記録した** (4 件目)。統一の方向
の決定は本 change のスコープ外で、後続 change か ADR で扱う。

これ以外の項目 (区切り線の色・位置、grid セルの content 配置、adaptive の列数、件数・初期値・
文言) には不一致がない。

## 照合の手順 (再現方法)

- iOS: `samples/ios/KsCollectionViewSamples.xcodeproj` の scheme `KsCollectionViewSamples` を
  Simulator へ導入し、起動引数 `--screen <画面タイトル>` で目的の画面を直接開く。固有検証画面は
  `--verify-height-change`
- Android: `samples/android` の `:app` を導入し、起動時の追加情報 `ks_start_route` に
  `demo/<画面名>` / `verification/<画面名>` を渡して目的の画面を直接開く
- 静止画はシミュレータ / エミュレータの画面取得機能で撮影する。個人を特定する要素は写っていない
  ことを保存前に確認済み (時刻と電波・電池の図案のみ)
