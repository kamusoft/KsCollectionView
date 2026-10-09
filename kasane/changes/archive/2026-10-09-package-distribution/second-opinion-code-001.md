# セカンドオピニオン: package-distribution (code-001)
**相方**: codex / **label**: so-code-package-distribution-001 / **日付**: 2026-10-09 / **対象**: commit 192a10b に対する作業ツリーの未 commit の変更 (tasks のグループ 1〜8)
---
# レビュー結果: package-distribution (001 回目)

**日付**: 2026-10-09  
**判定**: CHANGES_REQUESTED  
**対象**: commit `192a10b` に対する未コミットの変更・未追跡ファイル。tasks.md のグループ1〜8  
**出力先**: `review-001.md`（未保存）

## サマリー

配布物の構成、利用者役の取得元の固定、ビルド失敗の伝播、CIの呼び出し条件は、仕様・設計と整合している。一方、SwiftPMの写し作成には、受け付けた作業コピーのGit管理情報を削除し得る問題があるため、修正を求める。

指摘は **Critical 0件・Major 1件・Minor 0件・Suggestion 0件**。静的レビューのみを行い、ビルド・テストは再実行していない。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`：常時適用。追加・変更されたコメントの自己完結性と禁止参照。
- `kasane/handbook/cross/public-identifiers.md`：Maven座標、SwiftPMの宣言、利用者役の識別子。
- `kasane/handbook/cross/verification-ci.md`：workflowの構成、権限、道具の固定、失敗判定、検査スクリプトのテスト。
- `kasane/handbook/cross/test-execution.md`：追加テストと、ホスト側の全件実行の証跡。
- `kasane/handbook/cross/local-development-setup.md`：独立したビルドルートと版の定義元。
- `kasane/handbook/cross/branch-and-github-settings.md`：検査名と、保護更新に向けた草稿。GitHub上の操作は対象外。

関連するaccepted ADRとして、cross/ADR-0002・0003・0013・0014、ios/ADR-0005、android/ADR-0002・0008を照合した。cross/ADR-0015・0016はproposedとして扱い、それ自体を違反判定の根拠にはしていない。

ロードしたスキル: `ksn-review`、`kotlin-impl-skill`。

## 確認した観点

- proposal・design・specsの凍結と、未記録の仕様逸脱。
- グループ1〜8の完了チェックに対応する実装・テスト・証跡。
- 写しの対象、未追跡ファイルの除外、削除前の入力検証、Git状態の保護。
- Androidの発行物、POM、依存の公開範囲、署名条件、SNAPSHOT送信防止。
- `local`／`published`の参照、取得元の固定、本体ソースへの置換の排除。
- iOSの両ビルド先、AndroidのR8有効化・対応表・依存確認。
- 子プロセスの出力と終了コード、準備失敗時の後続停止。
- workflowの起動条件・検査名・入力・権限・時間上限・失敗の見逃し。
- Kotlinのnull安全性、不変性、Gradle Kotlin DSLの構成。
- Android利用者役の起動証跡、一覧の静止画、端末ログ。

ホスト側の最終結果は、4系統のテスト567／48／512／163件とスクリプトのテスト259件が、すべて失敗0・スキップ0。workflow検査・actionlint・標準lintの成功も証跡と照合した。グループ9の未実施と、公開物取得の成功が未確認であることは、今回の指摘に含めていない。

## 指摘事項

### [🟠 Major] `.git` が指す管理情報を削除して作業コピーを壊し得る

**該当箇所**: `scripts/distribution/sync-spm-snapshot.py:210`  
関連箇所: `scripts/distribution/sync-spm-snapshot.py:173`

**問題点**:

`check_working_copy()`は作業ツリーの最上位とoriginだけを確認し、`clear_destination()`は名前が `.git` の項目だけを残して、それ以外を削除する。

Gitは、`.git`を管理情報への参照ファイルとし、管理情報の実体を別のディレクトリに置く構成を正式にサポートしている。[Git公式ドキュメント](https://git-scm.com/docs/git-init#Documentation/git-init.txt---separate-git-dirgit-dir)

例えば、行き先の構成が次の場合である。

```text
KsCollectionView-SPM/
  .git          # .git-data を指す参照ファイル
  .git-data/    # config・HEAD・objects・refs 等
  Package.swift
  Sources/
```

この作業コピーのoriginが指定の配信用リポジトリなら、現在の事前確認を通過する。しかし削除処理は `.git-data/` を削除するため、`.git`だけが残っても、commit・tag等を保持する管理情報が失われる。その後のコピーは成功し得るので、道具は成功を報告したまま作業コピーを壊す。

仕様のScenario「行き先のgitの状態を進めない」が要求するGit状態の保持を満たさない。既存テストは通常の `.git/` 配置を使っており、この条件を検出できない。これは静的解析による指摘で、破壊を伴う再現実行は行っていない。

**推奨修正**:

削除前に、行き先の実際のGit管理ディレクトリと共通管理ディレクトリを取得し、実体パスで削除対象との重なりを確認する。管理情報が削除対象に含まれる場合は、何も変更せずにエラーで中止する。

`.git`が行き先内の別ディレクトリを指す使い捨ての作業コピーを用意し、拒否後もファイル内容・HEAD・commit・tagが変わらないことを確認する回帰テストを追加する。

## アクションプラン

1. 写し作成の事前確認に、Git管理情報と削除対象の重なりの検査を追加する。
2. 別配置のGit管理情報を持つ作業コピーについて、削除前に拒否する回帰テストを追加する。
3. スクリプトのテストと標準lintを確認し、修正差分の再レビューを行う。


## 突き合わせ結果

ホスト側のレビューは `review-001.md` (CHANGES_REQUESTED。Minor 1・Suggestion 2)。

| 区分 | 指摘 | 出典 | 扱い |
|---|---|---|---|
| 採用 | 写しを作る道具が、行き先の git の管理情報の実体 (`.git` が指す別のディレクトリ) を消し得る (Major) | 相方のみ | 該当箇所と壊れ方の筋書きが特定されており、根拠が強い。消す道具の事前の確認の穴なので、修正サイクルに入れる |
| 未解決 (オーナーに諮る) | 公開 API に現れる型を持つ 3 つの成果物が compile の範囲に直接は宣言されていない (Minor・優先度高) | ホスト側のみ | spec の読み方の判断を要するので、宣言を足すか、今の形を乖離として記録するかをオーナーが決める |
| 確定 (任意) | 確認のスクリプトのテスト 2 本だけテストの名前が英語 (Suggestion) | ホスト側のみ | 修正サイクルのついでに日本語へ揃える |
| 確定 (任意) | 利用者役の `activity-compose` の版のコメントが、手で合わせた値を「同じ」と書いている (Suggestion) | ホスト側のみ | コメントを事実だけに直す |

- 採用 1 / 降格 0 / 未解決 1 (矛盾する指摘は無い)
