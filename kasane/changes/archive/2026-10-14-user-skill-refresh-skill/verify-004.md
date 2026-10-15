# 一致検証: user-skill-refresh-skill (004 回目)

**日付**: 2026-10-14
**判定**: VALID

`review-003.md` の Suggestion への対応として足した 1 文 (`.agents/skills/docs-refresh/SKILL.md:152` と草稿 `drafts/user-skill-refresh.md:116`) の後の再検証。コンテキストパッケージの指定で、対象を直しが当たる Requirement「承認の後の commit と記録の更新」と、その Scenario に絞った。`verify-003.md` の後に変わったのは `SKILL.md`・草稿・`deviation.md` の 3 枚だけで (更新の時刻で確認)、`SKILL.md` の直しは `:152` の行の中の書き換えなので、行番号は前回から移っていない。ほかの 8 Requirement とその Scenario は、`verify-003.md` の対応表から変わらない (当たる行が変わっていない)。

照合の仕方は前回と同じ。Skill の挙動の Scenario は、tasks 3.4・3.5 の合意に従い、試運転の証跡 (`evidence/refresh-skill-trial.md`) と本文照合で照合した。試運転は今回の直しの前の Skill で行ったものなので、直しが THEN を変えていないかを本文で確かめた。

## 対応表

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **承認の後の commit と記録の更新** | `SKILL.md:140`〜`:168` | 試運転 3.4・3.5、`verify-003.md` の clone での再現 | ✅ 一致 |
| 承認の後、2 つの commit ができ、追従は要らない状態になる | `SKILL.md:144`〜`:148` | 試運転 3.4 の回 3。今回の直しは commit が 1 つもできない経路だけに当たり、この経路 (2 つの commit がある) の手順と証跡の置き場 (`:152` の 1 文目) は変わらない | ✅ 一致 |
| 直す 1 枚が無かったときは、記録の commit だけを作る | `SKILL.md:144`・`:152` (2 文目: 1 の commit を作らなかったときは、記録の commit が最初の commit) | 試運転 3.5 (2)。`record` が止まらない経路なので、今回足した 3 文目の括弧の 2 つ目の経路 (`record` が止まったとき) に当たらない (期待値: 記録の commit だけができ、メッセージに扱った源泉と直さなかった理由がある) | ✅ 一致 |
| 源泉に commit していない変更があると、記録を更新しない | `SKILL.md:146`・`:152` (3 文目)、草稿 `drafts/user-skill-refresh.md:116` | 試運転 3.5 (3) (`evidence/refresh-skill-trial.md:76`。`record` が終了コード 1 で止まり、記録を更新せず、commit していない源泉の一覧と、commit してから更新する必要を伝え、源泉を commit しなかった。HEAD と記録の sha1 は前と同じ)。足した 1 文は、この経路で commit が 1 つも無いときの証跡の置き場 (6 で見せた内容と、止まった理由として伝えた内容) を決めるだけで、THEN の 3 つ (記録を更新しない・一覧と必要を伝える・メインが源泉を commit しない) のどれも変えない。Skill と草稿の文は同じ経路・同じ証跡を指す | ✅ 一致 |
| 追従で変えていないファイルは commit しない | `SKILL.md:144`・`:147` | 試運転 3.4、`verify-003.md` の clone での再現。今回の直しは commit を足さないので当たらない | ✅ 一致 |
| push しない | `SKILL.md:27`・`:150` | 試運転 (`git push` の呼び出し 0)。今回の直しは push に触れない | ✅ 一致 |
| (Requires) 源泉のパスに commit していない変更が無いこと — 範囲の外 | `SKILL.md:146`・`:152` (3 文目) | 試運転 3.5 (3)。Requires を満たさないときの振る舞いに、証跡の置き場が足された | ✅ 一致 |
| 承認の後の commit と記録の更新 — Side Effects | 列挙: git の履歴の commit 2 種・記録の `syncedCommit` の更新。足した 1 文は「commit を作らない経路で、すでに見せた・伝えた内容を証跡とみなす」だけで、ファイル・git の履歴・記録のどれも変える操作を足していない | 本文照合 | ✅ 一致 |

## 追加検査

- [x] tasks.md — 16 件すべて `[x]`。`verify-003.md` の後に変わっていない (更新の時刻 16:02 が `review-003.md` の 16:27 より前)
- [x] 逆流 — `proposal.md`・`specs/` は作業ツリーで未変更 (`git diff --quiet` が 0)
- [x] 未記録乖離 — ❌ は無い。今回の直しは spec からの乖離を作らない
- [x] deviation.md — 最後の蒸留送りの行に、オーナーの指示で実装の中で草稿と Skill の本文の両方に足したことが追記された。乖離の行ではなく、対応表の判定に影響しない。`[付随修正]` の行は無い
- [x] Side Effects — 上の対応表の行のとおり、列挙に収まる
- [x] UI 変更 — 無い
- [x] テスト — `python3 scripts/ci/run-tests.py` 523 件・失敗 0。`check-project-skills.py .`・`check-skills.py .`・3 つの lint (`local-path-lint.py`・`identity-lint.py`・`comment-policy-lint.py`) も違反なし

## 判定

VALID。対象の Requirement と 5 Scenario・Requires・Side Effects の行はすべて ✅ 一致。`verify-003.md` の補足に挙げた、`SKILL.md:152` が `record` の止まる経路を名指ししていない点は、今回の 1 文で解消した。
