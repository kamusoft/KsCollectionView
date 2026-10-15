# Exploration: ios-invalid-input-handling-gaps

## 課題 / 動機

iOS で、誤った指定 (不正入力) を渡したときの動きが、概念の文書と Android の動きから外れている箇所が 4 つある。変更 `user-docs` で利用者向け Skill を書くとき、書く事実をコードの実物と突き合わせる中で見つけた (2026-10-10)。どれもコードを読んでの見立てで、動かしては確かめていない。`user-docs` はライブラリの挙動を変えないと決めていたので、直さずに起票した (オーナーの決定)。Skill は、今のコードの動きに合わせて書いてある。

- **幅で列の数を決める指定に 0 以下の幅を渡すと、リリースビルドで落ち得る**: `ios/Sources/KsCollectionView/KsLayoutMetrics.swift` の列の数の計算で、最小の幅が 0・列の間隔が 0 のとき、0 での割り算が無限大になり、整数への変換で落ちるように読める。Android は 1 dp として扱って表示を続ける。不正入力はリリースビルドで落とさない方針 (core/ADR-0011) に合わない疑い
- **列の数に 0 以下を渡したとき、リリースビルドで警告のログが出ない**: `ios/Sources/KsCollectionView/KsCollectionLayout.swift` は素の `assert` だけで、リリースビルドでは黙って 1 に丸める。`kasane/concepts/core/styling/collection-layout.md` は「release では警告ログを出して表示を継続」と書いている
- **同じテンプレートのキーを 2 つ登録しても、デバッグビルドで停止しない**: `ios/Sources/KsCollectionView/KsTemplateRegistry.swift` は、デバッグビルドでも後の登録を採用して警告のログを残すだけである。`kasane/concepts/core/core-model/collection-items.md` は「assertion」と書いていて、Android は停止する
- **並べ替えの公開の説明のコメントが、Android の動きを書いている**: `ios/Sources/KsCollectionView/KsCollectionView+Reorder.swift` の `reorder` のコメントの「見出しより上に置けば前のグループの末尾、下に置けば次のグループの先頭」は、`kasane/concepts/core/core-model/collection-reorder.md` では Android の動きで、iOS は別の動き (指を止めた項目との関係で決まる)

出どころ: `user-docs` のレビュー (`review-001.md` の Major) と、実装の報告のスコープ外の発見 (archive 後は `kasane/changes/archive/*-user-docs/`)。概念の文書の側を今のコードに合わせる分は、`user-docs` の `deviation.md` に蒸留送りとして記録してある。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補

## 未決の論点

- 未探索 (簡易起票)
- 1 つ目は、実際に落ちるかを動かして確かめる (最小の幅 0・列の間隔 0 の組と、負の幅)
- 概念の文書とコードのどちらを正とするか (コードを概念の文書と Android に揃えるのか、iOS の今の動きを決まりとして概念の文書を直すのか)。`user-docs` の蒸留が概念の文書を今のコードに合わせた場合は、本 change でコードを直すときに、概念の文書と Skill (`skills/{en,ja}/kscollectionview-ios/references/basics.md` の不正入力の表) も合わせて直す
- 不正入力の扱いを、両プラットフォームで表にして突き合わせる (ほかに外れている行が無いか)

## UI 素材

## 変更級の推奨

未判定 (挙動の修正とテストの追加で済むなら S。不正入力の方針の見直しに及ぶなら M)
