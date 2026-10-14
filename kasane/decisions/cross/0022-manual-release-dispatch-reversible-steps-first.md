---
id: 0022
title: リリースは版を入力して main から手動で起動し、取り消せる操作から公開して、tag と Release を最後に作る
status: proposed
date: 2026-10-14
---

## Context

リリースの起動元は `main` で、`main` は `develop` からの Pull Request だけを受ける (cross/ADR-0010)。検証 CI のプラットフォームの検証は、入力を取らない再利用 workflow で、別の workflow から呼べる (cross/ADR-0014)。配布物を利用者と同じ書き方で参照する利用者役も、再利用 workflow になっている (cross/ADR-0016)。

公開先は 2 つあり、取り消せるかどうかが違う。

- SwiftPM の配信用リポジトリ (cross/ADR-0015): 写しを push しただけでは、利用者に版として見えない。版として見えるのは、tag を付けたときである
- Maven Central: 送った発行物を、保留の状態で検証させ、取り下げられる。公開した後は取り消せない

Android の本体は、開発中の版を `-SNAPSHOT` で宣言していて、その版のままでは Maven Central へ送れないようにしてある。リリースの版は外から渡す。

兄弟ライブラリ KsSettingsView は、版を入力して手動で起動し、取り消せる操作から公開して、tag と Release を最後に作る形で、10 回リリースしている。Maven Central の検証の決着を待たずに先へ進んで失敗したことがあり、決着を待つ工程を足した。

前提: リリースを起動するのが開発者 1 人で、手動で起動できる頻度であること。Maven Central が、保留と公開の 2 段階の送信を持つこと。SwiftPM が、tag を付けたときに版を見せること。

## Decision

リリースの workflow は、版を入力して手動で起動する。tag の push や Pull Request のマージでは起動しない。本番の公開は `main` からだけ起動でき、公開しない試しはブランチを問わない。公開に使う secret は、`main` だけが使える環境にまとめる。

版の正は、起動のときに入力した値とする。リポジトリの中の宣言は開発中の版のままにし、リリースのたびに版を上げる commit を積まない。

公開は、取り消せる操作から先に進める。配信用リポジトリへ写しを push し (tag は付けない)、Maven Central へ保留で送って検証の決着を待ってから公開する。その後に、配信用リポジトリの tag、本リポジトリの tag (起動した commit)、Release の順に作る。公開の前には、検証 CI と同じ検証と、工程が作った成果物での利用者役の確認を通す。公開の後には、公開物を取得する利用者役の確認を通す。

各工程は同じ版で再実行できる形にし、失敗したら、失敗したところから再実行する。同じ版の tag や公開済みの配布物が、起動した commit から作られたものであれば再実行として続け、別の commit のものなら止める。

理由: 取り消せない操作 (Maven Central の公開) より前に失敗すれば、何も公開されずに終わる。その後に失敗しても、残るのは再実行できる工程だけで、後始末をせずに再実行で両方が揃う。版を入力にすれば、リポジトリの中の宣言と tag を照合する必要が無い。

## Alternatives Considered

- **tag の push で起動する**: 却下。後の工程が失敗すると、iOS だけ先に公開された状態が残る (兄弟ライブラリの却下理由)。
- **リリース用のブランチや Pull Request のマージで起動する**: 却下。tag の push で起動する案と同じく、tag が先に出る問題が残る (兄弟ライブラリの却下理由)。
- **リポジトリの中の宣言を版の正にし、tag と照合する**: 却下。リリースのたびに、版を上げる commit が要る。
- **`develop` から起動する**: 却下。リリースの対象の commit が 1 つに定まらない。
- **同じ版での再実行を禁止する**: 却下。片側だけ公開された版が、欠番として残る。
- **公開の後の利用者役の確認が通ってから tag を作る**: 却下。確認が失敗しても公開は取り消せず、利用者を守れない。

## Consequences

- 正: どの工程で失敗しても、再実行で続けられ、後始末が要らない。取り消せない操作より前の失敗なら、何も公開されない。
- 正: 取り消せない操作 (Maven Central の公開) の後に残るのは、再実行できる工程だけになる。
- 正: リリースのために、版を上げる commit が要らない。
- 負: リリースのたびに、人が版を入力して起動する必要がある。
- 負: リポジトリのファイルからは、リリースの版が読めない。tag と Release を見ることになる。
- 負: Maven Central の保留と公開の 2 段階を、workflow から操作する必要がある。
- 負: Maven Central の公開の後、配信用リポジトリの tag を付ける前に失敗すると、再実行するまでの間、Android だけが公開された状態が残る。
- 負: 公開の後の利用者役の確認が失敗しても、公開は取り消せない。直した版を新しく出すことになる。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/history.md (2026-10-14: 版の付け方と、兄弟ライブラリの踏襲による決定) / kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/artifacts/kssettingsview-release-research-2026-10-14.md (2. リリースの workflow / 5. 運用で起きた問題) / ../KsSettingsView/kasane/decisions/cross/0020-release-dispatch-tag-last-version-injection.md (Decision・却下した案・帰結) / ../KsSettingsView/kasane/changes/archive/2026-09-07-fix-release-central-validation-wait/exploration.md (検証の決着を待つ工程を足した経緯) / kasane/changes/release-pipeline/second-opinion-spec-001.md (tag だけの照合では、公開の後に別の commit から再実行できてしまう指摘)
関連: cross/ADR-0010 (リリースの起動元) / cross/ADR-0014 (検証の再利用 workflow) / cross/ADR-0015 (SwiftPM の配信用リポジトリ) / cross/ADR-0016 (利用者役の確認) / cross/ADR-0021 (版と tag の形)
