# Proposal: user-skill-refresh-skill

## Why

利用者向け Skill (`skills/`) の追従は、手順を handbook のガイド (`kasane/handbook/cross/user-skill-refresh.md`) に、道具を `scripts/docs/` に置き、専用の Skill を作らない形にしていた (cross/ADR-0017)。確かめたところ、オーナーの依頼を受けるメインのセッションには handbook を読む決まりが無く、追従を頼んでも手順にたどり着く保証が無かった。どの作業をどのワーカーに任せるかを決めるのもメインなので、メインに読まれないガイドでは、Skill の書き直しのような実作業を低コストのモデルの器に任せる形を持てない。

追従を、名前で呼べる専用の Skill から始める形に作り直す (cross/ADR-0020 (proposed)。cross/ADR-0017 を置き換える)。頼んだときだけ追従すること・前回追従した commit からの差分で見ること・道具を `scripts/` に置くことは引き継ぐ。議論の経緯は `exploration.md`。

## What Changes

- 追従の Skill `docs-refresh` を作る。実体は `.agents/skills/docs-refresh/` の 1 つで、`.claude/skills/docs-refresh` はそこへのリンクにする (2 つの CLI が名前で拾えることを、提案の段階の試作で確かめた: `evidence/skill-pickup-probe.md`)。名前は兄弟ライブラリの追従の Skill と同じにする
- Skill は 2 つの使い方を持つ
  - 確かめるだけ: 変わった源泉を出して、追従が要るかを報告する。何も書き換えない (リリースの手順から呼ぶかは phase-7-4 で決める)
  - 追従: 変わった源泉をもとに、Skill を直し、検査し、オーナーの承認を得て commit し、記録を更新する
- Skill が持つのは入口と指揮 (メインの進め方・ワーカーへの任せ方・オーナーに見せる時点) で、手順の中身 (道具の出力の読み方・終了コード・直し方・確かめ方の基準) は handbook のガイドを読ませる
- メインは、道具の出力とワーカーの報告だけで進め、概念の文書の本文と差分の本文を読み込まず、Skill の文面を自分で書き直さない。書き直しは、利用者向け Skill 1 つ (1 プラットフォームの英語版と日本語版) ごとに、器 ksn-scribe のワーカーに任せる。ksn-scribe が決められない箇所は報告で戻し、メインがオーナーに諮る。器を起動できない環境では止まる
- ワーカーへの指示のひな形を、Skill の中に持つ (書き直し・読ませる確認・使わせる確認)。器の指定は、Claude Code と codex の両方で成り立つ書き方にする
- 承認の後の commit は、追従で変えたファイルだけにし、メッセージに追従の要約 (扱った源泉・直した 1 枚・直さなかった源泉と理由・検査・確かめ方の判断) を残す。変更の外で頼まれた追従には変更のディレクトリが無いため、これを追従の証跡にする。直す 1 枚が無かったときは、記録の commit だけを作る
- 追従の中で直すのは、利用者向け Skill の既存の 1 枚と、記録の `sources`・`apiExclusions` に限る。README などの範囲の外の直しと、1 枚の追加などの構成の見直しは、追従の中で行わずオーナーに伝え、残っていれば記録の commit の ID を更新しない
- プロジェクト内の Skill の置き場の形 (実体とリンク・名前の一致) を、スクリプトのテストで確かめる
- AGENTS.md に、追従は頼まれたときに `docs-refresh` で行う 1 行を足す
- `scripts/docs/skills-refresh.py` の冒頭の説明が指す ADR を、cross/ADR-0020 にする
- 影響する能力: user-docs-refresh (追従の道具と手順)
- 蒸留時に反映: decisions — cross/ADR-0020 を accepted に上げ、cross/ADR-0017 の status を superseded にする。cross の index の 2 行を合わせる。cross/ADR-0018 の footer の「関連」に cross/ADR-0020 を足す
- 蒸留時に反映: handbook — `cross/user-skill-refresh.md` を、Skill と役目で分けた形に改める (追従は Skill から始める・「作業者」「指揮側」の書き方を Skill の進め方に合わせる・追従の証跡を、変更のディレクトリではなく commit のメッセージの要約に残す・直す 1 枚が無いときの終わり方・追従の範囲 (README などの範囲の外と構成の見直しの扱い) ・ADR の参照を cross/ADR-0020 にする)。草稿は実装の中で `drafts/` に作る。`cross/verification-ci.md` の ADR の参照も cross/ADR-0020 にする

## Non-Goals

- README の追従: 兄弟ライブラリの追従の Skill は README も扱うが、追従の範囲を広げるのは別の設計判断になる。README の最小コード例とインストール例は、今も検証 CI の検査が見ている
- リリースの手順から「確かめるだけ」を呼ぶこと: リリースの手順はユーザー判断待ち (phase-7-4 の agenda の論点)。phase-7-4 の agenda に、この変更を指す 1 行を、phase-7-4 の議論のときに足す
- 器の定義 (ワーカーのモデルと effort) の変更: 器の定義は Kasane のリポジトリの領分で、別のリポジトリ
- 追従の道具 (`skills-refresh.py`・`check-api-coverage.py`) と検査の挙動の変更: 今の道具をそのまま使う。変える理由が実装の中で見つかったら、付随修正の同梱条件で扱う
- 利用者向け Skill の中身の書き直し: 2026-10-14 の時点で変わった源泉は無く、追従することが無い

## Impact

- 破壊的変更なし。公開 API・利用者向け Skill の中身・検証 CI の検査の数に触れない
- 新しい置き場 `.agents/` と `.claude/skills/` が増える (`.gitignore` に当たらない)。リンクは、シンボリックリンクを扱えない環境の clone では切れる。開発の環境は macOS に限っている
- 追従の試運転を、使い捨ての写しで行う。本リポジトリの作業ツリーと記録は変えない
- リスク: Skill の書き直しを任せる器を低コストのモデルにすると、文面の質が下がりうる。オーナーの承認と、配った先を再現した確認で拾う

## 級: M

利用者向け Skill の追従という 1 つの能力の中の作り直しで、公開 API に触れない (オーナー確定)。

domain: cross
