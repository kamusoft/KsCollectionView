# Deviation: user-docs

- 蒸留時に反映: handbook・`kasane/handbook/cross/verification-ci.md` — スクリプトのテストの件数の記述 (2026-10-09 時点で 262 件) を、本変更の後の件数に合わせる (件数は、最後の完了判定の実測を `evidence/local-completion.md` から取る)
- 蒸留時に反映: concepts・`kasane/concepts/core/core-model/collection-reorder.md` — 「ソートしたままの配列を渡すと、置いた項目がソートの位置へ動く」の文を、コードの動き (配列は値で比べるので、置く前と等しい配列が届く間は置いた位置のまま。次に違う配列が届いたときにソートの位置になる) に合わせるかを確かめる。Skill はコードに合わせて書いた
- 蒸留時に反映: concepts・`kasane/concepts/core/core-model/collection-interaction.md` — iOS の末尾へのスクロール命令がフッターを表示範囲に入れないこと (今は `collection-paging.md` の表にだけある) と、スクロール命令の位置の基準 (`contentPadding` の内側か、一覧の端か) が iOS と Android で同じかを、実物で確かめて書く
- 蒸留時に反映: concepts・`kasane/concepts/core/styling/collection-layout.md` — 幅で列の数を決める指定に 0 以下の幅を渡したときのリリースビルドの動き (Android は 1 dp として扱う。iOS は決まった扱いが無い) と、列の数に 0 以下を渡したときの iOS のリリースビルドの動き (警告のログは出ず、1 に丸める) を、コードに合わせる
