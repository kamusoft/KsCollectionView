# セカンドオピニオン: prefetch-display-size (spec-001)
**相方**: codex / **label**: so-spec-prefetch-display-size / **日付**: 2026-09-22 / **対象**: 提案一式 (proposal.md / design.md / specs/image-loading/spec.md / tasks.md)
---
# レビュー結果: prefetch-display-size

**判定**: **NEEDS_DISCUSSION**  
**指摘件数**: Critical 0 / Major 6 / Minor 1 / Suggestion 0

## サマリー

狙いと実機検証方針は妥当ですが、取得単位・索引の保証・不正幅・並行アクセスについて仕様が閉じていません。このまま実装すると、Scenario を同時に満たせない箇所や、プラットフォームごとに異なる解釈が生じます。

依頼どおり静的レビューのみで、ビルド・テスト・ファイル書き込みは行っていません。

## 照合した規約

- ソースコメント規約（always）
- Sample のプラットフォーム間一致
- 実行時挙動の検証規約
- スクロール性能の体感ゲート
- iOS 性能検証の手順
- Android 性能検証の手順
- `swift-ui-impl-skill`
- `kotlin-impl-skill`
- `jetpack-compose-impl-skill`

## 指摘事項

### [🟠 Major] `disk` 到達点で、幅違いの独立取得・独立取消を実現できない

**該当箇所**: `specs/image-loading/spec.md:8`, `specs/image-loading/spec.md:99`, `specs/image-loading/spec.md:116`, `design.md:61`, `design.md:82`

**問題点**:  
`disk` では幅を要求へ含めない一方、同じ URL の幅違いを別取得として数え、一方だけを取り消す契約になっています。幅違い Scenario は到達点を指定していないため、既定の `disk` にも適用されます。

iOS の設計では到達点ごとの単一 `ImagePrefetcher` を維持しますが、`disk` の `(URL, 40)` と `(URL, columnWidth)` は同一の `ImageRequest` になります。Nuke は同一要求を一つへまとめ、`stopPrefetching` は start/stop の回数を参照数として扱わないため、一方の取消が残る要求まで止め得ます。

**推奨修正**:  
取得単位を到達点ごとに定義してください。推奨は次です。

- `disk`: URL 単位。幅違いも同じ参照数へまとめる
- `memory`: URL + 正規化済み幅 px 単位
- 幅違いの独立取消 Scenario は `memory` と明記する

`disk` でも論理的な独立取消を保証するなら、同一ローダー要求に対する購読ハンドルを個別に保持できる別方式が必要です。

### [🟠 Major] 上限付き索引が先に追い出されると、メモリ項目が存在しても契約どおり引き当てられない

**該当箇所**: `design.md:45`, `design.md:47`, `specs/image-loading/spec.md:41`, `specs/image-loading/spec.md:132`

**問題点**:  
spec は「範囲内のメモリ項目があれば使い、ローダー要求を出さない」と無条件に保証しています。一方、索引はローダーとは独立した上限 4,000 の LRU です。

ローダーのキャッシュに画像が残ったまま索引だけが追い出されると、`KsImage` はその項目を発見できず、新しい要求を出します。`tasks.md:43` の LRU 上限テストだけでは、この契約破れを検出できません。小さい画像が多数ある場合など、ローダーが4,000件を超えて保持しない保証もありません。

**推奨修正**:  
次のどの保証を採るか、仕様として決めてください。

- ローダーに存在するライブラリ登録項目は必ず索引にも存在するよう、寿命を一致させる
- 索引から追い出す際に対応するローダー項目も消す。ただし共有キャッシュへの副作用を許容する判断が必要
- spec を「索引に残る項目」に限定し、索引脱落時の再要求を許容する

現状の「索引は上限付きだが、メモリにある全項目を必ず発見できる」は両立しません。

### [🟠 Major] 固定幅および計算後の列幅について、有効値の定義と縮退挙動がない

**該当箇所**: `specs/image-loading/spec.md:8`, `design.md:61`, `design.md:72`, `tasks.md:26`

**問題点**:  
公開 API は Swift の `Double`、Android の `Dp` を受けるため、0、負数、NaN、Infinity、`Dp.Unspecified` を表現できます。また、コンテナ幅より padding と列間隔が大きければ、列幅の計算結果も 0 以下になります。

これらを px へ丸めたりローダー要求・台帳鍵に使った場合、例外、無効な要求、NaN による重複排除不能、要求の増殖などが起こり得ます。現状は Requirement、Scenario、tasks のいずれにも扱いがありません。

**推奨修正**:

- 固定幅は有限かつ 0 より大きい値だけを有効と定義する
- 不正な公開入力の debug/release 挙動を決める
- レイアウトから解いた幅が有限かつ正になるまで先読み要求を出さない
- 0、負数、NaN、Infinity、`Dp.Unspecified`、過大な padding の Scenario とテストを追加する

### [🟠 Major] Android のプロセス共有索引に必要な並行性契約がない

**該当箇所**: `design.md:47`, `tasks.md:21`, `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:37`, `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:35`

**問題点**:  
新しい索引はプロセス共有で、表示・先読みから登録／検索され、`KsImageCache.clear/remove` から削除されます。現行コード自身が「キャッシュ操作は任意スレッドから呼べる」として台帳をロックしていますが、新索引の直列化方法と原子性は design にありません。

実装次第では、検索中の `clear/remove` による破損、削除直後の古い鍵の再登録、キャッシュ削除済みなのに索引だけ残る状態が発生します。

**推奨修正**:

- Android 索引を thread-safe とすることを design に明記する
- 登録・検索・LRU 更新・全消去・URL 単位削除の直列化方法を決める
- `clear/remove` の復帰時点でキャッシュと索引の両方が無効になっていることを保証する
- 登録と `clear/remove` が競合するテストを tasks に追加する

### [🟠 Major] 列幅変更時の「既存要求」と「新しい要求」の境界が検証不能

**該当箇所**: `design.md:72`, `design.md:78`, `design.md:82`, `tasks.md:30`, `tasks.md:34`, `specs/image-loading/spec.md:25`, `specs/image-loading/spec.md:121`

**問題点**:  
design は回転時に旧幅の先読みを取り消して再発行する案を却下し、新しいアイテムだけを新幅で始める方針です。一方で、台帳は「アイテム → 解決済みの URL + px 幅」で持ち、Android は各 `update` で幅を解き直す計画です。

現在の Android 台帳は再評価結果が変われば既存要求を release する構造なので、素直な改修では回転直後に旧幅を取消・新幅を再発行し、却下案そのものになります。既存アイテムに対して宣言の再評価は必要ですが、列幅変化だけを無視する方法が決まっていません。

**推奨修正**:

- アイテムが返した意味上の宣言（URL + `columnWidth`/固定値）と、開始時の解決済み要求（URL + px 幅）を別に保持する
- 回転だけでは既存の進行中要求を取消・再発行しない
- 新たに窓へ入るアイテムだけを新幅で開始する
- 「回転しても既存要求の start/cancel 回数は変わらず、その後に入ったアイテムは新幅になる」Scenario と両プラットフォームのテストを追加する

### [🟠 Major] 新しい iOS 共有索引のメモリ検証が完了条件に入っていない

**該当箇所**: `design.md:47`, `tasks.md:51`, `tasks.md:55`, `kasane/handbook/ios/performance-verification.md:75`, `kasane/handbook/ios/performance-verification.md:100`

**問題点**:  
両プラットフォームへ最大4,000件のプロセス共有索引を追加しますが、完了時のメモリ計測は Android のみです。iOS 性能規約は画像ロード変更を対象とし、全件走査後の定常化と保持対象の解放確認を要求しています。

単体の LRU 上限テストでは、`ImageRequest`、URL、世代識別子などを含む索引の実メモリ量や、画面離脱後の増加停止を証明できません。

**推奨修正**:

- iOS にも画像グリッド全件往復後のメモリ定常化確認を追加する
- Android もローダーキャッシュ量の減少だけでなく、索引込みで定常化することを確認する
- 画面離脱後も索引が上限を超えず、コレクション／セルを保持しないことを確認対象にする

### [🟡 Minor] `proposed` ADR を「確定済み」と記述している

**該当箇所**: `design.md:7`, `proposal.md:11`, `kasane/decisions/core/0013-prefetch-display-size-hint.md:4`

**問題点**:  
ADR-0013 は `proposed` ですが、design は「方針は…確定済み」としています。レビュー前から決定済みと読め、今回のスペックレビューで設計変更が必要になった場合の扱いが不明瞭です。

**推奨修正**:  
レビュー・承認までは「提案中の方針」「本 proposal で確定予定」などに改め、accepted 後に確定済みとしてください。

## アクションプラン

1. `disk` の要求同一性と、索引脱落時の保証を設計判断として確定する。
2. 幅の有効範囲、列幅変更時の既存要求、Android の並行性契約を Requirement／Scenario に落とす。
3. 対応する単体・競合・回転テストと、iOS を含むメモリ完了条件を tasks に追加する。
4. ADR-0013 の状態に合わせて design の確定表現を修正し、再レビューする。

## 突き合わせ結果

ホスト側の自己レビュー (2 周) の通過状況と突き合わせた。自己レビューはチェックリストを通過していたため、以下はすべて「相方のみ」の指摘。

| # | 指摘 | 採否 | 反映 |
|---|---|---|---|
| 1 | `disk` で幅違いの独立取得・取消が成立しない (Nuke は同一要求を統合、参照数を持たない) | **採用** (根拠強: iOS の要求同一性を実物で特定) | 取得単位を到達点ごとに定義: `disk` は URL 単位、`memory` は URL + 幅 px 単位。spec「プリフェッチの取り消し」と design Decision 6 を改訂、幅違い Scenario を `memory` に限定し `disk` の Scenario を追加 |
| 2 | 上限つき索引が先に追い出されると「範囲内の項目があれば必ず使う」契約が破れる | **採用** (根拠強: 契約と設計が両立しない) | 契約を「ライブラリが把握している項目」に限定し、外れた項目の再要求を許容する形に spec を改訂。design Decision 3 に上限の根拠 (ローダーの実用容量を上回る) と lookup 時の刈り込みを明記 |
| 3 | 固定幅・列幅の有効値と縮退挙動が未定義 (0・負数・NaN・無限大・`Dp.Unspecified`・過大な余白) | **採用** (根拠強: 公開 API の入力域) | 有効値 = 有限かつ 0 より大きい。無効な固定値は不正入力 (debug assertion / release 警告 + その URL を幅なし扱い)。列幅が 0 以下に解ける間は列幅の先読みを開始しない。Scenario 2 本と tasks を追加 |
| 4 | Android のプロセス共有索引に並行性契約が無い | **採用** (根拠強: 現行の台帳が任意スレッドからの `clear` / `remove` を前提にしている) | design Decision 3 に thread-safe と直列化の方法、`clear` / `remove` 復帰時点の保証を明記。競合テストを tasks に追加 |
| 5 | 列幅変更時、Android 台帳の素直な改修は旧幅の取消・再発行 (却下案 B) になる | **採用** (根拠強: 現行 `update` の release 条件を特定) | 台帳を「宣言 (URL + 幅の種類) で突き合わせ、解決済み要求 (URL + px) で取り消す」の 2 層に。回転だけでは既存要求を触らない Scenario とテストを追加 |
| 6 | iOS の索引のメモリ検証が完了条件に無い (ios/performance-verification が要求) | **採用** (根拠強: handbook の適用範囲) | tasks 8.3 を両プラットフォームに拡張し、索引込みの定常化と画面離脱後の保持なしを確認対象に |
| 7 | proposed の ADR を「確定済み」と記述 | **採用** (Minor) | design / proposal の表現を「提案中の方針 (本 proposal で確定予定)」に修正 |

確定 0 / 採用 7 / 降格 0 / 未解決 0。オーナーに提示する設計判断: #2 の契約の限定 (索引に無い項目は再要求) と #3 の無効幅の扱い (幅なし扱い)。
