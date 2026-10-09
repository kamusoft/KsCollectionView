---
id: 0010
title: 開発は develop、リリース候補は main の 2 本のブランチに分ける
status: accepted
date: 2026-10-08
---

## Context

リポジトリの公開にあたり、検証 CI がいつ走るか、リリースをどこから起動するか、リリースノートの材料をどこから取るかを決める必要がある。この 3 つはどれも、ブランチがどういう役割を持つかに依存する。

公開前のブランチは `main` の 1 本だけで、開発者は 1 人である。作業用のブランチを手元で `main` にマージしており、Pull Request は使っていない。

兄弟ライブラリ KsSettingsView は `develop` と `main` の 2 本で運用し、この形で 10 回のリリースを回している。当初はどちらのブランチにも Pull Request と検証を掛けており、1 回のマージで macOS ランナーを約 54 分使っていたため、今の形に整理した経緯がある。

前提: 開発者が 1 人で、日々の変更を Pull Request を介さずに直接 push する運用であること。

## Decision

ブランチを `develop` と `main` の 2 本に分ける。

`develop` は日々の開発の場所とする。直接 push し、検証は push の後に走る。`main` はリリース候補だけが入る場所とする。`develop` からの Pull Request でしか入れず、リリースは `main` から起動する。

`main` 宛ての Pull Request をリリースの節目とする。その節目で何を確かめ、何をリリースノートの材料にするかは、検証 CI・配布・リリースのそれぞれの決定が定める。

理由は 2 つある。リリース候補が入る節目が 1 か所に定まる。兄弟ライブラリがリリースを重ねて落ち着いた形なので、workflow と手順をほぼそのまま流用できる。

## Alternatives Considered

- **`main` の 1 本で開発もリリースも行う**: 却下。公開前の運用から何も変えずに済む。しかしリリースの節目が無く、公開物を確かめる機会がリリースを起動するときの予行だけになる。壊れた状態が `main` に載り得る。兄弟ライブラリの workflow のトリガーとリリースノートの作り方を流用できず、作り直すことになる。
- **`main` の 1 本にして、自分の Pull Request を必須にする**: 却下。壊れた状態は載らなくなる。しかし Pull Request ごとに検証を待つことになり、節目としては細かすぎる。兄弟ライブラリの workflow も流用できない。

## Consequences

- 正: リリース候補が入る節目が 1 か所に定まり、リリース前の確認をそこへ集められる。
- 正: 日々の push は検証を待たない。
- 正: 兄弟ライブラリと同じ形なので、workflow と手順を流用できる。
- 負: `develop` の検証は事後になり、壊れた状態が `develop` に載り得る。失敗を見て直す運用が前提になる。
- 負: `develop` を作り、作業用のブランチの基点を `main` から移す切り替えが要る。
- 負: リリースのたびに `main` 宛ての Pull Request を作る手間が加わる。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-1-public-repo-verify-ci/history.md (2026-10-08: ブランチの役割) / ../KsSettingsView/kasane/decisions/cross/0028-ci-triggers-by-branch-role.md (兄弟ライブラリの形と整理の経緯)
