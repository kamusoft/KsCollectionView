# Exploration: platform-placement-parity-check

## 課題 / 動機

iOS と Android で、置かれる位置の決まりが揃っていないかもしれない箇所が 3 つある。変更 `user-docs` で、読ませる確認の指摘に答えるために両プラットフォームのコードを読んだときに見つけた (2026-10-10)。どれもコードを読んでの見立てで、動かしては確かめていない。概念の文書には、どれも定めが無いか、両方が同じと書いている。`user-docs` はライブラリの挙動を変えないと決めていたので、直さずに起票した (オーナーの決定)。

- **コードからのスクロールで、項目を合わせる位置**: Android は、コンテンツの余白 (`contentPadding`) の内側に合わせる。iOS は、一覧自身の端に合わせる読みになる (上下の余白を空けない)。`kasane/concepts/core/core-model/collection-interaction.md` は、両方とも余白の内側と書いている。iOS の Skill (`references/basics.md` のスクロールの節) は、コードの読みに合わせて書いてあり、実機では確かめていない
- **幅より狭いヘッダー・フッターの位置**: iOS は中央、Android は始端に置かれる。Android は、ページングを使うかどうかでも枠の作りが違う
- **画像の読み込み中・失敗の表示として渡した中身の位置**: iOS は枠の中央、Android は枠の左上に置かれる

出どころ: `user-docs` の証跡 `evidence/dist-read-dispositions.md` と、実装の報告のスコープ外の発見 (archive 後は `kasane/changes/archive/*-user-docs/`)。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補

## 未決の論点

- 未探索 (簡易起票)
- 3 つとも、まず両プラットフォームで動かして、今の見え方を確かめる
- 揃えるのか、意図した差として残すのか。残すなら、概念の文書と両プラットフォームの Skill に、差として書く。揃えるなら、どちらに寄せるか
- スクロールの位置は、`user-docs` の `deviation.md` の蒸留送り (概念の文書 `collection-interaction.md` を実物で確かめて書く) と重なる。蒸留で確かめた結果を、本 change の出発点に使う

## UI 素材

## 変更級の推奨

未判定
