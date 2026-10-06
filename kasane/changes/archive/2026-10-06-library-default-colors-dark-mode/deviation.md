# Deviation: library-default-colors-dark-mode

- [付随修正] Android の一覧の本体 (`KsCollectionView.kt` の、最終行を幅いっぱいに並べるセルの幅を引く箇所): null にならない値への不要な安全呼び出し (`?.`) を外し、既存のコンパイラ警告を消した。動きは変わらない。理由: 本務で触るファイルにあった既存の警告で、オーナーが同梱を指示 (2026-10-06)

- 蒸留時に反映: concepts・ios/architecture/collection-engine.md — iOS の既定の色 4 つの置き場は `KsDefaultColors`。区切り線は外観で解決される色を 1 つ持つので、外観の切り替えで色を書き込み直さない (実装ワーカーの報告からの追加の材料。採否は蒸留で判断)
- 蒸留時に反映: concepts・android/architecture/compose-wrapper.md — Android の既定の色の置き場は `KsListSeparatorDefaults` (区切り線) と `KsImageDefaults` (画像の 3 つ)。表示モードの判定は、一覧は 1 回読んだ値を区切り線とスクロールインジケータで共用し、画像は既定の表示を出す箇所でだけ読む。先読みを待つ経路は色を部品へ渡し直すだけで、部品を作り直さない (実装ワーカーの報告からの追加の材料。採否は蒸留で判断)
- 蒸留時に反映: handbook・cross/test-execution.md または local-development-setup — worktree には `android/local.properties` が無く、`ANDROID_HOME` を前置きすると Android のテストを流せる (既に書かれているかは未確認。採否は蒸留で判断)
- 蒸留時に反映: handbook・cross/test-execution.md — iOS で画像の表示まで確かめるテストは同期の関数で書く (`async` のテストの中で実行ループを回して待つと、ローダーの結果が表示に届かない)。失敗したときだけ xcodebuild が診断の収集で約 10 分待つことがあり、`-collect-test-diagnostics never` で避けられる (実装ワーカーの報告からの追加の材料。採否は蒸留で判断)
- 蒸留時に反映: concepts — 利用者への案内の材料として、Android で利用者が画面の文脈 (`LocalContext`) ごと差し替えて表示モードを切り替えると、画像は引き当てからやり直しになる (この変更の前からの挙動で、デルタスペックの約束の外。独立レビュー review-001.md の Suggestion。採否は蒸留で判断)
