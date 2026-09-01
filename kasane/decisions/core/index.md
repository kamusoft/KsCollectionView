# core ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-asymmetric-rendering-engines.md) | 描画エンジンの非対称構成 | accepted | iOS は UICollectionView ベースのエンジン + `UIHostingConfiguration` セル、Android は Compose Lazy 系の薄いラッパー。対称性は公開 DSL の層で担保する。 |

採番規則は [../index.md](../index.md) を参照。
