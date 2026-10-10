# 証跡: 4 つの Skill の突き合わせと、Skill の索引 (tasks グループ 7)

2026-10-10 に、4 つの Skill (`skills/{en,ja}/kscollectionview-{ios,android}/`) を実物で突き合わせた結果と、索引 (`skills/README.md`・`skills/README_ja.md`) について確かめたこと。パスはリポジトリのルートからの相対で書く。

## 7.2 4 つの Skill の突き合わせ

### 同じ 6 枚を持つ

4 つのディレクトリのファイルの一覧を取った。どれも次の 6 枚だけを持ち、ほかのファイルは無い。

| ディレクトリ | ファイル |
|---|---|
| `skills/en/kscollectionview-ios/` | `SKILL.md`・`references/basics.md`・`references/images.md`・`references/layout.md`・`references/paging.md`・`references/reorder.md` |
| `skills/en/kscollectionview-android/` | 同じ 6 枚 |
| `skills/ja/kscollectionview-ios/` | 同じ 6 枚 |
| `skills/ja/kscollectionview-android/` | 同じ 6 枚 |

英語版と日本語版の、見出しの深さの並びとコードブロックの一致は、検査 (`python3 scripts/ci/check-skills.py .`) が確かめている。結果は終了コード 0 で、「違反なし (Skill 4 つ・Markdown 24 枚)」だった。

### 相手の Skill に名前だけで触れている

24 枚のすべての行から、相手の Skill の名前 (iOS の Skill では `kscollectionview-android`、Android の Skill では `kscollectionview-ios`) を含む行を拾った。

| ファイル | 行 | リンク |
|---|---|---|
| `skills/en/kscollectionview-ios/SKILL.md` | 12 行目 (冒頭の段落) | 無い (名前だけ) |
| `skills/ja/kscollectionview-ios/SKILL.md` | 12 行目 (冒頭の段落) | 無い (名前だけ) |
| `skills/en/kscollectionview-android/SKILL.md` | 12 行目 (冒頭の段落) | 無い (名前だけ) |
| `skills/ja/kscollectionview-android/SKILL.md` | 12 行目 (冒頭の段落) | 無い (名前だけ) |

拾えたのはこの 4 行だけで、`references/` の 20 枚には、相手の Skill の名前が現れない。Skill の外へ出るリンクが無いことは、上の検査が確かめている。

### 相手のプラットフォームのコードが無い

4 つの Skill のコードブロックを、言語の指定ごとに数えた。

| Skill | Swift | Kotlin | 言語の指定が `text` |
|---|---|---|---|
| `skills/en/kscollectionview-ios/` | 36 | 0 | 1 |
| `skills/ja/kscollectionview-ios/` | 36 | 0 | 1 |
| `skills/en/kscollectionview-android/` | 0 | 34 | 1 |
| `skills/ja/kscollectionview-android/` | 0 | 34 | 1 |

`text` の 1 個は、どの Skill でも `references/paging.md` の発火の条件の式である。相手のプラットフォームの動きは、文の中に 1〜2 文で書いていて、相手のプラットフォームのコードブロックは無い。Android の Skill の本文が iOS の名前に触れるのは、型の名前の `KsTemplate` (その名前の型が Android に無いことの説明) の 1 つだけで、iOS の modifier や関数の呼び出しは書いていない。

### 各 `SKILL.md` の最小の動く例が、README の例と同じである

`SKILL.md` のコードブロックのうち、そのプラットフォームの言語のものを、利用者の立場のアプリの画面のファイルの全体と比べた (前後の空白を除いた文字列の一致)。README の側も、同じファイルと比べた。

| 比べたもの | 相手 | 結果 |
|---|---|---|
| `README.md` の Swift のコードブロック | `verification/ios/Sources/VerificationApp/ItemListScreen.swift` | 一致するブロックがある |
| `README.md` の Kotlin のコードブロック | `verification/android/app/src/main/kotlin/ItemListScreen.kt` | 一致するブロックがある |
| `README_ja.md` の Swift・Kotlin のコードブロック | 上と同じ 2 つのファイル | どちらも一致するブロックがある |
| `skills/en/kscollectionview-ios/SKILL.md`・`skills/ja/kscollectionview-ios/SKILL.md` の最小の動く例 | iOS の画面のファイル | どちらも一致する |
| `skills/en/kscollectionview-android/SKILL.md`・`skills/ja/kscollectionview-android/SKILL.md` の最小の動く例 | Android の画面のファイル | どちらも一致する |

README と各 `SKILL.md` が同じファイルと一致するので、各 `SKILL.md` の最小の動く例は、README の同じプラットフォームの最小コード例と同じコードである。インストール例は、検査 (`python3 scripts/ci/check-readme-examples.py .`) が確かめている。結果は終了コード 0 で、「違反なし (一致した最小コード例 4 つ・確かめた依存の宣言の行 12 行)」だった。

### 5 枚の分け方と見出し

iOS の Skill と Android の Skill は、同じ 5 枚の分け方を持つ。`references/` の見出しのうち、プラットフォームで違うところと理由は、`android-skill-handoffs.md` の「iOS の Skill と見出しが違うところ」に書いた。

### iOS の Skill の側に見つけた、直すところ

iOS の Skill (英語版) の `references/` が Android の動きに触れている行は 16 行ある。これを下の 12 件にまとめ (並べ替えの動きの 5 行は 1 件にした)、Android の実物 (公開の宣言と、Android の Skill の文面) と突き合わせた。誤りは無かった。言い方が粗いところが 1 つあり、表の該当の行に書いた。iOS の Skill の 12 枚は、変えていない。

| iOS の Skill の文 (英語版の見出し) | Android の実物 |
|---|---|
| `basics.md`「Switch templates by item type」: Android では `template` という関数で登録し、`KsTemplate` の型は無い | `KsCollectionViewScope` の `template` と一致する |
| `basics.md`「Read parent state inside a row」: Android では宣言するものが無い | 対応する引数は無い |
| `basics.md`「Handle taps and long taps」: Android は色みだけを使う | `touchFeedbackColor` の説明と一致する |
| `basics.md`「Scroll from code」: Android の末尾への命令は、フッターを含むいちばん最後まで進む | Android の Skill の同じ表と一致する |
| `layout.md`「Group items under group headers」: Android のグループの値は `Bundle` に保存できる型 | `KsGroups` の説明と一致する |
| `layout.md`「Place the list full screen under the bars」: Android の edge-to-edge でも同じ決まり | 一致する |
| `paging.md`「Add paging to a list」: Android のコールバックは例外を投げることができ、ライブラリは伝える | 一致する |
| `paging.md`「Add pull to refresh」: 失敗したとき、Android はスクロールした位置に残る | 一致する |
| `paging.md`「Color the loading indicators」: Android は指定した色がそのまま矢印に付く | `loadingIndicatorColor` の説明と一致する |
| `paging.md`「Know when a running load is cancelled」: Android は次の画面へ進むと取り消される | 一致する |
| `reorder.md`「Know how the drag behaves on iOS」の括弧の中 (隙間の動き・境目・受け入れないとき・取りやめ) | Android の Skill の「Know how the drag behaves on Android」の表と、大筋で一致する。隙間の動きの括弧の中 (Android では指が項目を越えるのに合わせて動く) は、言い方が粗い。Android のリストでは、指の位置ではなく、持ち上げた項目がほかの項目に半分を越えて重なったときに置き場所が入れ替わる (グリッドでは、指がほかの項目の上に入ったとき)。誤りではないので、直すかどうかは指揮側の判断に委ねる |
| `images.md`「Enable the disk cache at launch」: Android ではディスクキャッシュが既定で有効 | 一致する |

## 7.1 Skill の索引

`skills/README.md` と `skills/README_ja.md` を書いた。どちらも、見出しは `#` が 1 つと、その下の `##` が 3 つである。

| 英語版の見出し | 日本語版の見出し | 中身 |
|---|---|---|
| KsCollectionView Skills | KsCollectionView Skills | これが何かと、もう一方の言語の索引へのリンク |
| Skills | Skill の一覧 | 2 つの Skill の名前・対象・扱う内容・`SKILL.md` へのリンク。英語版は `en/` の 2 つ、日本語版は `ja/` の 2 つを挙げる |
| How to install | 導入の手順 | 取得する・ディレクトリごとコピーする・エージェントを開き直す、の 3 つの手順 |
| One language only | 片方の言語だけを使う | 片方の言語のツリーからだけコピーすることと、もう一方の言語を使うときの置き換え方 |

リンクの先が実在することを、4 枚 (索引の 2 枚と、ルートの README の 2 枚) について確かめた。

| ファイル | リンクの先 | 実在 |
|---|---|---|
| `skills/README.md` | `README_ja.md`・`en/kscollectionview-ios/SKILL.md`・`en/kscollectionview-android/SKILL.md` | すべてある |
| `skills/README_ja.md` | `README.md`・`ja/kscollectionview-ios/SKILL.md`・`ja/kscollectionview-android/SKILL.md` | すべてある |
| `README.md` の「Skills」の節 | `skills/en/kscollectionview-ios/SKILL.md`・`skills/en/kscollectionview-android/SKILL.md`・`skills/README.md` | すべてある |
| `README_ja.md` の「Skill」の節 | `skills/ja/kscollectionview-ios/SKILL.md`・`skills/ja/kscollectionview-android/SKILL.md`・`skills/README_ja.md` | すべてある |

索引には、ライブラリの版を書いていない。索引に書いた URL は、本リポジトリの URL (取得のコマンドの中) の 1 つだけである。

## 7.3 識別の検査の範囲のコメント

`kasane/config.yaml` の `lint.identity.scope` の上のコメントのうち、`skills` と `samples` がまだ存在しないと書いていた 2 行を、今の状態に合わせた (`skills` が検査範囲に入っている理由を書く形にした)。`scope`・`allow`・`disable` の値は変えていない。
