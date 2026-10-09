# Exploration: ios-release-build-concurrency-warnings

## 課題 / 動機

iOS の本体をリリースの構成でビルドすると、並行性の警告が 2 か所で出る。エラーではなく、ビルドは通る。

- 見つけた文脈: 変更 package-distribution の実装で、iOS の利用者役の確認 (`scripts/ci/verify-consumer-ios.py --mode local`) を流したとき。利用者役は本体をリリースの構成でビルドするので、ふだんのテスト (デバッグの構成) では目に入らない警告が出力に現れた (2026-10-09。Xcode 27.0・Swift 6.4)
- 警告の箇所 (実装ワーカーの報告による。警告の全文は記録していない):
  - `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:256` — 並べ替えのドロップのセッションが終わった後に行う処理を控える関数の中で、受け取った処理を次の周回へ送る行 (`DispatchQueue.main.async(execute: work)`)
  - `ios/Sources/KsCollectionView/KsCollectionViewController.swift:1891` — 適用の時点が「次の周回」のときに、適用の処理を次の周回へ送る行 (`DispatchQueue.main.async(execute: apply)`)
- 警告の種類は、Sendable でない値 (受け取ったクロージャ) の受け渡しとされている
- 動機: 配布を始めると、利用者は本体をリリースの構成でもビルドする。利用者のビルドの出力に、本ライブラリ由来の警告が出る。Swift の版が上がって警告がエラーに変わると、配布物がビルドできなくなる可能性がある

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

未探索 (簡易起票)

- 警告の全文と、警告の種類の正確な名前 (報告の要約しか無い)
- デバッグの構成でも出るか。出ないなら、なぜリリースの構成でだけ出るか
- 2 か所のほかに、同じ形 (受け取ったクロージャを次の周回へ送る) の箇所が無いか
- 直し方 (クロージャの型に主スレッドの隔離を付ける・送り方を変える など) と、公開 API への影響の有無
- 警告を出さないことを、どの検査で確かめ続けるか (利用者の立場のビルドの確認は、今は警告で失敗しない)

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨: S / M / L (理由)

未判定 (暫定は S。内部の 2 か所の直しで、公開 API を変えない見込みのため。調べて公開 API に及ぶと分かれば上げる)
