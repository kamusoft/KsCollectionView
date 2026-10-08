---
id: 0012
title: ライセンスは MIT License とする
status: proposed
date: 2026-10-08
---

## Context

リポジトリを公開して配布するにあたり、ライセンスを決める必要がある。公開前のリポジトリには `LICENSE` が無い。

兄弟ライブラリ KsSettingsView は MIT License で、著作権の名義は `kamusoft` である。

本ライブラリが依存するのは、iOS の Nuke (MIT License) と、Android の Coil・Compose (どちらも Apache License 2.0) である。いずれも依存として参照するだけで、配布物に同梱しない。

前提: 依存するライブラリを配布物に同梱しないこと。

## Decision

本ライブラリを MIT License で提供する。著作権の名義は `kamusoft` とする。

理由は 2 つある。兄弟ライブラリと条件が揃う。利用者に求める条件が、著作権表示とライセンス文を残すことだけで済む。

## Alternatives Considered

- **Apache License 2.0**: 却下。特許の利用の許諾と、訴えた場合の失効が明記される。しかし兄弟ライブラリと条件が揃わず、利用者に、変更した旨の明示と NOTICE の引き継ぎを求めることになる。

## Consequences

- 正: 兄弟ライブラリと同じ条件で使える。
- 正: 利用者に求める条件が少ない。
- 負: 特許の扱いについて、明示の定めを持たない。
- 負: 公開した版のライセンスは、後から取り消せない。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-1-public-repo-verify-ci/history.md (2026-10-08: ライセンスの種類)
