> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/consumer-build-check.md`
> - proposal の「蒸留時に反映」にある、利用者役の画面のソースが README の最小コード例と同じ内容であること・変えるときに README も同時に直すことを足すための草稿である
> - 追記は 5 個ある。それぞれの見出しに、追記先の節と、足すのか置き換えるのかを書いてある
> - 文書の中のリンクは、追記先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - 中身は、2026-10-10 時点の実物 (`verification/ios/Sources/VerificationApp/ItemListScreen.swift`・`verification/android/app/src/main/kotlin/ItemListScreen.kt`・`MainActivity.kt`・`scripts/ci/check-readme-examples.py`) と、手元での確認の記録 (`evidence/consumer-screen-source.md`・`dist-use.md`) から書いた
> - 確認のスクリプト・ひな形・ビルドの定義・成功の条件は、本変更で変えていない。追記先の、それらを説明している節は直さない
> - **書き直した利用者役は、検証 CI の上では、まだ 1 回も走っていない** (書いた時点で commit していない)。手元では、切り替えを `local` にして両プラットフォームが成功している。`main` 宛ての Pull Request で成功を見た後に、追記 4 の日付と文面を確かめ直す
> - リンク先の「利用者向け Skill と README の書き方」「利用者向け Skill の追従」は、同じ変更で新設する文書 (草稿は `user-docs-writing.md`・`user-skill-refresh.md`)。置き先の名前が変わるなら、リンクも直す
> - `timestamp` は、蒸留で置く日にする

---

## 追記 1: frontmatter と冒頭の段落の直し

`description` の末尾に、画面のソースと README の関係が分かる言葉を足す。

```
description: 配布物を利用者と同じ書き方で取る利用者役の形 (画面のソースは README の最小コード例と同じ内容)、手元での流し方、検証 CI での走り方、失敗したときの見方、確かめた範囲と確かめていないこと、変えるときの注意
```

`applies-when` の `paths` は変えない (`verification/**` が、画面のファイルを含んでいる)。`tasks` に、次の 1 つを足す。

```
利用者役の画面のソース (README の最小コード例の元) の変更
```

## 追記 2: 節「利用者役」の表の下に、小節を 1 つ足す (小節「切り替え」の前)

### 画面のソースは、README の最小コード例と同じ内容である

利用者役の画面のソースは、プラットフォームごとに 1 つのファイルで、ルートの README の最小コード例と、各 `SKILL.md` の最小の動く例に、ファイルの全体がそのまま載っている。利用者が README から貼るコードが、import まで含めて、この確認でビルドしたものになる。

| プラットフォーム | 画面のファイル | 形 |
|---|---|---|
| iOS | `verification/ios/Sources/VerificationApp/ItemListScreen.swift` | モデル `Item` と画面 `ItemListScreen` を 1 つのファイルに置く。コメントと `public` を持たない |
| Android | `verification/android/app/src/main/kotlin/ItemListScreen.kt` | モデル `Item` と画面 `ItemListScreen` を置く。package の宣言を持たず、`import` から始まる。コメントを持たない。Material に依存しない書き方 (`BasicText`) である |

- Android の入口 (`MainActivity.kt`。利用者役のアプリの package の下にある) は、package の宣言を持つ。package の宣言を持たないファイルの画面を呼ぶために、画面の名前だけを書いた import (`import ItemListScreen`) を 1 行持つ
- この import を消すと、名前を解決できずにビルドが落ちる
- 画面のファイルの形 (1 つのファイルであること・コメントが無いこと・Android が package の宣言を持たないこと・入口が名前だけの import で呼ぶこと) は、スクリプトのテスト (`scripts/ci/tests/test_verify_consumer_ios.py`・`test_verify_consumer_android.py`) が実物を見て確かめる
- README の最小コード例がこのファイルと同じ内容であることは、検査 (`scripts/ci/check-readme-examples.py`) が確かめる。検査は、lint のジョブのスクリプトのテストの中で、push のたびに流れる ([検証 CI](verification-ci.md))。`main` 宛ての Pull Request を待たずに、食い違いに気付ける
- 各 `SKILL.md` の最小の動く例がこのファイルと同じ内容であることは、検査が見ない。画面のファイルを変えると、追従の道具が「変わった源泉」として出す ([利用者向け Skill の追従](user-skill-refresh.md))

載せ方の決まりは、[利用者向け Skill と README の書き方](user-docs-writing.md) にある。

## 追記 3: 節「失敗したときの見方」に、段落を 1 つ足す (小節「iOS」の前)

> 画面のファイルを変えた push では、利用者の立場のビルドの確認より先に、lint の `CI script tests` が落ちることがある。README の最小コード例と画面のファイルが食い違ったとき (README の例の検査) と、画面のファイルの形が決めた形でなくなったとき (コメントを足した・Android に package の宣言を足した・iOS のファイルを分けた) である。見方は [検証 CI](verification-ci.md) の「失敗したときの見方」にある。

## 追記 4: 節「確かめた範囲と確かめていないこと」の小節「コード縮小の後の動き」の末尾に、段落を足す

> 画面のソースを README に載せる形 (Android は package の宣言を持たないファイル) に書き直した後、2026-10-10 に、コード縮小を有効にした利用者役を、作業専用のエミュレータ (Android 16・API 36) でもう 1 回起動した。一覧の最初の画面が表示され、落ちなかった。コード縮小の対応表には、新しい画面の名前があった。このときは、スクロールを操作していない。

小節「確かめていないこと」の表に、次の 2 行を足す。

| 確かめていないこと | 分かっていること |
|---|---|
| 書き直した利用者役の、ランナーの上での実行 | 【`main` 宛ての Pull Request で成功を見たら、この行を消す】手元では、切り替えを `local` にして、両プラットフォームが成功している |
| Skill の `references/` のコード例のビルド | この確認がビルドするのは、画面のファイル (README の最小コード例と同じ内容) だけである。`references/` の例は、書いた・直したときに、作業用の置き場でコンパイルして確かめる ([利用者向け Skill と README の書き方](user-docs-writing.md)) |

## 追記 5: 節「変えるときの注意」の表に、行を足す

| 変えるもの | 守ること |
|---|---|
| 利用者役の画面のファイル (`ItemListScreen.swift`・`ItemListScreen.kt`) | README の 2 枚の最小コード例と、4 つの `SKILL.md` の最小の動く例を、同時に同じ内容に直す。README の直し漏れは検査が落とすが、`SKILL.md` の直し漏れは検査が見ない。コメント・`public`・package の宣言・利用者に関係の無い行を足さない (そのまま README に載る)。Android は、Material に依存しない書き方を保つ (利用者役のモジュールは Material に依存していない) |
| 利用者役の画面のファイルの名前・置き場 | 検査 (`scripts/ci/check-readme-examples.py`) が持つパス、スクリプトのテストが持つパス、追従の記録 (`skills/.manifest.json`) の `sources` のパスを、同時に直す |
| Android の入口 (`MainActivity.kt`) | 画面の名前だけの import を消さない。入口を package の宣言を持たないファイルにしない (マニフェストの入口の名前の書き方まで変わる) |
| 利用者役のモジュールの依存 | 足さない。足すと、README の最小コード例が、利用者に余分な依存を求める例になる。最小コード例に要る依存は、README と `SKILL.md` の例の下に書いてある |

同じ表の「利用者が書く依存の書き方 (Package URL・package の名前・座標)」の行の「守ること」を、次に置き換える。

> 利用者役のひな形と依存の行、README の 2 枚と 4 つの `SKILL.md` のインストール例を、同時に直す ([公開識別子と配布座標](public-identifiers.md))。インストール例の値が利用者役の値と違うと、README の例の検査が落ちる

節「知っておく制限」の箇条に、次を足す。

> - 利用者役の画面は、配った先を再現した確認 (利用者向け Skill だけを渡したエージェントに画面を書かせて、ビルドする確認) の入口にも使う。そのときは、作業ツリーを写した作業用の写しの中で画面のファイルを入れ替え、本リポジトリの利用者役は入れ替えない。Android の作業用の写しには、SDK の場所を書いた設定ファイル (`local.properties`) を足す。足さないと、本体の発行で止まる ([利用者向け Skill の追従](user-skill-refresh.md))

節「関連」に、次の 2 行を足す。

> - [利用者向け Skill と README の書き方](user-docs-writing.md) — 最小コード例を、利用者役の画面のファイルと同じにする決まり
> - [利用者向け Skill の追従](user-skill-refresh.md) — 画面のファイルを変えた後に、`SKILL.md` の例を直す流れ

出典の行に、次を足す。

> 【蒸留のときに、archive のパスで書く】変更 `user-docs` の design.md (Decision 4) / `evidence/consumer-screen-source.md` (書き直した形・`local` の確認・コード縮小の後の起動)
