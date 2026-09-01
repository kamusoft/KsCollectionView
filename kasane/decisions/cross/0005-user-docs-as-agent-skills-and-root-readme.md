---
id: 0005
title: 利用者向けドキュメントは Agent Skills (skills/、en/ja 2 版) で提供し、README はルート 2 枚に集約する
status: accepted
date: 2026-09-01
---

## Context

KsCollectionView の公開後の主要読者は、AI エージェントを併用してネイティブ UI を書く開発者である。章立て型の読み物ドキュメントは、必要箇所だけを読ませる用途に合わない。翻案元プロジェクトは章立ての `docs/` を先に整備した後で Agent Skills 形式へ作り直す是正コストを払っており、本プロジェクトはまだ利用者向けドキュメントを 1 枚も書いていない位置にいる。

翻案元は同時に、開発者向けの README がプラットフォームごとに増殖し、知識の正がドキュメントに滞留する逆転 (概念ドキュメントが README を正として指す) を抱えた末に README をルート 2 枚へ集約している。本プロジェクトは README も未整備であり、同じ形を最初から取れる。

なお、翻案元でこれらを定めた時点の知識層は概念ドキュメント 1 層だった。現行の Kasane は契約 (concepts) と規範・手順 (handbook) を分けるため、「開発者向け知識の正を 1 箇所に置く」という原則はそのままでは写せない。

## Decision

- 利用者向けドキュメントは `skills/` 配下の Agent Skills (`SKILL.md` + `references/`) として提供し、章立て型の `docs/` は作らない。利用者は自分のプロジェクトへディレクトリをコピーして使う。
- 分割軸は利用者のプラットフォームとし、**iOS / Android の 2 Skill** とする。name は配布識別子に揃えた `kscollectionview-ios` / `kscollectionview-android`。
- 2 言語は `skills/{en,ja}/<name>/` で言語をトップに分離し、各言語配下に自己完結した Skill ディレクトリを置く。name は en/ja 同名とし、言語はパスと frontmatter の metadata で表す。**en/ja は常に同一構成・同時更新の翻訳ロックステップ**とする (片方だけを更新して commit しない)。
- **配布単体利用の閉世界性**: Skill は 1 ディレクトリを単体コピーして使われるため、`SKILL.md` と `references/` は Skill 外のファイル・URL への参照を持たない。兄弟 Skill への言及はスキル名のみ (リンクなし) とし、リポジトリ内部の用語を漏出させない。
- 知識の正は `kasane/` とコード・テストであり、`skills/` はそこから利用者向けに翻訳した派生物とする。派生物を手で直接育てず、源泉の変更に追従させる。追従を担う仕組み (manifest・追従ツール) の具体は配布・ドキュメントのフェーズで決める。
- README は**ルートの 2 枚のみ**とする: 英語 `README.md` + 日本語 `README_ja.md`。プラットフォーム別・Sample 別の README は新設しない。ルート README は利用者の入口に純化し (概要・特徴・対応プラットフォーム・インストール・最小コード例・`skills/` への導線・リポジトリ構成・貢献・ライセンス)、開発者向けの手順は載せない。ルート 2 枚も翻訳ロックステップで扱う。
- `skills/` の索引 (`skills/README.md` + `skills/README_ja.md`) はこの集約の対象外として存置する。
- **開発者向け知識の配置**: 翻案元の「開発者向け知識は概念ドキュメントに一本化する」を、現行 Kasane の層分離に読み替える — **契約・仕様は `kasane/concepts/`、規範・手順は `kasane/handbook/`** に置く。README・Skill を知識の正として指す参照を作らない。
- 上記のうち Skill 構成の見直し (Skill の増減・`references/` の再編) は変更フローの承認を通す。

## 持ち込まない条件

- MAUI 向けの Skill・記述は作らない (cross/ADR-0001 で MAUI 非対応)。
- 旧ライブラリからの移行 Skill は作らない。本ライブラリは旧ライブラリのユーザー基盤には届かない新規ブランドの新製品であり (cross/ADR-0001)、移行対象の利用者が存在しない。
- 翻案元固有の docs-refresh 運用 (対象一覧・manifest 形式・起動規約) はそのまま持ち込まない。

## Alternatives Considered

- **章立ての `docs/` を利用者向けドキュメントとして整備する**: 却下。エージェントが必要箇所だけを読めず、想定読者に合わない。翻案元が `docs/` から Agent Skills へ作り直す是正コストを既に払っており、同じ道を通る理由がない。
- **両プラットフォームを 1 つの Skill にまとめる**: 却下。「同じ書き味」が製品価値であるため併記は一見自然だが、利用者は自分のプラットフォームの Skill だけをコピーして使う。1 本にまとめると無関係なプラットフォームのコード例を常に読ませることになり、閉世界性とも噛み合わない。対称性は各 Skill が同一の能力マップを持つことで示す。
- **プラットフォーム別 README を置く**: 却下。2 プラットフォームなら枚数は少ないが、開発者向け知識の正が README に滞留する逆転は同じく起きる。翻訳ロックステップの対象枚数も増える。
- 参考 (翻案元での検討): トピック別 Skill 分割、`SKILL.md` + `SKILL_ja.md` の 1 ディレクトリ 2 言語同居、`skills/<name>/{en,ja}` の言語配置、ja 版 name への接尾辞は、いずれも翻案元で検討・却下されている。本プロジェクトはその結論 (プラットフォーム別分割・言語トップ分離・en/ja 同名) を前提として引き継ぎ、再検討していない。

## Consequences

- 正: エージェントが description で発火 → 能力マップで全景把握 → 必要な `references/` だけを読む段階開示になる。
- 正: 利用者向けドキュメントを最初から Agent Skills 形式で書けるため、章立てドキュメントからの作り直しが発生しない。
- 正: 開発者向け知識の正が `kasane/` に定まり、ドキュメントを正として指す逆参照が生まれない。
- 負: en/ja × 2 Skill = 4 部の生成・維持コストが生じ、共通概念の変更が複数 Skill に波及する。
- 負: 人間が通しで読むブラウズ型ドキュメントは持たず、人間の可読性はルート README と各 `SKILL.md` のリード文・自然言語見出しに依存する。
- 負: 派生物の追従を担う仕組みが未決のため、それが決まるまでは源泉と `skills/` のずれを人手で防ぐ必要がある。
- 負: Agent Skills 標準は多言語の慣行が未標準化であり、標準の進化に応じて 2 言語規約の見直しが必要になり得る。

出典: ../KsSettingsView/kasane/decisions/cross/0022-user-docs-as-agent-skills.md (Decision / Alternatives) / ../KsSettingsView/kasane/decisions/cross/0023-readme-root-only-and-developer-knowledge-in-concepts.md (README 集約・開発者向け知識の配置) / kasane/changes/kasane-initial-assets/exploration.md (ADR 候補 4) / kasane/roadmaps/v1-foundation/roadmap.md (前提 / 制約: skills/ 方式の踏襲)
