# Exploration: android-disappearing-items-drawn-outside-bounds

## 課題 / 動機

起票元: ../ColorAnalyzer/kasane/changes/kmp-device-check-issues/exploration.md

- 何が起きたか: ColorAnalyzer の KMP 版 (KsCollectionView 0.1.0-beta.2) の色名辞典の一覧で、Android だけ、グリッドを下へスクロールした状態で絞り込みを変えると、一瞬グリッドの項目が一覧の枠を越えて上に描かれ、上にある検索欄と色相のタブを覆う。100% 再現する (速すぎてスクリーンショットは撮れていない)。iOS では起きない
  - アプリ側の画面: `Column` の中に検索欄・横スクロールのタブ・`Box(Modifier.weight(1f))` の中の KsCollectionView (3 列のグリッド、footer の Spacer、`KsPaging`)。絞り込みを変えると items を空にしてから読み直し、項目の ID は読み直しの世代ごとに変わる (全項目のキーが入れ替わる)
- KsCollectionView に関係する理由: 利用側が何もしなくても、差分の反映 (android/ADR-0006) で一覧の枠の外に描かれる。一覧の上下に部品を並べる画面すべてに出うる

### 原因 (ksn-explore 2026-10-24 にソースで確認)

- Compose foundation 1.11.4 の LazyGrid は、修飾を「利用者の modifier → … → 消えていく項目を描く仕組み (`state.itemAnimator.modifier` = `DisplayingDisappearingItemsNode`) → `scrollableArea` (先頭が `clipScrollableContainer`)」の順に並べる (`lazy/grid/LazyGrid.kt:122-144`)。切り取りは消えていく項目を描く仕組みより内側にしか無い
- 消えていく項目は前の配置での位置 (`finalOffset`) にそのまま、見えている項目より先に描かれる (`lazy/layout/LazyLayoutItemAnimator.kt:541-554`)。上端で一部隠れていた行は負の y に描かれ、一覧の枠より上 (下端で一部はみ出していた行は枠より下) に出る。スクロールしていなければ先頭行の y は 0 以上なので起きない
- Compose 自身の切り取り (`clipScrollableContainer(Orientation.Vertical)`、`ClipScrollableContainer.kt`) は、縦は枠ぴったり・横は影のために左右へ 30dp (`MaxSupportedElevation`) 広げた矩形。見えている項目の見え方は今も「縦ははみ出さない・横は影だけ 30dp まではみ出してよい」
- KsCollectionView は一覧の根 (`BoxWithConstraints`、`KsCollectionView.kt:598`) にもグリッド (`LazyVerticalGrid` の modifier、`:677-692`) にも切り取りを付けていない
- 横に動かない一覧なので、消えていく項目の前の位置は横には枠の中にある。横にはみ出しうるのは影などの装飾だけで、見えている項目と同じ
- 項目に影を付けている既存の利用: ライブラリの並べ替えで持ち上げた項目の影 8dp (`KsReorderLift.kt`)、ColorAnalyzer の項目の影 2dp (`LibraryStyle.kt` の `normalShadow`)
- Compose の issue tracker に同じ報告があるかは、Web の簡単な検索では見つからなかった (未確認)

## 検討した選択肢 (却下案と理由を含む)

- **A: Compose と同じ切り取り (縦は枠ぴったり・横は 30dp 広げる) を、グリッドの外側にも掛ける** — 採用。消えていく項目の上下のはみ出しが無くなり、見えている項目の見え方は何も変わらない。左右の端の影は今と同じく出る (iOS では切れる。この差は今もある)
- **B: 一覧を四辺とも枠で切る (`clipToBounds`)** — 却下。iOS の既定 (切り取る) と四辺とも揃うが、今回の症状と関係ない左右の見え方が変わり、左右の端にある影 (並べ替えで持ち上げた項目の影、利用側の項目の影) が新しく切れる。縦のはみ出し対策に横の変更を混ぜない (ios/ADR-0007 の却下理由と同じ考え方)
- **C: 直さず、利用側に切り取りを付けてもらう** — 却下。利用側が何もしなくても既定機能 (android/ADR-0006) で起きる不具合で、一覧の上下に部品を並べる画面すべてに出うる。起票元の ColorAnalyzer も上流で直す方針 (アプリ側で回避しない)
- 切り取りを一覧の根 (`BoxWithConstraints`) に付ける案 — 却下。根に重ねて置いている表示 (引っ張って更新のインジケータ・0 件のときのページングの表示・追加読み込み中の表示) まで切り取りの対象になる。グリッドに付ければグリッドの中身 (消えていく項目を含む) だけが対象になる

## 決定事項

- A 案: グリッド (`LazyVerticalGrid`) の modifier に、Compose 自身と同じ縦の切り取り (`clipScrollableContainer(Orientation.Vertical)`) を付ける。付ける位置は、消えていく項目を描く仕組みより外側になる利用者側の modifier の中 (グリッドの modifier の中の並び順は実装者の判断。描く範囲が枠の中のスクロールインジケータ・並べ替えのジェスチャには影響しない)
- 一覧の根 (`BoxWithConstraints`) には切り取りを付けない。根に重ねる表示の見え方は変えない
- iOS のコードは変えない (UICollectionView は既定で切り取るため起きない)
- 公開 API・KDoc の利用契約は変えない (縦に枠からはみ出して描く装飾は、今も見えている項目では切れているため、利用者への新しい制約にならない)
- テスト: ライブラリの単体テスト (Robolectric + `captureToImage`。既存の `KsCollectionViewLayoutTest` などと同じ土台) で、一覧の上に別の部品を並べた画面を作る。下へスクロールして先頭の行が上端で一部隠れた状態から、全項目のキーが入れ替わる差し替えをする。時計を止めて消えるフェードの途中で、上の部品の画素が差し替え前と同じであることを確かめる。修正前に落ちることも確かめる。下端側も同じ形で確かめる
- 作業用のエミュレータで、修正の前後を目視で見比べる (起票元と同じ形: 上に部品・下へスクロール・全項目の差し替え)。エミュレータは作業専用のものを作り、最後に削除する
- 性能のゲートはやり直さない (追加は切り取りの層 1 枚だけで、項目ごとの費用は増えない見込み)。エミュレータでの見比べで体感に変化が見えたら報告する
- 蒸留時に反映: concepts android/architecture/compose-wrapper.md — 「配置の変化は `animateItem` で見せ、高さの補間中は止める」の節に 1 段落: Compose は消えていく項目を自分の切り取りより外側で描くため、ラッパーがグリッドの外側にも同じ縦の切り取りを掛けている (横は Compose と同じく 30dp 広げ、左右の影の見え方を変えない)。四辺を切る案は左右の影が新しく切れるため採らなかった

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

なし。単発のバグ修正で、可逆で局所的 (選別基準のどれにも当たらない)。見えている項目の見え方を変えない直し方を選んだため、将来の決定も制約しない。

## 未決の論点

- なし

## UI 素材 (ui/references/ の一覧と注釈)

なし (起票元でも速すぎてスクリーンショットは撮れていない)

## 変更級の推奨: S / M / L (理由)

S。Android の描画の不具合修正で、触るのは 1 つの能力 (Android の Compose ラッパー) だけ。公開 API の変更は無く、修飾 1 つを戻せば元どおりにできる。UI の見た目の仕様は変えない (はみ出しを消すだけ)。
