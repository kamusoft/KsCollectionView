---
id: 0014
title: 検証 CI は、プラットフォーム別の再利用 workflow と入口 1 本で構成し、検査の名前を固定する
status: accepted
date: 2026-10-08
---

## Context

検証 CI は、`develop` への push の後と、`main` 宛ての Pull Request で走る (cross/ADR-0010)。`main` の保護は、必須の検査を名前で登録する。検査の名前が変わると、登録した名前の検査が報告されなくなり、Pull Request をマージできなくなる。

リリースの workflow は、公開の前に同じ検証を通す予定である。配布物を利用者の立場でビルドする確認も、`main` 宛ての Pull Request に足す予定がある。

兄弟ライブラリ KsSettingsView は、プラットフォーム別の検証を再利用 workflow にして、検証 CI の入口とリリースの workflow の両方から呼んでいる。

前提: `main` の保護が、必須の検査を名前で参照すること。同じ検証を、検証 CI の入口のほかの workflow からも呼ぶこと。

## Decision

iOS と Android の検証を、それぞれ入力を取らない再利用 workflow にする。入口の workflow 1 本がこの 2 本を呼び、lint のジョブを自分で持つ。

検査の名前は `lint`・`ios / verify`・`android / verify` の 3 つに固定し、呼ぶ側と呼ばれる側の両方で名前を明示する。

`main` 宛ての Pull Request では、変更したパスで起動を絞り込まない。絞り込むのは、必須の検査を持たない `develop` への push だけとする。

理由は次のとおり。リリースの workflow が、同じ検証を手順の二重持ちなしで呼べる。検査の名前は `main` の保護が参照するので、ジョブの構成を変えても名前が動かないようにする。`main` 宛ての Pull Request でパスを絞ると、必須の検査が走らないまま通る経路ができる。

## Alternatives Considered

- **入口 1 本に手順を直に書く**: 却下。ファイルが少なく済む。しかしリリースの workflow から同じ検証を呼べず、手順を写すことになる。
- **プラットフォームごとに別の入口を持ち、変更したパスで起動を分ける**: 却下。関係のないプラットフォームの検証を走らせずに済む。しかし片方しか走らない Pull Request で、もう片方の必須の検査が満たされない。必須から外すと、検証を通らないまま `main` に入る経路ができる。

## Consequences

- 正: リリースの workflow と、後から足す確認が、同じ検証を入力なしで呼べる。
- 正: 必須の検査の名前が、ジョブの中身を変えても変わらない。
- 正: `main` 宛ての Pull Request は、何を変えても 3 つの検査が走る。
- 負: workflow のファイルが 3 本に分かれ、検証の全体を読むには 3 本を開く必要がある。
- 負: 検査の名前を変えるときは、workflow と `main` の保護の両方を同時に直す必要がある。
- 負: `main` 宛ての Pull Request では、文書だけの変更でも両プラットフォームの検証が走り、ランナーの時間を使う。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/changes/archive/2026-10-08-public-repo-verify-ci/design.md (Decision 1) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/specs/verification-ci/spec.md (検証 CI の起動条件 / プラットフォームの検証の再利用)
現行照合: 2026-10-08 確認。`.github/workflows/ci.yml` (入口。lint のジョブと 2 本の呼び出し、`develop` への push だけに `paths-ignore`)・`.github/workflows/verify-ios.yml`・`.github/workflows/verify-android.yml` (どちらも `workflow_call` で入力なし、ジョブの名前は `verify`)。GitHub の `main` の保護の必須の検査は `lint`・`ios / verify`・`android / verify`。判定: 維持
関連: cross/ADR-0010 (検証 CI が走る時点) / cross/ADR-0013 (検証 CI が走らせる範囲)
