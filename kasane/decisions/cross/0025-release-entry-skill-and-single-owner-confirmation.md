---
id: 0025
title: リリースは専用の Skill から始め、手順の正は handbook に置き、オーナーの確認は版と変更の節の文面の 1 回にまとめる
status: accepted
date: 2026-10-14
---

## Context

リリースの工程は、版を入力して `main` から手動で起動する workflow で、取り消せる操作から公開し、tag と Release を最後に作る (cross/ADR-0022)。リリースノートは、`main` 宛ての Pull Request の本文の変更の節から組み立てる (cross/ADR-0023)。リリースの前には、変更の節を書いたリリースの Pull Request を `develop` から `main` へ出してマージし、その後に本番を起動する。マージ・起動・tag の作成は、どれも外向きの操作で、Maven Central への公開は取り消せない。

リリースの手順を handbook のガイドに置くだけでは、オーナーの依頼を受けるメインのセッションが手順にたどり着く保証が無い。利用者向け Skill の追従でも同じ理由で、専用の Skill から始める形に改めた (cross/ADR-0020)。

兄弟ライブラリ KsSettingsView は、手順の正を handbook に置き、入口に専用の `release` の Skill を置いて、Skill は起動のたびに handbook を読むだけにしている。Skill が自分で持つのは、変更の節の下書きの作り方・オーナーへの確認を 1 回にまとめる境界・止まる条件である。

前提: リリースを頼むのは開発者 1 人 (オーナー) で、リリースを進めるのはオーナーの依頼を受けたエージェントであること。エージェントの CLI が、プロジェクト内の Skill を名前で呼べること。

## Decision

リリースは、プロジェクト内の専用の Skill `release` から始める。手順の正は handbook に置き、Skill は起動のたびに handbook を先頭から読み、段の順序もコマンドも持たない。Skill はオーナーの明示の依頼からだけ動き、自分からは起動しない。

Skill が自分で持つのは 3 つだけにする。変更の節の下書きの作り方、オーナーへの確認の境界、止まる条件である。

オーナーへの確認は 1 回にまとめる。版と変更の節の文面を、事前の確認の結果と並べて 1 回で確かめる。オーナーが確定したら、それを対象の commit についての以降の承認として扱い、リリースの Pull Request の作成とマージ・本番の起動・tag と Release の作成まで、段ごとに聞かずに進める。確定の前には、公開を伴う操作をしない。止まるのは、検証や実行が失敗したとき・手順に無い状況に当たったとき・確定した版や文面のままでは進めないときで、再実行するか中止するかはオーナーが決める。

理由: 名前で呼べる Skill から始めれば、どのセッションでも手順にたどり着ける。手順の正を handbook の 1 か所に置けば、手順を変えても Skill を直さずに済む。確認を版と文面の 1 回にまとめれば、オーナーが決めるべきこと (何を、どの版で出すか) だけを聞き、決めた後の機械的な段で何度も止めずに済む。

## Alternatives Considered

- **handbook のガイドだけにし、Skill を置かない**: 却下。名前で呼べず、オーナーの依頼を受けたセッションが手順にたどり着く保証が無い。
- **Skill の中に手順を持たせ、handbook に置かない**: 却下。兄弟ライブラリがオーナーの判断で却下した形で、手順の置き場が 2 つになる余地が残る。

## Consequences

- 正: オーナーの依頼から、どのセッションでも同じ手順でリリースを進められる。
- 正: 手順を変えるときは handbook だけを直せばよく、Skill を直さずに済む。
- 正: オーナーの確認は 1 回で済み、取り消せない公開を含む後続の段で毎回止まらない。
- 負: 確定した後は、取り消せない公開までオーナーの確認無しに進む。確定の時点の版・文面・事前の確認の結果が正しいことに頼る。
- 負: Skill が指す handbook の節の名前を変えるときは、Skill の本文も同じ回に直す必要がある。
- 負: handbook の手順の文書が無いと、Skill は何もできない。

## Revisit When

- 前提 (Context) が崩れたとき
- 確定した後の段で、オーナーの確認があれば防げた誤った公開が起きたとき

出典: kasane/roadmaps/archive/2026-10-15-v1-foundation/phases/phase-7-4-release-pipeline/agenda.md (決定事項: リリースの Skill (A3 の補い)) / kasane/roadmaps/archive/2026-10-15-v1-foundation/phases/phase-7-4-release-pipeline/history.md (2026-10-14: リリースの Skill の中身 / リリースの手順の置き場) / kasane/changes/archive/2026-10-15-release-pipeline/design.md (Decision 11) / ../KsSettingsView/kasane/decisions/cross/0030-release-notes-from-pr-body-and-handbook-as-procedure-source.md (手順の正を handbook に置く決まり)
関連: cross/ADR-0020 (利用者向け Skill の追従を専用の Skill から始める) / cross/ADR-0022 (リリースの起動と公開の順序) / cross/ADR-0023 (リリースノートの材料)
