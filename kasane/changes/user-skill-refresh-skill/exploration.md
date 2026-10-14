# Exploration: user-skill-refresh-skill

## 課題 / 動機

利用者向け Skill の追従は、cross/ADR-0017 で、手順を handbook のガイド (`kasane/handbook/cross/user-skill-refresh.md`) に、道具を `scripts/docs/` に置き、専用の Skill を作らないと決めていた。オーナーから「Skill を生成する docs-refresh の Skill が無いが、現状どうなっているか」と問われて確かめたところ、次の穴があった。

- 頼んでも手順にたどり着く保証が無い。handbook の索引を作業の前に開くのは、コード・テストに触れるワーカー (ksn-implement / ksn-ui / ksn-review / ksn-live) だけである (`~/.claude/skills/ksn-core/references/handbook.md`「読み込み」)。メインのセッションには決まりが無い
- ガイドを指す記述も無い。AGENTS.md (CLAUDE.md はここへのリンク)・`skills/.manifest.json`・`scripts/docs/skills-refresh.py` の冒頭のどれにも無い
- 普通の運用では呼ばれない。ksn の流れ (探索・提案・実装・蒸留) に、Skill への影響を見るステップが無い
- ガイドの「公開 API を変えた後にこの文書を開いたら、報告でオーナーに知らせる」は、ガイドの中にある。`skills/` に触れない変更では読まれない
- モデルの使い分けを持てない。兄弟ライブラリの docs-refresh (`../KsSettingsView/.agents/skills/docs-refresh/SKILL.md`) は、書き直しを低コストのモデルのワーカー (ksn-scribe) に任せている。ワーカーを呼び分けるのはメインのセッションなので、メインに読まれない handbook のガイドには持たせられない。今のガイドもモデルの話を持たない

ADR-0017 が見込んだ補い方 (`skills/` を触る作業でガイドが必ず読まれる。`kasane/roadmaps/v1-foundation/phases/phase-7-3-user-docs/history.md:131`) は、`skills/` を触る変更の中のワーカーにしか効かず、頼まれたときと、変更の後に知らせるときには効かない。

兄弟ライブラリの docs-refresh の形 (2026-10-14 に確認):

- メインのセッションは、ハッシュと対応表の機械的な確かめだけを行い、概念の文書の本文を読まない
- Skill の書き直しは、器 ksn-scribe のワーカーに、1 つの Skill の英語版と日本語版をまとめて任せる。最大 3 並列
- ワーカーへの指示のひな形を 2 枚 (Skill 用・README 用) 持つ
- ksn-scribe を起動できない環境では止まり、メインが代わりに書かない
- 実体は `.agents/skills/docs-refresh/` で、`.claude/skills/docs-refresh` はそこへのリンク。AGENTS.md に「`skills/` の追従は docs-refresh 経由でのみ行う」の 1 行がある
- 同じ置き方で、リリースの Skill (`release`) も持つ

2026-10-14 時点の道具の出力: `skills-refresh.py status` は、変わった源泉なし・公開の宣言の増減なし (記録の commit は `bc3c832`)。`check-api-coverage.py` は漏れ 0 件。追従を通しで行ったことはまだ無い。

## 検討した選択肢 (却下案と理由を含む)

追従の手順の置き場:

| 案 | 評価 |
|---|---|
| A: 今のまま (handbook のガイドと `scripts/`) | 却下。上の穴が残る |
| B: AGENTS.md に、ガイドを指す 1 行を足す | 却下。AGENTS.md はどちらの CLI もセッションの始めに読むので、手順にはたどり着ける。しかしワーカーの呼び分けは持てない。議論側は最初これを推したが、モデルの使い分けの軸を見落としていた |
| C: 専用の Skill を作る (採用) | 名前で呼べ、ワーカーの呼び分けを持てる。ADR-0017 の却下理由は小さくできる。置き場が増えることは、実体 1 つとリンクの置き方で抑える。Skill の中のスクリプトがテストの外になることは、スクリプトを `scripts/` に置いたまま Skill から呼ぶ形で避ける |

ADR-0017 の改め方:

| 案 | 評価 |
|---|---|
| amends (手順の置き場の部分だけを置き換え、残りを生かす) | 却下。議論側はこちらを推したが、オーナーが全体の置き換えを選んだ |
| supersede (全体を置き換えて作り直す) (採用) | オーナーの判断 |

進め方:

| 案 | 評価 |
|---|---|
| A: 単独の変更 (採用) | すぐ着手できる。phase-7-3 は完了済みで、これはその成果物の作り直しにあたる。先に Skill ができていれば、phase-7-4 のリリースの手順は、その Skill を呼ぶだけで済む |
| B: phase-7-4 に合流 | 論点 2 (気づき) をリリースの手順と一緒に決められる。しかしリリースの手順の議論が終わるまで着手できず、議論中の agenda がさらに膨らむ |
| C: ロードマップに新しいフェーズを足す | フェーズを足す改訂の手間が増える。着手できるのは改訂の後 |

handbook の追従のガイド (`kasane/handbook/cross/user-skill-refresh.md`) の扱い:

| 案 | 評価 |
|---|---|
| A: 役目で分けて両方残す (採用) | Skill は入口と指揮 (メインが何をし、どこでどのワーカーに任せ、どこで止まってオーナーに見せるか)、ガイドは手順の中身 (道具の出力の読み方・終了コード・直し方・確かめ方の基準) を持つ。Skill の本文は呼ぶたびにメインに読み込まれるので、薄いほどメインの文脈を守れる (兄弟ライブラリの SKILL.md は 476 行・約 50KB)。handbook に残せば、棚卸し (ksn-drift) と構造の lint の対象のまま。ほかの handbook の 3 枚 (verification-ci・consumer-build-check・user-docs-writing) からのリンクも生きる |
| B: 手順を Skill に移し、ガイドは消す | 直す場所が 1 か所で、兄弟ライブラリと同じ。しかし呼ぶたびに手順の全部をメインが読み、Skill は棚卸しと構造の lint の外になる。3 枚のリンクも直す |

Skill の書き直しを任せる器:

| 案 | 評価 |
|---|---|
| A: すべて ksn-scribe (採用) | 源泉の差分・コード・書き方の決まりから内容が決まるので、軽作業の器の境目に当たる。考える必要がある部分 (新しい公開 API の置き場所・載せない名前) は、ガイドがもともとオーナーに諮る流れにしており、ksn-scribe は決められない箇所を埋めずに報告するので、メインに戻る。器の定義を変えたときに、書き直しの全部が安くなる。兄弟ライブラリと同じ。文面の質が下がりうる分は、オーナーの承認と、配った先を再現した確認で拾う |
| B: すべて ksn-implementer | 文面の質は一番安心だが、器の定義を変えても安くならない |
| C: 種類で分ける (既存のページへの差分の反映は ksn-scribe、新しい内容の置き場所を決める作業は ksn-implementer) | 新しい内容の質は安心。しかし Skill の中の分かれ道が作業の種類ごとに増える |

追従が要る状態になったことに気づく仕組み:

| 案 | 評価 |
|---|---|
| A: リリースの直前に確かめる (採用) | 利用者の手に渡るのはリリースした Skill なので、困るのはリリースのとき。兄弟ライブラリも、リリースの手順の 1 段目で Skill の追従が要るかを確かめている (`kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/artifacts/kssettingsview-release-research-2026-10-14.md` の 3 節)。変わった分をまとめて追従する決まりとも合う |
| B: A に加えて、蒸留のたびに知らせる (AGENTS.md に「公開 API・利用者に見える挙動を変えた変更を蒸留したら、変わった源泉を出して報告に書く」の 1 行を足す) | 早く気づけるが、蒸留のたびに報告が 1 つ増え、AGENTS.md に決まりが 1 つ増える。兄弟ライブラリには無い |
| C: 仕組みを作らない | 古い Skill のままのリリースを、頼み忘れ次第で防げない |

## 決定事項

- 追従は、プロジェクト内の専用の Skill から始める。Skill は、メインのセッションの進め方と、実作業を任せるワーカーの呼び分け (どの作業をどのモデルで行うか) を持つ (cross/ADR-0020)
- ADR-0017 から、次の 3 つを引き継ぐ: 頼んだときだけ追従する・前回追従した commit からの差分で見る・差分を出す部分と検査する部分は `scripts/` に置く
- cross/ADR-0017 は、amends ではなく supersede で置き換える。ADR-0017 の status を superseded にするのは、cross/ADR-0020 を accepted にする蒸留のとき
- Skill の書き直しは、すべて器 ksn-scribe のワーカーに任せる。ksn-scribe が決められない箇所 (新しい内容の置き場所・載せない名前の候補など) は報告で戻り、メインがオーナーに諮る
- 追従が要る状態になったことには、リリースの直前に気づく形にする。この変更では、Skill に「追従が要るかを確かめるだけ」の使い方 (変わった源泉を出して報告し、Skill は直さない) を持たせる。それをリリースの手順から呼ぶかは、phase-7-4 で決める
- 進め方: ロードマップのフェーズにはせず、単独の変更 `user-skill-refresh-skill` として進める
- phase-7-4 の agenda の「リリースの手順の中で、Skill の追従を確かめるかどうか」の行に、この変更を指す 1 行を足す (この変更が「確かめるだけ」の使い方を用意し、リリースの手順から呼ぶかを phase-7-4 で決める)。探索では agenda を書かないので、phase-7-4 を ksn-agenda で議論するときに足す
- 蒸留時に反映: kasane/decisions/cross/0017-user-skill-refresh-on-request-by-commit-diff.md — status を superseded にする (cross/ADR-0020 の昇格と同じ作業)
- 蒸留時に反映: kasane/decisions/cross/index.md — 0017 の行の status を superseded にし、置き換え先の 0020 を書く
- handbook の追従のガイドは残し、Skill と役目で分ける。Skill は入口と指揮 (メインの進め方・ワーカーへの任せ方・オーナーに見せる時点)、ガイドは手順の中身 (道具の出力の読み方・終了コード・直し方・確かめ方の基準) を持つ
- 蒸留時に反映: kasane/handbook/cross/user-skill-refresh.md — Skill との役目の分け方に合わせて改める (追従は Skill から始めること、「作業者」「指揮側」の書き方を Skill の進め方に合わせること、冒頭と「関連」の cross/ADR-0017 を cross/ADR-0020 にすること)。Skill が指す節の名前と食い違わないよう、実装の中で草稿を作る
- 蒸留時に反映: kasane/handbook/cross/verification-ci.md — 「関連」の cross/ADR-0017 を cross/ADR-0020 に
- 蒸留時に反映: kasane/decisions/cross/0018-install-examples-without-concrete-version.md — footer の「関連」に cross/ADR-0020 を足す (本文の cross/ADR-0017 は accepted の本文なので変えない)
- 実装の作業: `scripts/docs/skills-refresh.py` の冒頭の cross/ADR-0017 を cross/ADR-0020 に

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

- 作成済み: cross/ADR-0020 (proposed。supersedes: 0017) — 利用者向け Skill の追従は、オーナーが頼んだときに、専用の Skill が前回追従した commit からの源泉の差分をもとに行う

## 未決の論点

- 論点 1 (呼び口): 専用の Skill で解決した (cross/ADR-0020)
- 論点 2 (気づき): リリースの直前に確かめる形にした (決定事項)。リリースの手順から呼ぶかは phase-7-4 に残る
- 論点 3 (ガイドの扱い): 役目で分けて両方残す (決定事項)
- 論点 4 (書き直しを任せる器): すべて ksn-scribe にした (決定事項)
  - ワーカーのモデルは器の定義が決め、呼ぶ側の Skill は器を選ぶだけである (`~/.claude/skills/ksn-core/references/worker-dispatch.md`)
  - 2026-10-14 時点の器の定義 (`~/.claude/agents/`) では、ksn-scribe と ksn-implementer はどちらも claude-opus-5-5・effort medium で、モデルの差は無い。器の定義を変えれば、Skill を変えずに安くできる
- 論点 5 (進め方): 単独の変更にした (決定事項)
- 提案で詰めるもの: Skill の名前と置き場 (実体とリンク)、ワーカーへの指示のひな形、ワーカーを起動できない環境での動き、AGENTS.md に Skill を指す 1 行を足すか、配った先を再現した確認 (読ませる・使わせる) を任せるワーカーの器

## UI 素材 (ui/references/ の一覧と注釈)

なし

## 変更級の推奨: S / M / L (理由)

M (オーナーが確定)。利用者向け Skill の追従 (変更 `user-docs` のデルタスペックの user-docs-refresh) という 1 つの能力の中の作り直しで、公開 API と利用者向けの Skill の中身には触れない。方向の決定は cross/ADR-0020 で起票済みで、残りは Skill の形 (名前・置き場・進め方・ワーカーへの指示のひな形) の設計である。Skill は消せば元に戻せ、道具のスクリプトは今のものを使う。

L に上げる理由になりうるのは、このリポジトリで初めてのプロジェクト内の Skill になり、その置き場の決め方が後の Skill (リリースの手順など) の先例になること。
