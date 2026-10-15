---
id: 0021
title: すべてのプラットフォームに 1 つの版を付け、本リポジトリと配信用リポジトリに同じ版の文字列の tag を付ける
status: proposed
date: 2026-10-14
---

## Context

配布物は 2 つある。iOS は、配信用リポジトリ `KsCollectionView-SPM` に置く本体の写しで、SwiftPM は版をそのリポジトリの tag から読む (cross/ADR-0015)。Android は、Maven Central の `jp.kamusoft:kscollectionview` で、版は発行物の座標に入る (cross/ADR-0003)。

インストール例は、ルートの README の 2 枚と、利用者向け Skill に載る。版の位置は、両プラットフォームとも同じ印 `{version}` で、最新の版の確かめ先は、本リポジトリの Release の一覧 1 つである (cross/ADR-0018)。Android の本体は、開発中の版を `-SNAPSHOT` で宣言し、リリースの版を外から渡す作りになっている。

兄弟ライブラリ KsSettingsView は、すべてのプラットフォームに同じ版を付け、本体と配信用リポジトリに接頭辞なしの同じ文字列の tag を付けて、10 回リリースしている。兄弟ライブラリの調べでは、SwiftPM は `ios-1.0.0` のような接頭辞付きの tag を版として読めない。Maven の版の比較では、`-pre` や `-preview` を付けた版が、正式版より新しいと判定される。

前提: SwiftPM が、配信用リポジトリの tag から版を読むこと。インストール例と最新の版の確かめ先が、プラットフォームで分かれていないこと。

## Decision

iOS と Android の配布物に、同じ 1 つの版を付ける。片方のプラットフォームだけが変わったリリースでも、両方に同じ新しい版を出す。

版は semver の形にする。プレリリースの版には、Maven の版の比較で正式版より前に並ぶ語 (alpha・beta・rc) だけを使う。

tag は、版の文字列そのもの (接頭辞なし) にする。本リポジトリと配信用リポジトリの両方に、同じ文字列の tag を付ける。

理由は 2 つある。利用者は、プラットフォームをまたいで 1 つの版で話せ、インストール例と最新の版の確かめ先を 1 つに保てる。tag と版が同じ文字列なら、リリースの工程・手順書・検証の各所で、接頭辞を付け外しせずに済む。

## Alternatives Considered

- **プラットフォームごとに版を分ける**: 却下。変わった側だけを出せ、片方のビルドが失敗しても、もう片方は出せる。しかし最新の版の確かめ先が分かれ、README と Skill の 6 つのファイルと、Skill が持ってよい URL の一覧を書き直すことになる。本リポジトリの tag には接頭辞が要る。兄弟ライブラリと揃わない。
- **tag を `v` 付きの版にする**: 却下。リリースの工程・手順書・検証の各所で、`v` の付け外しが要る (兄弟ライブラリが却下した理由)。

## Consequences

- 正: 利用者は、両プラットフォームを 1 つの版で指せる。インストール例と最新の版の確かめ先が 1 つで済む。
- 正: tag と版が同じ文字列なので、どこでも変換が要らない。
- 正: 兄弟ライブラリと同じ形になる。
- 負: 変わっていないプラットフォームにも、中身が同じ新しい版が出る。
- 負: 片方のプラットフォームのビルドや公開が失敗すると、リリース全体が止まる。
- 負: プレリリースの版に使える語が限られる。

## Revisit When

- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/history.md (2026-10-14: 版の付け方と、兄弟ライブラリの踏襲による決定) / kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/artifacts/kssettingsview-release-research-2026-10-14.md (1. ADR 3 枚 / 4. 版と tag の対応) / ../KsSettingsView/kasane/decisions/cross/0019-lockstep-single-version.md (Decision・却下した案) / ../KsSettingsView/kasane/decisions/cross/0020-release-dispatch-tag-last-version-injection.md (tag の表記)
関連: cross/ADR-0003 (Maven の座標) / cross/ADR-0015 (SwiftPM の配信用リポジトリ) / cross/ADR-0018 (インストール例の版の印と、最新の版の確かめ先)
