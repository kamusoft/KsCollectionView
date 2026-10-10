---
id: 0018
title: インストール例には具体の版を書かず、利用者が置き換える印を置く
status: accepted
date: 2026-10-10
---

## Context

インストール例は、ルートの README の 2 枚と、利用者向け Skill の導入の節に載る (cross/ADR-0005)。例に書く値のうち、SwiftPM の Package URL と package の名前、Maven の座標は決まっている (cross/ADR-0003、cross/ADR-0015)。決まっていないのは、版の書き方である。

兄弟ライブラリ KsSettingsView は、例に具体の版を書いていた。その結果、Skill の導入の節に実在しない版が残った。リリースのたびに版を置き換える仕組みを作り、対象を Skill まで広げたが、5 日後に仕組みごと撤去して、版を書かない形に変えた。

利用者向け Skill の追従は、オーナーが頼んだときにだけ行う (cross/ADR-0017)。リリースの工程は、この決定の時点ではまだ作られていない。

前提: リリースのたびに版が変わること。README と Skill を書き換える経路が、オーナーの依頼による追従だけであること。最新の版を確かめられる Release の一覧が、利用者に公開されること。

## Decision

インストール例には具体の版を書かない。版の位置には、利用者が置き換える印 `{version}` を置く。印は版として解決できない形なので、置き換え忘れは依存の解決の失敗として現れる。

リリースの工程は、README と Skill の版を書き換えない。版を置き換える仕組みを持たない。

最新の版は、Release の一覧で確かめてもらう。README と Skill は、インストール例のそばにその案内を持つ。案内先の Release をどこにどう作るかは、この決定の外に置く。

理由は 2 つある。例の中に版が無ければ、古い版や実在しない版が例に残らない。リリースの工程が README と Skill を書き換える経路を作らずに済み、追従をオーナーの依頼に限る決定 (cross/ADR-0017) と別の書き換えの経路ができない。

## Alternatives Considered

- **具体の版を書き、リリースの工程が毎回置き換える**: 却下。例はいつも最新の版になり、貼ればそのまま動く。しかしリリースのたびに例のある全部の場所を書き換える道具と commit が要り、リリースの工程が Skill を書き換える経路ができる。兄弟ライブラリが作って撤去した形である。
- **具体の版を書き、手で直す**: 却下。何も作らずに済む。しかし直し忘れると古い版や実在しない版が残る。兄弟ライブラリで実際に起きた。

## Consequences

- 正: 例の版が古くならず、実在しない版が例に残らない。
- 正: 置き換え忘れが、依存の解決の失敗として現れる。古い版が気付かれずに入ることがない。
- 正: リリースの工程に、文書を書き換える道具が要らない。
- 正: 兄弟ライブラリと同じ書き方になる。
- 負: 例は、貼ってそのままでは動かない。置き換えの説明を、例のそばに添える必要がある。
- 負: 利用者は、最新の版を別の場所で確かめる手間が要る。
- 負: 案内先の Release が利用者に見える形で保たれていないと、案内が役に立たない。Release の作り方が、この決定に縛られる。
- 負: Skill が、最新の版の確かめ先を URL で持つことになる。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-3-user-docs/history.md (2026-10-10: インストール例の版の書き方) / ../KsSettingsView/kasane/decisions/cross/0029-install-examples-without-pinned-version.md (Decision: インストール例の version 表記・置換機構の撤去) / ../KsSettingsView/kasane/changes/archive/2026-09-06-skills-install-version-drift/exploration.md (実在しない版が残った経緯) / kasane/changes/archive/2026-10-10-user-docs/design.md (Decision 1: Skill のファイルの置き方 / Decision 3: ルートの README / Decision 5: インストール例の検査)
現行照合: 2026-10-10 確認。`README.md`・`README_ja.md` と、4 つの `SKILL.md` のインストール例は、版の位置が `{version}` で、置き換えの説明と、最新の版の確かめ先 (Release の一覧) を同じファイルに持つ。`scripts/ci/check-readme-examples.py` が、具体の版・確かめ先の案内が無いことを違反にし、検証 CI のスクリプトのテストから毎回流れる。版を書き換える道具は無い。確かめ先の Release はまだ作っておらず、URL は仮の値である (リリースの工程を決めるフェーズが確定する)。判定: 維持
関連: cross/ADR-0003 (Maven の座標) / cross/ADR-0015 (SwiftPM の Package URL) / cross/ADR-0017 (追従をオーナーの依頼に限る決定) / cross/ADR-0019 (Skill が URL を持つことの扱い)
