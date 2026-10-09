---
id: 0003
title: 公開識別子の名前空間と配布座標
status: accepted
date: 2026-09-01
---

## Context

Apple・Android・Maven Central へ公開する識別子には、後続のモジュールや Sample まで一貫して使える名前空間が必要である。識別子は一度公開すると事実上変更できないため、実装が始まる前に確定させる価値が高い。

プロジェクトオーナーは `kamusoft.jp` ドメインを保有しており、Maven Central の名前空間検証 (DNS TXT) を自身で行える。姉妹ライブラリ群も同じ `jp.kamusoft` 名前空間を使う方針であり、検証は名前空間 1 回で全ライブラリを賄える。

翻案元プロジェクトは Maven の artifactId を製品名の内部にハイフンを含む形 (`ks-settingsview-*`) で運用し、Gradle の `group` も ADR が定めた groupId に追従しない実装 drift を抱えたまま配布直前まで進んだ結果、後から座標の是正 (module 統合・改名・参照追随) を払っている。本プロジェクトはまだ実装が存在せず、その是正コストを回避できる位置にいる。

Android の公開単位は、独自エンジンを持たない Compose Lazy 系の薄いラッパーという方針 (core/ADR-0001) から、層ごとにモジュールを分ける前提を最初から持たない。

## Decision

- Maven Central の groupId は **`jp.kamusoft`** とする。Gradle の `group` にも同じ値を設定し、ADR と実装値を最初から一致させる。
- Android の公開 artifactId は **`kscollectionview`** とし、配布座標を **`jp.kamusoft:kscollectionview`** の 1 点にする。artifactId はブランド名を 1 トークンとして扱い、内部にハイフンを入れない (Maven の慣例: ハイフンはブランドとサブモジュールの境目にのみ使う)。Gradle の project 名・ディレクトリ名も artifactId に揃える。
- Apple のバンドル ID と Android の namespace / application ID は **`jp.kamusoft.kscollectionview.*`** とする。Android の命名要件に合わせ `kscollectionview` は lowercase で連結する。
- Sample アプリケーションの識別子は **`jp.kamusoft.kscollectionview.samples.ios`** / **`jp.kamusoft.kscollectionview.samples.android`** とする。
- Swift 側は PascalCase の慣例に従い、SwiftPM package 名を **`KsCollectionView`**、product 名を `KsCollectionView` を接頭辞とする PascalCase とする。product の分割粒度は iOS エンジン基盤の実装時に決めるが、接頭辞規則はこの決定に従う。
- 後続のモジュール・Sample・ツールは独自の体系を作らず、上記の接頭辞と各エコシステムの表記規則から用途を導く。

## Alternatives Considered

- **artifactId を `ks-collectionview` (ブランド名の内部にハイフン) とする**: 却下。ブランド名の内部にハイフンが入り Maven の慣例から外れる。Android namespace (`jp.kamusoft.kscollectionview.*`) との読みも揃わず、翻案元が後から是正した形をそのまま再現することになる。
- **groupId を `jp.kamusoft.kscollectionview` にして座標を `jp.kamusoft.kscollectionview:kscollectionview` とする**: 却下。製品名が座標内で二重になり、姉妹ライブラリの座標とも揃わない。名前空間検証も `jp.kamusoft` 1 回で全ライブラリを賄えるため、分ける利得がない。
- **Android を層別 (core / ui / compose 相当) の複数 artifact として公開する**: 却下。Android は Compose Lazy 系の薄いラッパーで層分割の前提を持たず (core/ADR-0001)、分割しても利用者に推移する依存は減らない。利用者が書く座標を増やすだけになる。
- 参考 (翻案元での検討): 名前空間の親を `com.kamusoft` / `dev.kamusoft` / `io.github.*` とする案は翻案元で検討・却下されている (`kamusoft.com` は他者保有・新規ドメインの取得維持コスト・ブランド要素の希薄化)。本プロジェクトはその結論を組織共通の前提として引き継ぎ、再検討していない。

## Consequences

- 正: 利用者への Android の案内は `implementation("jp.kamusoft:kscollectionview:x.y.z")` の 1 行で済む。
- 正: 座標 (`jp.kamusoft` + `kscollectionview`) と Android namespace (`jp.kamusoft.kscollectionview.*`) の読みが一致し、姉妹ライブラリと同型になる。
- 正: ADR の groupId と Gradle `group` を最初から一致させるため、配布直前に座標 drift を是正する作業が発生しない。
- 負: Android 側でモジュール境界による層の compile 時強制を持たない (層構造はパッケージ名で表す)。
- 負: 各エコシステムの慣例に従うため、識別子は全プラットフォームで同一文字列にはならず、lowercase reverse-DNS・Maven 座標・PascalCase を使い分ける必要がある。
- 負: 公開後の識別子変更は事実上不可能なため、実装前のこの段階で誤ると是正コストが高い。

出典: ../KsSettingsView/kasane/decisions/cross/0002-public-identifier-namespace.md (Context / Decision) / ../KsSettingsView/kasane/decisions/android/0016-single-module-single-maven-artifact.md (artifactId をブランド 1 トークンとする結論・groupId の是正。翻案元では status: proposed のまま) / ../KsSettingsView/kasane/handbook/cross/public-identifiers.md (Maven 座標の drift) / kasane/changes/kasane-initial-assets/exploration.md (決定事項: artifactId 先取り)
関連: cross/ADR-0015 (SwiftPM は配信用リポジトリ `KsCollectionView-SPM` から配る。マニフェストの `name` は `KsCollectionView` のままで、利用者がマニフェストに書く package の名前は、配信用リポジトリの名前 `KsCollectionView-SPM` になる)
