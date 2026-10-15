---
id: 0019
title: Skill の外への参照は、知識を委ねるものを持たず、操作の対象になる URL は持ってよいとする
status: accepted
date: 2026-10-10
amends: 0005
---

## Context

cross/ADR-0005 は、利用者向け Skill の閉世界性を次のように決めている。Skill は 1 ディレクトリを単体でコピーして使われるため、`SKILL.md` と `references/` は Skill の外のファイル・URL への参照を持たない。

この文面のままでは、書けないものが 2 つある。

- SwiftPM のインストール例。依存に書く値そのものが、配信用リポジトリの Package URL である (cross/ADR-0015)
- 最新の版の確かめ先。インストール例には版を書かないので (cross/ADR-0018)、Skill が確かめ先を案内する必要がある

この条項は、兄弟ライブラリ KsSettingsView の決定から引き継いだ。兄弟ライブラリは、引き継ぎの後にこの条項を改めている。文面が実態と合っていない (Skill に配布リポジトリの URL が既にある) ことを理由に、境界を「URL があるかどうか」から「何のための参照か」へ置き換えた。

兄弟ライブラリの最初の Skill の制作では、Skill の外への参照がレビューを通り、オーナーの検収で落ちた経緯がある。

本リポジトリには、この決定の時点で利用者向け Skill がまだ 1 枚も無い。

前提: Skill が 1 ディレクトリの単体のコピーで使われること。SwiftPM の依存の宣言に Package URL が要ること。インストール例に版を書かない決定 (cross/ADR-0018) が続くこと。

## Decision

cross/ADR-0005 の決定のうち、「`SKILL.md` と `references/` は Skill の外のファイル・URL への参照を持たない」を本決定で置き換える。他の決定は維持する。

Skill の外への参照は、URL があるかどうかではなく、何のための参照かで分ける。

- 知識を Skill の外に委ねる参照は持たない。README・Skill の索引・相手のプラットフォームの Skill・リポジトリの中の文書へ、続きをそちらで読ませる形の参照が当たる。Skill の外のファイルへの参照は、すべてこれに当たる
- 操作の対象になる URL は書いてよい。依存に書く Package URL・最新の版の確かめ先・不具合の報告先・配布元を示す項目が当たる

理由は 3 つある。文面どおりに従うとインストール例が書けず、「依存に書く値は参照に数えない」という、決定に書かれていない読み替えで運用することになる。知識が Skill の中で閉じることは、知識を委ねる参照を禁じたままにすれば守られる。Skill がまだ無い今なら、直す実物が無い。

## Alternatives Considered

- **文面のまま従い、案内の URL を書かない**: 却下。URL が無いことは機械で確かめやすく、決定を改めずに済む。しかし Package URL を書いた時点で文面と食い違い、決定に書かれていない読み替えが要る。最新の版は言葉で案内することになり、利用者のエージェントが場所を推測する。

## Consequences

- 正: SwiftPM のインストール例と、最新の版の確かめ先を、決定と食い違わずに書ける。
- 正: 知識を委ねる参照は禁じたままなので、Skill だけで知識が閉じることは変わらない。
- 正: 兄弟ライブラリと同じ線引きになる。
- 負: 操作の対象かどうかは機械で判定できず、人が見て確かめる必要がある。
- 負: 「操作の対象」を広く読むと、知識を委ねる参照が入り込む余地が残る。
- 負: Skill が持つ URL の行き先が変わると、Skill を直す必要がある。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/archive/2026-10-15-v1-foundation/phases/phase-7-3-user-docs/history.md (2026-10-10: cross/ADR-0005 の閉世界性の条項) / ../KsSettingsView/kasane/decisions/cross/0029-install-examples-without-pinned-version.md (Decision: Skill の外部参照の境界) / ../KsSettingsView/kasane/changes/archive/2026-08-28-rollout-user-skills/deviation.md (Skill の外への参照が検収で落ちた経緯) / kasane/changes/archive/2026-10-10-user-docs/design.md (Decision 2: 相手のプラットフォームとの差の書き方 / Decision 5: Skill 自身の整合の検査)
現行照合: 2026-10-10 確認。Skill の 24 枚が持つ URL は、`scripts/ci/user-docs-rules.json` の 4 つ (Package URL・配布元・最新の版の確かめ先・不具合の報告先) と、コード例の見本の前置きだけである。`scripts/ci/check-skills.py` が、Skill の外のファイルへのリンクと、一覧に無い URL を違反にする。相手のプラットフォームの Skill には、名前だけで触れている。判定: 維持
関連: cross/ADR-0015 (SwiftPM の Package URL) / cross/ADR-0018 (インストール例に版を書かない決定)
