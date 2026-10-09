> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/public-identifiers.md`
> - proposal の「蒸留時に反映」にある、SwiftPM の Package URL と、利用者がマニフェストに書く package の名前を足すための草稿である
> - 追記先は規約 (`kind: rule`) で、規範の正は cross/ADR-0003 である。ADR-0003 は「SwiftPM package 名を `KsCollectionView` とする」と決めている。利用者がマニフェストに書く package の名前が `KsCollectionView-SPM` になることは、cross/ADR-0015 (書いた時点では proposed) が負の結果として書いている。この 2 つの関係 (ADR-0003 を直すのか、ADR-0015 が上書きする範囲を本文で述べるだけにするのか) は、この草稿では決めていない。蒸留で判断する
> - 配信用リポジトリは、書いた時点ではまだ無い。URL は決めた値で、取得できることは確かめていない。蒸留で `timestamp` を動かすかどうかは、この点を踏まえて決める
> - 値の根拠: 利用者役のひな形 (`verification/ios/Package.swift.template`) と、`published` の形のマニフェストを SwiftPM に読ませた結果 (`evidence/consumer-ios.md` の 4.1)

---

## 追記 1: 節「命名方針」の表の直し

`SwiftPM package` の行を、次の 3 行に置き換える。

| 対象 | 規則または値 | 表すもの |
|---|---|---|
| SwiftPM のマニフェストの `name` | `KsCollectionView` | 製品 |
| SwiftPM の Package URL (利用者が依存に書く) | `https://github.com/kamusoft/KsCollectionView-SPM` | 所有主体 + 製品 + 配信用であること |
| 利用者が target の依存に書く package の名前 | `KsCollectionView-SPM` | Package URL の末尾から決まる名前 |

## 追記 2: 節「Maven 座標」の後ろに、節を 1 つ足す

## SwiftPM の Package URL と package の名前

SwiftPM の配布物は、配信用のリポジトリ `kamusoft/KsCollectionView-SPM` から配る ([cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md))。利用者がマニフェストに書くのは、次の 2 行である。

```swift
.package(url: "https://github.com/kamusoft/KsCollectionView-SPM", exact: "<版>"),
```

```swift
.product(name: "KsCollectionView", package: "KsCollectionView-SPM"),
```

- **利用者が書く package の名前は、製品名そのものではなく `KsCollectionView-SPM` である。** SwiftPM は、package を Package URL の末尾の名前で見分ける。マニフェストの `name` (`KsCollectionView`) ではない
- product の名前と、`import` するモジュールの名前は、`KsCollectionView` のままである
- 配信用リポジトリの名前を変えると、利用者が書く package の名前が変わる。公開の後は変えない
- 利用者役 (`verification/ios/`) は、この 2 行と同じ書き方で配布物を取る。書き方を変えるときは、利用者役のひな形も同時に直す ([配布物の形と利用者の立場の確認](package-distribution.md))

## 追記 3: 節「保証すること」に 1 行足す

- 利用者への iOS の案内は、Package URL `https://github.com/kamusoft/KsCollectionView-SPM` と、package `KsCollectionView-SPM` の product `KsCollectionView` への依存で足りる

## 追記 4: 節「関連」に 2 行足す

- [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) — SwiftPM を配信用の別リポジトリから配る決定
- [配布物の形と利用者の立場の確認](package-distribution.md) — 配布物の中身と、利用者役での確かめ方
