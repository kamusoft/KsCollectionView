---
id: 0023
title: リリースノートは、前回の Release からの main 宛ての Pull Request の本文にある変更の節から組み立てる
status: proposed
date: 2026-10-14
---

## Context

日々の変更は `develop` へ直接 push し、`main` へは `develop` からの Pull Request だけが入る (cross/ADR-0010)。1 本の Pull Request に、多くの変更がまとめて入る。マージは merge commit だけで、`develop` の commit がそのまま `main` に入る。

兄弟ライブラリ KsSettingsView は、同じブランチの運用で、ラベルによるノートの自動の分類が働かなかった (全件が「その他」に落ちた)。そこで、Pull Request の本文の変更の節から組み立てる形に変えて運用している。

前提: `main` へは、`develop` からの集約の Pull Request だけが入る運用が続くこと。

## Decision

リリースノートは、`main` 宛ての Pull Request の本文にある変更の節から組み立てる。節の各行には、変更の種類 (破壊的な変更・機能・修正・文書) と説明を書く。利用者向けの変更が無いときは、無いと書く。節は必須で、欠けていたり、読めない行があれば、リリースを止める。

範囲は、前回公開した Release の tag から、起動した commit までに `main` に入った Pull Request のすべてとする。ノートはリリースの工程の最初に 1 回だけ組み立て、公開の段はそれを使う。

理由: 集約の Pull Request の本文なら、利用者向けの変更の単位で書ける。節を必須にすれば、書き忘れと「変更が無い」を区別できる。

## Alternatives Considered

- **Pull Request にラベルを付けて自動で分類する**: 却下。分類できる粒度が、集約の Pull Request の単位でしかない。
- **変更ごとに `main` 宛ての Pull Request を出す運用に改める**: 却下。cross/ADR-0010 を改めることになり、代償が大きい。
- **commit から組み立てる**: 却下。粒度が、利用者向けの変更の単位と合わない。
- **直近の Pull Request 1 本だけを見る**: 却下。前回のリリースからの複数の Pull Request を取りこぼす。
- **`main` 宛ての Pull Request をリリースごとに 1 本に限る**: 却下。リリース以外で `main` を触れなくなる。
- **変更の節を任意にする**: 却下。書き忘れと、変更が本当に無いことを区別できない。

## Consequences

- 正: ノートを、利用者向けの変更の単位で書ける。
- 正: 書き忘れが、公開の前に止まる形で見つかる。
- 負: `main` 宛ての Pull Request のたびに、変更の節を書く手間が増える。
- 負: 書き忘れると、リリースが止まる。
- 負: リリースの workflow が、Pull Request の本文を集めて検査する責務を持つ。

## Revisit When

- 前提 (Context) が崩れたとき
- 変更の節の書き漏れで、リリースが止まることが繰り返されたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/history.md (2026-10-14: 版の付け方と、兄弟ライブラリの踏襲による決定) / kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/artifacts/kssettingsview-release-research-2026-10-14.md (1. ADR 3 枚 の 0030) / ../KsSettingsView/kasane/decisions/cross/0030-release-notes-from-pr-body-and-handbook-as-procedure-source.md (Decision・却下した案・帰結・Revisit When)
関連: cross/ADR-0010 (ブランチの役割と、main 宛ての Pull Request) / cross/ADR-0022 (リリースの工程の順序)
