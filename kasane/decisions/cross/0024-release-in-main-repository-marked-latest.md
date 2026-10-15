---
id: 0024
title: Release は本リポジトリにだけ作り、プレリリースの印を付けずに、最新の Release として示す
status: accepted
date: 2026-10-14
---

## Context

README と利用者向け Skill は、最新の版の確かめ先として、本リポジトリの Release の一覧を案内している (cross/ADR-0018)。案内が効くには、Release が利用者に見える形で保たれている必要がある。Skill が持ってよい URL は許可した一覧に限っていて、この URL が入っている (cross/ADR-0019)。

配布物は、本リポジトリと配信用リポジトリ `KsCollectionView-SPM` に分かれ、tag は両方に同じ文字列で付く (cross/ADR-0021)。

GitHub は、プレリリースの印を付けた Release を、最新の Release に選ばない。兄弟ライブラリ KsSettingsView は、プレリリースの版だけを出していた間に、最新の Release を指す URL (`/releases/latest`) が見つからない状態になった。そこで、印を付けずに最新として指定する形に変えた。本ライブラリも、初回の版はプレリリースの版である。

前提: README と Skill が、本リポジトリの Release の一覧を、最新の版の確かめ先として案内すること。GitHub が、プレリリースの印を付けた Release を最新に選ばないこと。

## Decision

Release は本リポジトリにだけ作る。配信用リポジトリには作らない。

プレリリースの版でも、Release にプレリリースの印を付けず、作るたびに最新の Release として指定する。版がプレリリースかどうかは、版の文字列で示す。Release の本文は、リリースノートとする。

理由: 最新の版の確かめ先を 1 か所に保ち、README と Skill の案内をそのまま使える。印を付けなければ、一覧の中で最新の版に最新の表示が付き、最新の Release を指す URL も働く。

## Alternatives Considered

- **本リポジトリの外に Release を作る**: 却下。README と Skill の 6 つのファイルと、Skill が持ってよい URL の一覧を直すことになる。
- **プレリリースの版の Release に、プレリリースの印を付ける**: 却下。版の性格が一覧の印でも分かる。しかしプレリリースの版しか無い間は、どの Release も最新にならず、最新の Release を指す URL が見つからない (兄弟ライブラリで起きた)。

## Consequences

- 正: 最新の版の確かめ先が 1 か所で、README と Skill の案内を書き換えずに済む。
- 正: 一覧の中で最新の版が分かり、最新の Release を指す URL も働く。
- 負: プレリリースの版も最新として示される。正式版かどうかは、利用者に版の文字列を読んで見分けてもらうことになる。
- 負: 配信用リポジトリを直接見た利用者には、Release が見えない。本リポジトリへの案内が要る。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/history.md (2026-10-14: 版の付け方と、兄弟ライブラリの踏襲による決定) / kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/agenda.md (申し送りの phase-7-3 から: Release の置き場所・利用者に見える形で保つ決まり) / kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/artifacts/kssettingsview-release-research-2026-10-14.md (2. リリースの workflow の GitHub の Release / 5. 運用で起きた問題) / ../KsSettingsView/kasane/decisions/cross/0029-install-examples-without-pinned-version.md (プレリリースの印を付けずに最新として指定する決まり) / kasane/changes/archive/2026-10-15-release-pipeline/design.md (Decision 7)
関連: cross/ADR-0018 (最新の版の確かめ先を Release の一覧にした決定) / cross/ADR-0019 (Skill が持ってよい URL) / cross/ADR-0021 (版と tag の形) / cross/ADR-0023 (リリースノートの材料)
