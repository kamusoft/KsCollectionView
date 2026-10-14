# AGENTS.md

## 全体ルール

- 使用言語は日本語とする。（ソースのコメントも日本語とする）
- 削除コマンドは `rm` ではなく `trash` を使用すること。

## 開発ハーネス

このプロジェクトは Kasane (ksn-*) で運用する。
- 探索: ksn-explore / 提案: ksn-propose / 実装: ksn-orchestrator / 蒸留: ksn-distill / 棚卸し: ksn-drift
- 規約: ~/.claude/skills/ksn-core/SKILL.md、プロジェクト設定: kasane/config.yaml
- 他の SDD 系スキル (openspec-* 等) はこのプロジェクトでは使用しない

## 利用者向け Skill の追従

- 利用者向け Skill (`skills/`) の追従は、オーナーが頼んだときにだけ、プロジェクト内の Skill `docs-refresh` で行う (実体は `.agents/skills/docs-refresh/`)。追従が要るかを確かめるだけのときも、同じ Skill を使う
- 利用者向け Skill の構成の見直し (1 枚の追加・名前の変更・分け方の変更) は、追従では行わず、変更の実装で行う
