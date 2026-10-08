# 公開前の確認 (public-repo-verify-ci)

tasks のグループ 6 の記録。Requirement「公開前の確認」の 5 つの確認ごとに、実行した内容・件数・結果を書く。画像そのものは置かない。

## 履歴に残る証跡の画像の目視 (tasks 6.5)

実施日: 2026-10-08。対象の履歴: 提案の commit (`a76c380`) までの全 commit (74 個)。本変更の実装は画像を足していない (実装の commit の後に、足された画像が 0 件であることを確かめ直す)。

### 取り出し方

- 全 commit から届く blob のうち、パスの拡張子が画像・動画・PDF のもの (png / jpg / jpeg / gif / webp / heic / bmp / tiff / pdf / mov / mp4 / svg) を、中身の ID で重複を除いて列挙した
- 結果: 104 件 (png 101・webp 3。ほかの拡張子は 0 件)。置き場は `kasane/changes/*/evidence`・`kasane/changes/*/ui/verification`・`kasane/changes/*/ui/mock`・`kasane/roadmaps/v1-foundation/phases/phase-4-sections-grouping/artifacts`
- リポジトリの外の一時の場所に取り出して見た

### 見た件数と観点

- 見た件数: 104 / 104 (開けなかったものは 0 件)。3 つの独立した調査ワーカーが 35・35・34 件に分けて、1 件ずつ全件を開いた。要確認に挙がった 5 件は、指揮側も画面の上端を開いて確かめた
- 観点: 端末の名前・ホスト名・ユーザー名 / 通知・ほかのアプリの内容 / アカウントの名前・メールアドレス・電話番号 / 位置の情報 / 実在の人物の顔・氏名 / ユーザー名を含むファイルパス・デスクトップやほかのウィンドウの写り込み / 鍵・トークン

### 結果

- 個人の情報が写っている画像: 0 件
- 内訳: iOS の画面 61 件、Android の画面 35 件、UI のモック 8 件。中身は Sample の画面とモックで、データは連番の項目・果物の名前・単色のタイル・サンプルの写真
- 個人の情報ではないが、ほかのアプリに関わるものが写っている画像: 5 件。画面の上端の切り出しをオーナーに示し、「このまま公開する」の判断を得た (2026-10-08)。履歴は書き換えない

| 画像 (履歴の中のパス) | 写っているもの |
|---|---|
| `kasane/changes/android-wrapper-foundation/evidence/height-change-template-state-offscreen.png` | Android のステータスバーに、通知のアイコン 3 つ (盾・チェック・歯車の形)、通知オフの印、電池の残量。文面は無い |
| `kasane/changes/android-wrapper-foundation/evidence/height-change-template-state-restored.png` | 同じ並び |
| `kasane/changes/image-loading/evidence/image-grid-memory-prefetch-after-fix-android.png` | Android のステータスバーに、通知のアイコン 4 つ (盾・チェック・動画のアプリのもの 2 つ) と、ほかにも通知がある印。文面は無い |
| `kasane/changes/image-loading/evidence/image-grid-memory-prefetch-loading-android.png` | Android のステータスバーに、通知のアイコン 4 つ (不在着信・盾・歯車・チェックの形)。発信者・文面は無い |
| `kasane/changes/android-wrapper-foundation/evidence/root-menu-ios.png` | iOS の画面の左上に、直前のアプリへ戻る表示として、兄弟ライブラリの Sample の名前 (途中で省略) |

- サンプルの写真が並ぶ画像グリッドの画面が 10 件ある。顔の分かる人物は写っていない (遠景の小さな人影、手と腕時計だけ)。写真の出どころと利用の条件は、今回の観点の外で確かめていない

### 埋め込まれたメタデータ (目視の補い)

104 件のファイルの中身を機械で読んだ。

- PNG のチャンク: 文字のチャンク (`iTXt`) 12 件と `eXIf` 57 件。中身は色空間と画像の寸法だけ
- ユーザー名を含むパス・メールアドレスの形の文字列: 0 件
- 位置の情報: 0 件 (`GPS` の 3 文字に当たったものが 2 件あったが、どちらも圧縮された画素の列の中の偶然の一致)

### 後片付け

取り出した画像と、オーナーに示した切り出しは、オーナーの判断の後に消した (2026-10-08)。
