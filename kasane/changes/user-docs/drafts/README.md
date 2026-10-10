# 草稿の置き場 (変更 user-docs・tasks グループ 11)

蒸留のための下書きを置く。ここにあるものは、まだ `kasane/handbook/`・`kasane/decisions/` に配置していない。配置は、蒸留のときに行う。

各草稿の冒頭の囲み (「草稿の扱い」) に、置き先・index に足す行の案・蒸留のときに確かめ直すことを書いてある。囲みは、配置のときに消す。文書の中のリンクは、置き先から見た相対パスで書いてある (この置き場からは辿れない)。

## 草稿の一覧

| 草稿 | 種類 | 置き先の案 | tasks |
|---|---|---|---|
| [user-skill-refresh.md](user-skill-refresh.md) | 新設 (guide) | `kasane/handbook/cross/user-skill-refresh.md` | 11.1 |
| [user-docs-writing.md](user-docs-writing.md) | 新設 (rule) | `kasane/handbook/cross/user-docs-writing.md` | 11.2 |
| [verification-ci-addition.md](verification-ci-addition.md) | 追記 (6 個) | `kasane/handbook/cross/verification-ci.md` | 11.3 |
| [consumer-build-check-addition.md](consumer-build-check-addition.md) | 追記 (5 個) | `kasane/handbook/cross/consumer-build-check.md` | 11.3 |
| [public-identifiers-addition.md](public-identifiers-addition.md) | 追記 (4 個) | `kasane/handbook/cross/public-identifiers.md` | 11.3 |

## proposal の「蒸留時に反映」の 6 行との対応

| proposal の行 | 対応する草稿 |
|---|---|
| decisions — cross/ADR-0017・0018・0019 を、実装の形で確かめて accepted に昇格する。cross/ADR-0019 を上げるときに、cross/ADR-0005 の側へ、一部が改められたことの印を付ける | 草稿は要らない。蒸留のときに ADR を昇格するだけである (本文は提案のときのまま。出典と現行照合を足す)。昇格のときに確かめる実装の形は、下の「ADR を昇格するときに見る実物」に挙げた |
| handbook — cross に、利用者向け Skill の追従の手順を新設する。`skills/` を触る作業で必ず読まれるように、適用のきっかけにパスを書く | [user-skill-refresh.md](user-skill-refresh.md)。適用のきっかけの `paths` に `skills/**` と `scripts/docs/**` を書いた |
| handbook — cross に、利用者向け Skill と README の書き方の決まりを新設する | [user-docs-writing.md](user-docs-writing.md)。proposal が挙げた 7 項目と、節の対応は、下の表 |
| handbook — `verification-ci.md` に、lint が流すテストへ README と Skill の検査が加わったこと・落ちたときの見方を足す | [verification-ci-addition.md](verification-ci-addition.md) (追記 2 が加わったこと、追記 4 が落ちたときの見方) |
| handbook — `consumer-build-check.md` に、利用者役の画面のソースが README の最小コード例と同じ内容であること・変えるときに README も同時に直すことを足す | [consumer-build-check-addition.md](consumer-build-check-addition.md) (追記 2 が同じ内容であること、追記 5 が同時に直すこと) |
| handbook — `public-identifiers.md` の、依存の書き方を変えるときに同時に直すものに、README と Skill のインストール例を足す | [public-identifiers-addition.md](public-identifiers-addition.md) (追記 2・3) |

### 書き方の決まりの 7 項目と、草稿の節

| proposal・tasks 11.2 が挙げた項目 | `user-docs-writing.md` の節 |
|---|---|
| 公開の宣言の名前を載せる基準と、外す名前の扱い | 公開の宣言の名前 |
| 相手のプラットフォームとの差の書き方 | 相手のプラットフォームとの差 |
| Skill の外への参照の線引きと、URL の一覧の足し方 | Skill の外への参照 (小節「URL と内部の言葉の一覧に足すとき」) |
| インストール例の書き方 | インストール例 |
| コード例のコメント | コード例 |
| 英語版と日本語版の同時更新 | 英語版と日本語版を同じ回に直す |
| スクリーンショットの撮り方と、撮り直すきっかけ | スクリーンショット (小節「撮り方」「保存する前と後に確かめること」「撮り直すきっかけ」) |

このほかに、検査のスクリプトが前提にしている形 (最小コード例の節の見出しの文面・依存の宣言の行はコードブロックの中・frontmatter の値は 1 行・内部の言葉の一覧の足し方) を「構成」「インストール例」「Skill の外への参照」の節に、配った先を再現した確認で分かった書き方の勘どころを「書くときの勘どころ」の節に入れた。

### ADR を昇格するときに見る実物

| ADR | 決定 | 実装の形 |
|---|---|---|
| cross/ADR-0017 | 追従は、オーナーが頼んだときに、前回追従した commit からの源泉の差分をもとに行う。手順は handbook、道具は `scripts/` に置く | 記録は `skills/.manifest.json` (覚えるのは commit の ID 1 つ)。道具は `scripts/docs/skills-refresh.py`・`check-api-coverage.py`。検証 CI は、源泉とのずれを検査していない (`evidence/checks-and-refresh-tools.md` の 8.2)。手順は、草稿 `user-skill-refresh.md` |
| cross/ADR-0018 | インストール例に具体の版を書かず、`{version}` を置く。最新の版は Release の一覧で確かめてもらう | README の 2 枚と 4 つの `SKILL.md` の例が `{version}` で、検査 (`scripts/ci/check-readme-examples.py`) が、具体の版と、確かめ先の URL が無いことを落とす。確かめ先は仮の値である |
| cross/ADR-0019 | Skill の外への参照は、知識を委ねるものを持たず、操作の対象になる URL は持ってよい。cross/ADR-0005 の該当の 1 文を置き換える | 許可する URL は `scripts/ci/user-docs-rules.json` の 4 つ。検査 (`scripts/ci/check-skills.py`) が、Skill の外のファイルへのリンクと、一覧に無い URL を落とす。相手の Skill には名前だけで触れている (`evidence/skills-cross-check.md`)。昇格のときに、cross/ADR-0005 の側へ、一部が改められたことの印を付ける |

## 蒸留のときに決める・確かめ直すこと (草稿をまたぐもの)

- 新設する 2 枚の名前 (`user-skill-refresh.md`・`user-docs-writing.md`)。変えるなら、5 枚の草稿の中のリンクを直す
- `user-skill-refresh.md` の「初回と同じ確かめ方をする場面」と、`user-docs-writing.md` の「撮り直すきっかけ」は、書き手の案である。オーナーが確定する
- `apiExclusions` (公開の宣言のうち、Skill に載せない名前) は、草稿を書いた時点では空で、iOS の 2 つの名前をオーナーに諮っている途中である。決まった後に、2 枚の草稿の「今の一覧」「今、外している名前」を埋める
- 追従の記録の更新 (`record`。tasks 12.5) は、草稿を書いた時点ではまだ流していない。流した後に、`user-skill-refresh.md` の該当の節を実測で確かめ直す
- 本変更の作業ツリーは、草稿を書いた時点で commit していない。検証 CI の上での値 (スクリプトのテストの件数と所要時間・書き直した利用者役の実行) は、push の後に確かめて埋める
- 最新の版の確かめ先と、README の「まだ公開していない」の 1 文は、リリースの工程を決めるフェーズ (phase-7-4) が扱う。草稿は、仮の値のまま書いてある
- 使わせる確認で挙がった分かりにくいところを、草稿を書いたのと同じ回に Skill に直した (`evidence/dist-use.md` の最後の表)。草稿の「書くときの勘どころ」は、その直しを含めて書いてある
