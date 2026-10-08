---
id: 0011
title: 貢献は Issue で受け、外部からの Pull Request は受け付けない
status: proposed
date: 2026-10-08
---

## Context

リポジトリを公開するにあたり、外部からの貢献をどう受けるかを決める必要がある。

開発は Kasane の変更フロー (探索 → 提案 → 実装 → レビュー → 蒸留) で回っている。外部からの Pull Request は、このフローの外から、探索や提案の文脈を持たない実装だけが入ってくる形になる。AI が生成した粗い提案が流れ込むと、レビューの負荷が上がる。

ブランチは `develop` と `main` の 2 本で、`develop` へは直接 push し、Pull Request は `main` 宛てだけに使う (cross/ADR-0010)。外部からの Pull Request を受けるなら、`develop` 宛ての Pull Request とその検証が要る。一方、オーナー自身は `main` 宛ての Pull Request を作れなければならない。

兄弟ライブラリ KsSettingsView は、外部からの Pull Request を受け付けず、貢献を Issue で受けている。

前提: 開発者が 1 人で、変更フローで開発していること。GitHub に、Pull Request を作れる人を共同作業者に限る設定があること。

## Decision

外部からの Pull Request は受け付けない。GitHub の設定で、Pull Request を作れる人を共同作業者に限る。

貢献は Issue で受ける。オーナーが Issue を見て、変更フローの変更に起こして対応する。Issue には、実際に動かした証拠 (バージョンや再現手順) を必須で求める。

理由は 3 つある。変更フローの文脈を持たない実装が入らず、レビューの負荷と品質を制御できる。粗い提案は、書式ではなく動かした証拠を求めることで入口で減らせる。`develop` へ直接 push する構え (cross/ADR-0010) がそのまま成り立つ。

## Alternatives Considered

- **外部からの Pull Request を受ける**: 却下。コードで貢献したい人の道ができる。しかし文脈を持たない実装をレビューすることになる。`develop` 宛ての Pull Request と検証が要り、ランナーの消費が増える。
- **GitHub の設定は変えず、README で断るだけにする**: 却下。来た Pull Request をその都度閉じる手間が残り、投稿者は書き上げてから断られる。
- **Pull Request を完全に無効にする**: 却下。オーナー自身も `main` 宛ての Pull Request を作れなくなる。

## Consequences

- 正: 変更フローの外から実装が入らず、レビューの負荷と品質を制御できる。
- 正: `develop` へ直接 push し、Pull Request は `main` 宛てだけ、という構えがそのまま成り立つ。
- 正: 兄弟ライブラリと貢献の受け方が揃う。
- 負: コードで直接貢献したい人の道が無い。
- 負: Issue を見てオーナーが変更に起こす運用が前提になり、滞ると貢献が放置される。
- 負: Pull Request の画面は見えるのに作れない状態になるので、README と貢献の案内での表明が要る。
- 負: Issue のフォーム・貢献の案内・GitHub の設定という、コード以外の作業が公開の準備に加わる。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-1-public-repo-verify-ci/history.md (2026-10-08: 外部からの PR の扱い) / ../KsSettingsView/kasane/decisions/cross/0024-contributions-via-issues-no-external-pull-requests.md (兄弟ライブラリの決定とその理由)
関連: cross/ADR-0010 (ブランチの役割。Pull Request を `main` 宛てだけに使う構え)
