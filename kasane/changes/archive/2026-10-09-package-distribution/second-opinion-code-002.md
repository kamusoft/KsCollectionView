# セカンドオピニオン: package-distribution (code-002)
**相方**: codex / **label**: so-code-package-distribution-002 / **日付**: 2026-10-09 / **対象**: commit 192a10b に対する作業ツリーの未 commit の変更 (tasks のグループ 1〜8。修正サイクル 1 回目の後)
---
# レビュー結果: package-distribution (002 回目)

**日付**: 2026-10-09  
**判定**: CHANGES_REQUESTED  
**件数**: Critical 0 / Major 1 / Minor 0 / Suggestion 0

## サマリー

グループ 1〜8 の実装を静的レビューした。前回指摘された配置の Git 管理情報を保護する修正は入っているが、管理情報が行き先のルートそのものにある場合に、履歴を削除する経路が残っている。依存宣言の合意済み差分と、前回のテスト名・コメントの修正は反映されている。

グループ 9 と `kasane/lessons/inbox/` は対象外とした。ビルド・テストは実行せず、提示された結果と `evidence/` の記録を確認した。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`: 新規・変更されたソースコメント。
- `kasane/handbook/cross/test-execution.md`: テスト追加と、完了判定の件数・実行範囲。
- `kasane/handbook/cross/public-identifiers.md`: Maven 座標、SwiftPM の宣言、利用者役の識別子。
- `kasane/handbook/cross/verification-ci.md`: workflow の追加、検証スクリプト、失敗判定と検査名。
- accepted ADR: cross/ADR-0010・0013・0014、android/ADR-0008、core/ADR-0012。
- `ksn-core` の change-scope・delta-spec・paths: 足場の凍結、合意済み差分、契約と参照形式。

ロードしたスキル: `ksn-review`、`kotlin-impl-skill`。

## 確認した観点

- commit `192a10b` に対する追跡済み差分と、対象の未追跡ファイル。
- proposal・design・デルタスペック 4 枚・tasks・deviation の整合。足場の書き換えは見当たらず、グループ 9 は未完了として残されている。
- SwiftPM の写しの内容、追跡ファイルへの限定、削除前の入力検証、Git 管理情報の保護。
- Android の発行物構成、POM、署名の条件、SNAPSHOT の送信拒否、合意済みの依存宣言。
- 利用者役のソース直接参照の排除、取得元の限定、local / published の切り替え。
- iOS の 2 行き先のビルド、Android の R8 対応表・解決された版の確認、失敗時の打ち切りと出力。
- CI の起動条件、再利用入力、検査名、権限、道具の指定、時間上限、失敗を見逃す指定の有無。
- 正常系・異常系のテスト、証跡と草稿の記述範囲。Android の画面証跡には一覧が表示され、ログ抜粋に致命的な例外は見当たらない。
- ホスト側の検証結果: スクリプト 261 件、Android 本体 512 件・Sample 163 件が失敗・スキップ 0。iOS 本体 567 件・Sample 48 件は修正前に全件成功しており、今回の修正は iOS ソースに触れていない。

## 指摘事項

### [🟠 Major] Git 管理情報が行き先のルートにある場合、削除前検査を通過する

**該当箇所**: `scripts/distribution/sync-spm-snapshot.py:213`

**問題点**: `check_git_directories()` は、管理情報の場所が「削除する子ディレクトリの中にある」場合だけ拒否している。管理情報の場所と `destination` 自体が同じ場合は、この判定に掛からない。

例えば、次の配置で、`config` に `core.bare=false`・`core.worktree=.` と配信用の origin が設定されている場合が該当する。

```text
destination/
  .git          # 内容: gitdir: .
  HEAD
  config
  objects/
  refs/
  …
```

この配置では、Git の最上位と origin の確認を通っても、管理情報の場所は `destination` である。`is_within(destination, destination/objects)` や `is_within(destination, destination/refs)` は偽になるため拒否されず、後続の `clear_destination()` が `HEAD`・`config`・`objects`・`refs` を削除する。`.git` ファイルだけが残り、commit・tag の実体を失う。

前回の「管理情報が行き先の子ディレクトリにある」ケースは回帰テストで覆われているが、この一致境界は覆われていない。本指摘は静的な分岐追跡によるもので、再現実行は行っていない。

**推奨修正**: 子ディレクトリの検査に入る前に、取得した Git 管理ディレクトリ・共通管理ディレクトリのいずれかが `destination` 自体と同じ実体なら、何も削除せず拒否する。上記配置の使い捨てリポジトリで、拒否後も管理情報・HEAD・commit・tag と保存済みの内容が維持される回帰テストを追加する。

## アクションプラン

1. Git 管理情報の場所と行き先が同じ場合の拒否処理と回帰テストを追加する。
2. ホスト側でスクリプトの全テストと標準 lint を実行し、結果を証跡に残す。
3. 修正箇所を再レビューする。その他の前回指摘について追加対応は不要。


## 突き合わせ結果

ホスト側のレビューは `review-002.md` (APPROVED。Minor 1・優先度低)。

| 区分 | 指摘 | 出典 | 扱い |
|---|---|---|---|
| 採用 | 写しを作る道具で、git の管理情報の場所が行き先そのものと同じ構成 (`.git` のファイルが行き先自身を指す) が、消す前の確認を通る (Major) | 相方のみ | 該当箇所と判定の抜け (行き先と同じ場所は「中にある」に当たらない) が特定されている。直しは判定 1 つと回帰テスト 1 件で済むので、修正サイクルに入れる |
| 確定 (文書で境界を示す) | オブジェクトの借用先 (alternates) が行き先の中にある作業コピーでは、成功を報告したまま commit を読めなくなる (Minor・優先度低) | ホスト側のみ | ホスト側が再現済み。通常の clone では起きず、配信用リポジトリから取り直せる。確認は足さず、道具の説明と草稿に、対象外の構成として書く |

- 採用 1 / 降格 0 / 未解決 0 (矛盾する指摘は無い)
- 2 件とも「通常の clone でない作業コピーで、管理情報を消す」という同じ型で、前回の採用の続きにあたる。個別に穴を塞ぎ続けず、確かめる範囲 (管理情報と共通の管理情報の場所) と、確かめない範囲 (借用先など) の境界を道具の説明に書いて、この型を決着させる
