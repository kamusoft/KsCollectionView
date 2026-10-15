# セカンドオピニオン: user-skill-refresh-skill (spec-001)
**相方**: codex / **label**: so-spec-user-skill-refresh-skill-001 / **日付**: 2026-10-14 / **対象**: 提案一式 (proposal.md・specs/user-docs-refresh/spec.md・tasks.md・kasane/decisions/cross/0020-user-skill-refresh-via-dedicated-skill.md・evidence/skill-pickup-probe.md)
---
実装前に修正したい指摘は5件です。Critical はありません。ビルド・テストの実行、ファイルの変更はしていません。

1. **Major — 追従した結果、変更ファイルが無い場合に完了できない**

   該当箇所: kasane/changes/user-skill-refresh-skill/specs/user-docs-refresh/spec.md:196

   必ず「追従ファイルのcommit → 記録更新のcommit」の2つを作る契約ですが、本体の内部処理だけが変わった場合や、源泉の変更が利用者に関係しない場合は、調査してもSkill・対応表の変更が発生しません。既存handbookの111行も、Skillを直さない判断を認めています。この場合、通常のcommitでは1つ目を作れず、記録を進めないと次回も同じ変更を調べ続けます。

   **推奨修正:** 修正不要と判断した場合の完了経路を定めてください。記録だけをcommitするか、調査結果を残す空commitを許可するかを決め、証跡の保存先とScenarioを追加してください。

2. **Major — READMEを対象外にした方針と、委譲する既存手順が衝突する**

   該当箇所: kasane/changes/user-skill-refresh-skill/proposal.md:28、kasane/changes/user-skill-refresh-skill/specs/user-docs-refresh/spec.md:87

   README追従は対象外ですが、ワーカーに従わせるhandbookの176行は、利用者役の画面が変わった場合にREADMEと4つの`SKILL.md`を同時に直すよう求めています。利用者役の画面はmanifestの源泉に含まれるため、この入力は実際に受け付けます。READMEが旧内容なら例の検査も落ち、範囲内のSkill修正だけでは解消できません。

   **推奨修正:** この場合はREADME変更を別作業へ引き継ぎ、追従完了・記録更新を保留するなど、対象外の修正が必要になった場合の経路を明記してください。handbook草稿にも同じ境界を反映し、Scenarioを追加してください。

3. **Major — 新しい1枚が必要になった場合の停止条件が無い**

   該当箇所: kasane/changes/user-skill-refresh-skill/specs/user-docs-refresh/spec.md:89、kasane/changes/user-skill-refresh-skill/specs/user-docs-refresh/spec.md:227

   構成変更は別の変更実装で行う方針ですが、委譲先の書き方規約67行は、既存の5枚に収まらなければ1枚を追加するよう求めています。ワーカーが追加を必要と判断した場合、オーナーに諮って追従内で追加できるのか、別変更へ移すのかが決まっていません。追加を行うと、書き直しRequirementのSide Effectsが許す「既存の1枚の更新」も超えます。

   **推奨修正:** 既存構成に収まらない場合は構成変更として引き継ぎ、追従済みにはしないことを、ワーカーひな形とScenarioで定めてください。

4. **Minor — 承認前に禁止する「記録の更新」の範囲が曖昧**

   該当箇所: kasane/changes/user-skill-refresh-skill/specs/user-docs-refresh/spec.md:91、kasane/changes/user-skill-refresh-skill/specs/user-docs-refresh/spec.md:145

   書き直し段階ではmanifestの`sources`・`apiExclusions`を更新する一方、承認前は「記録の更新もしない」としています。「記録」はmanifest全体を指す定義なので、文面上は矛盾します。さらに、名前の漏れへの対応で除外候補が承認された場合、その記録更新を検査Requirement自身が行うのか、前のRequirementへ戻すのかも不明です。

   **推奨修正:** 承認前に禁止するのは`syncedCommit`の更新だと明記してください。対応表・除外名の更新をどのRequirementで行うかを定め、そこでSide EffectsとScenarioを揃えてください。

5. **Minor — ADRが、改名時の記録修正を不要と説明している**

   該当箇所: kasane/decisions/cross/0020-user-skill-refresh-via-dedicated-skill.md:32、同52行

   「分割・改名をgitが追うので記録を手で合わせる作業が起きない」としていますが、specの91行は改名した源泉のパス修正をワーカーに任せます。既存スクリプトも類似度で改名候補を検出するだけで、対応表を更新しません。方向を説明するADRが、実際の運用より強い保証になっています。

   **推奨修正:** 「差分と改名候補を検出でき、ファイルごとのハッシュを更新する必要がない。源泉パスの対応表は追従時に修正する」など、現行の道具とspecに一致する説明へ直してください。

## 突き合わせ結果

ホスト側の自己レビュー (`spec-self-review.md`) は、5 件のどれも挙げていなかった。5 件とも、該当の行が実在し、実害の場面が具体的なので、相方のみ・根拠強として採用した。確定 0 / 採用 5 / 降格 0 / 未解決 0。

| # | 判定 | 根拠の確かめ | 反映 |
|---|---|---|---|
| 1 | 採用 (Major) | `kasane/handbook/cross/user-skill-refresh.md:111` は「差分が利用者に見える内容を変えていなければ、Skill は直さなくてよい」としている。直す 1 枚が無いと 1 つ目の commit を作れず、記録の commit の ID も進まない。先例として、Skill の文面を変えずに記録だけを更新した commit `335eef6` がある | 「承認の後の commit と記録の更新」に、直す 1 枚が無いときは記録の commit だけを作り、要約 (直さなかった源泉と理由を含む) を最初に作る commit のメッセージに書くことと、Scenario を足した。tasks 3.5 に試運転を足した |
| 2 | 採用 (Major) | `kasane/handbook/cross/user-skill-refresh.md:176` は、利用者役の画面を変えたときに README と 4 つの `SKILL.md` を同時に直すとしている。利用者役の画面は記録の `sources` にある (`skills/.manifest.json`) | 新しい Requirement「追従の範囲」を足した: README などの範囲の外の直しと違反は、ワーカーに戻さずオーナーに伝え、残ったまま承認されたら記録の commit の ID を更新しない。「検査とオーナーの承認」から、範囲の外の違反をこの Requirement に回した。ひな形 (tasks 1.2)・突き合わせ (3.6)・handbook の草稿 (4.1) に足した |
| 3 | 採用 (Major) | `kasane/handbook/cross/user-docs-writing.md:67` は、今の 5 枚に入らないときに 1 枚を足すとしている。cross/ADR-0005 は、`references/` の再編を変更フローの承認に通すとしている | 「追従の範囲」に、構成の見直し (1 枚の追加・名前の変更・分け方の変更) は追従の中で行わず、変更の実装で行う必要をオーナーに伝えることと、Scenario を足した。「追従の入口の案内」の構成の見直しの言い方を揃えた |
| 4 | 採用 (Minor) | スペックの冒頭の言葉の定義では「記録」は `skills/.manifest.json` 全体を指し、「書き直しの任せ方」はその `sources`・`apiExclusions` を更新するのに、「検査とオーナーの承認」は承認の前に「記録の更新」をしないとしていた | 冒頭に「記録の commit の ID」(`syncedCommit`) の定義を足し、承認の前に止めるのをこれに限った。「検査とオーナーの承認」の Side Effects に `apiExclusions` の更新を足した |
| 5 | 採用 (Minor) | `scripts/docs/skills-refresh.py:342` は、名前の変わった源泉について「追従の記録の sources のパスを直す」と出すだけで、記録を書き換えない | cross/ADR-0020 (proposed) の Decision の理由と Consequences を、「ハッシュを合わせ直す作業は起きない (名前の変わった源泉の記録のパスは、追従のときに直す)」に直した |
