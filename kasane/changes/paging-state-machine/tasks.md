# Tasks: paging-state-machine

## 0. 先に確かめること

- [ ] 0.1 iOS: `contentInsetAdjustmentBehavior = .never` の全画面の一覧 (Sample の既存画面) に `UIRefreshControl` を付け、インジケータをナビゲーションバー・ステータスバーの下に出す手段を Simulator で確かめる。行をバーの裏に流す作り (core/ADR-0017) を保ったまま下げられなければ、作業を止めてオーナーに諮る。取り直し中に `adjustedContentInset.top` が変わるかも記録する (→ Requirement: Pull to Refresh のインジケータ / design Decision 7)
- [ ] 0.2 Android: material3 1.4.0 の `Modifier.pullToRefresh` と `PullToRefreshDefaults.Indicator` が実験的 API か確かめ、実験的なら内部で opt-in する方針を tasks の実装に反映する (→ design Decision 7)

## 1. 公開 API と状態

- [ ] 1.1 iOS: `KsPagingState` (5 値、`Hashable` / `Sendable`) と `.paging(_:threshold:onLoadMore:)`、6 つの表示の modifier (`.pagingAppendingFooter` / `.pagingFailedFooter` / `.pagingEndReachedFooter` / `.pagingLoadingPlaceholder` / `.pagingFailedPlaceholder` / `.pagingEmptyPlaceholder`) を足し、`KsCollectionConfiguration` に載せる (→ Requirement: ページングの状態 / ページングの設定 / ページングの表示)
- [ ] 1.2 Android: `KsPagingState` (enum class) と `public class KsPaging` (状態・次ページ要求・しきい値・6 つの表示)、`KsCollectionView` の `paging` と `onRefresh` の引数を足す (→ 同上 / Requirement: Pull to Refresh の接続)
- [ ] 1.3 公開 API のテスト (iOS `KsPublicAPITests`、Android `KsCollectionViewPublicApiTest`) に新しい型と引数の形を足す (→ Requirement: ページングの設定)

## 2. 発火と待ち方

- [ ] 2.1 両プラットフォームに UI から切り離した `KsPagingRequester` を置く: 発火の式 (0 件で待機なら頼む・待機のときだけ・残り ≦ ceil(しきい値 × 画面に出ている項目の数))、頼んだ時点の状態と配列の版の控え、「処理が終わり、かつ状態か配列の版が変わるまで次を頼まない」、再試行 (失敗のとき、実行中でなければ頼む)、取り消し (→ Requirement: 追加読み込みの発火 / 初回の読み込み / 待機のときだけ自動で頼む / 頼んだ後の待ち方 / 再試行 / 画面を離れたときの取り消し)
- [ ] 2.2 2.1 の単体テスト (両プラットフォーム): Scenario「既定のしきい値で 1 画面分手前で頼む」「しきい値 2」「しきい値 0」「空で待機なら頼む」「終端では頼まない」「失敗では自動で頼まない」「VM が状態の書き換えを遅らせても二重に頼まない」「処理の中で待つ VM」「頼みが無視されたとき」、再試行の 2 Scenario の判定部分
- [ ] 2.3 iOS: 画面に出ている項目の数といちばん後ろの配列上の位置を求める (表示範囲と交わるセルに絞り、`appliedChunkTable.sectionItemRanges` で位置に変える)。`scrollViewDidScroll` を override し、差分の適用の完了時・状態やしきい値の変化・大きさの変化でも判定する。ページングを付けていなければ何もしない。`disconnect()` (dismantle) で実行中の処理を取り消す (→ Requirement: 追加読み込みの発火 / 判定し直すきっかけ / 一覧が破棄されたときの取り消し)
- [ ] 2.4 Android: `snapshotFlow` で表示中の項目 (`KsGroupPlan.itemIndexOfLazy` で項目だけ) のいちばん後ろの位置と数を観測し、状態・配列・しきい値と合わせて判定する。処理は一覧の composition に結びついたスコープで起動する (→ 同上)
- [ ] 2.5 不正なしきい値 (負・非有限) を報告して 0 として扱う (iOS `KsInvalidInput.report`、Android `KsDiagnostics`。値が変わった回に 1 度) (→ Requirement: 不正なしきい値)
- [ ] 2.6 結合テスト (iOS は実レイアウト上、Android は Robolectric): Scenario「グリッドは項目の数で数える」「見出しとフッターは数えない」「1 ページが画面に満たないとき」「失敗から待機に戻ったとき」「回転で画面に出る項目の数が変わったとき」「ページングを付けない一覧」「ライブラリは状態を書き換えない」「画面に項目が出ていないとき」「読み込み中に画面を閉じる」「負のしきい値 (release)」

## 3. ページングの表示

- [ ] 3.1 iOS: ページングを付けた一覧ではルートのフッターの枠を常に置き、枠の中にページングの表示 (上) と利用者のフッター (下) を縦に並べる。表示が無いときは高さを持たない。状態だけが変わったときに見えているフッターの中身をかけ直し、高さの変化を測り直させる。既定の読み込み中は `ProgressView` (→ Requirement: ページングの表示 / design Decision 2)
- [ ] 3.2 Android: ページングを付けた一覧では `KsRootSlotKey.Footer` の項目を常に置き (プランのフッターの有無と remember のキーに反映)、中にページングの表示と利用者のフッターを縦に並べる。既定の読み込み中は `CircularProgressIndicator` (→ 同上)
- [ ] 3.3 両プラットフォーム: 項目が 0 件のときの表示を、一覧の見えている範囲 (上下の安全領域を除く) の真ん中に、ルートのヘッダー / フッターより手前に重ねる (iOS は一覧の上に重ねた入れ物、Android はグリッドの前面)。表示の外のタッチは一覧へ通す。中のボタンが押せること、0 件でも引っ張れること (→ Requirement: ページングの表示 / Pull to Refresh の接続 / design Decision 3)
- [ ] 3.4 失敗の表示の差し替えに再試行の操作を渡し、2.1 の再試行につなぐ (→ Requirement: 再試行)
- [ ] 3.5 結合テスト (両プラットフォーム): Scenario「次のページの読み込み中 (既定)」「最初の読み込み中 (既定)」「失敗・終端・空は既定では出ない」「差し替えた表示が出る」「VM が始めた取り直しの間は項目の上に何も出さない」「状態だけが変わったとき」「0 件の表示がヘッダーと重なっても押せる」「項目があるときの再試行」「0 件のときの再試行」。フッターの枠の追加で、既存のルートのフッター・区切り線・スクロール命令・インジケータ・画像の先読み・端への挿入のテストが通ること
- [ ] 3.6 読み上げ: 既定の読み込み中の表示が、iOS は読み込み中の要素として、Android は不定の進捗の semantics として出ることを自動テストで確かめる (→ design Decision 10)

## 4. 表示範囲の置き方

- [ ] 4.1 iOS: 前回の設定の反映時のページングの状態を控え、`edgeToKeep` で、直前が取り直し中なら先頭を返し、直前が終端以外なら末尾を返さないようにする。塊の件数が変わってアニメーションを切る差し替えでも、直前が取り直し中なら適用の直後に先頭へ合わせる (→ Requirement: 端を表示中の端への挿入 (MODIFIED) / 取り直しの結果は先頭から表示する / design Decision 6)
- [ ] 4.2 Android: `KsPositionKeeper` に前回のページングの状態を控え、`keepEdge` の先頭で、直前が取り直し中なら `requestScrollToItem(0)`、直前が終端以外なら末尾への追従を要求しないようにする (→ 同上)
- [ ] 4.3 結合テスト (両プラットフォーム・list / グリッド): Scenario「追加読み込みで届いたページは今の位置の下に現れる」「最後のページが届くのと同時に終端になる」「終端の後に末尾へ足した項目」「途中で取り直す」「大きな一覧を取り直す」「Pull to Refresh の取り直し」「状態を取り直し中にしない差し替え」。既存の端への挿入の 3 Scenario (ページングなし) がそのまま通ること

## 5. Pull to Refresh

- [ ] 5.1 iOS: `KsCollectionView` で `@Environment(\.refresh)` を読んで設定に載せ、処理があれば `UIRefreshControl` を付ける。`alwaysBounceVertical` を許す。インジケータの規則 (引っ張ってから処理が終わるまで、その後は状態が取り直し中の間) と、状態が追加読み込み中の間と次ページ要求の処理の実行中は `refreshControl` を外す (取り直し中のインジケータを出していないとき)。インジケータの位置は 0.1 の結果に従う (→ Requirement: Pull to Refresh の接続 / Pull to Refresh のインジケータ / 追加読み込みの間は引っ張れない)
- [ ] 5.2 Android: 一覧を `Modifier.pullToRefresh(isRefreshing, state, enabled, onRefresh)` の Box で包み、インジケータを上端に重ねて上端とシステムバーの重なりの分だけ下げる。`enabled = !(状態 == 追加読み込み中 || 次ページ要求の処理の実行中)`。インジケータの規則は 5.1 と同じ。安全領域の測り方 (`KsTopSafeArea`) が変わらない位置に Box を置く (→ 同上)
- [ ] 5.3 テスト (両プラットフォーム): Scenario「引っ張ると取り直しの処理が呼ばれる」「0 件でも引っ張れる」「処理の中で待つ取り直し」「処理がすぐ戻る取り直し」「VM が始めた取り直しでは出さない」「追加読み込み中に引っ張る」「処理の実行中に引っ張る」「追加読み込みが終わった後」。iOS の `.refreshable` の受け取りは `KsSwiftUIIntegrationTests` の形で書く。取り直し中の見出しの固定と先頭の判定が崩れないこと (design の Risks)
- [ ] 5.4 Scenario「全画面の一覧でも見える」を、両プラットフォームの Sample の「ページング」画面で撮った画面で確かめ evidence/ に残す

## 6. Sample「ページング」

- [ ] 6.1 両プラットフォームのメニューに「ページング」を「差分更新」の次に足し、画面の振り分けと起動引数 (iOS `--screen ページング` と `--paging-delay-ms`、Android の開始ルートと遅延の追加値) を足す (→ Requirement: デモ画面「ページング」/ 起動引数)
- [ ] 6.2 偽の取得元 (全 10,000 件・1 ページ 50 件・既定 1 秒の遅延・失敗させる / 0 件の切り替え) と VM (iOS `@Observable @MainActor final class`、Android は Compose の状態を持つ class) を両プラットフォームで同じ振る舞いで作る。次ページ要求は待機か失敗で受け付け、取り直しは項目があれば失敗時に元の状態に戻して「更新できませんでした」を出し、0 件なら失敗にする。取り直しを始めたら世代を進め、前の世代の読み込みの結果は捨てる。「次の読み込みを失敗させる」は次の取得から効かせ、切り替えでは再読み込みしない (「中身を 0 件にする」は切り替えで再読み込みする)。状態と配列は同じ回に書き換える (→ Requirement: 失敗と空の実演 / 取り直しの実演)
- [ ] 6.3 画面: 承認 mock どおりに、操作のパネル (リスト / グリッドの切り替え・2 つの切り替え・「再読み込み」・説明の一行。背景が透け、外周に余白、左端の丸いボタンに畳める) と、Pull to Refresh・失敗 / 終端 / 空の表示の差し替え (同じ文言)・「更新できませんでした」を置く。一覧の下の余白にパネル (畳んだときは丸いボタン) の高さの分を入れる。「中身を 0 件にする」を変えたら再読み込みする (→ Requirement: 失敗と空の実演 / 取り直しの実演 / 操作を畳める)
- [ ] 6.4 Android の Sample の単体テスト: メニューの一致 (`SampleScreenParityTest`)、偽の取得元の並び・件数・終端・失敗・0 件、VM の状態の遷移 (再試行・取り直しの失敗・追加読み込み中の取り直しで古い結果を捨てる・「失敗させる」の切り替えで再読み込みしない)、文言が iOS と一致すること (→ Scenario: 両プラットフォームで同じ構成 ほか)
- [ ] 6.5 iOS の UI テスト (遅延 0 で起動): Scenario「開いたら最初のページを読み込む」「スクロールで続きを読み込む」「次のページの失敗と再試行」「最初の読み込みの失敗」「0 件」「途中から再読み込み」「追加読み込み中に再読み込み」「項目があるときの取り直しの失敗」「畳んで広げる」「末尾の表示が操作に隠れない」「遅延を縮めて開く」。「最後まで読むと終端の表示が出る」は遅延 0 で末尾まで送って確かめる

## 7. 見た目と性能の検証

- [ ] 7.1 承認 mock との視覚照合 (ksn-ui) を両プラットフォームで行い、verification/ に残す (「ページング」画面の 6 つの状態・リスト / グリッド・パネルを畳んだところ、ライブラリの既定の読み込み中の置き場、Pull to Refresh のインジケータの位置)
- [ ] 7.2 状態が変わってフッターの枠の高さが変わるときに、表示範囲が跳ねないことを目視で確かめる (design の Risks)
- [ ] 7.3 「ページング」画面で、両プラットフォームの基準機の体感ゲート (handbook/cross/scroll-performance-gate.md、iOS / Android の performance-verification) を 1 回行う。取得の遅延は 200 ms、リスト表示。構成と判定を evidence/ に残す (→ design Decision 10)
- [ ] 7.4 iOS の内部の塊の件数が変わる追加読み込み (500 件の境目を越える差し替え) の見え方を、7.3 の中で目視で確かめる (design の Risks)
