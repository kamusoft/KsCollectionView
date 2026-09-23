---
id: 0014
title: 画像の任意キー — 先読みの要素 KsResource と KsImage の画像ソースの両方に同じ任意キーを持たせ、キーがあれば URL の代わりに鍵の基準にする
status: proposed
date: 2026-09-23
---

## Context

画像の鍵は URL から作られている。先読み (`prefetchResources` の要素 `KsResource`。core/ADR-0013) は URL、表示 (`KsImage(source: .remote(URL))`) は iOS が `url.absoluteString` から世代と `imageID` を決め、Android は `KsImageSource.Remote.url` をそのまま `cacheKey` にする。消去 (`KsImageCache.remove(source)`) と先読みの停止 (`fence`) も同じ URL 文字列で項目を指す。

署名付き URL のように取得のたびに URL が変わる画像では、同じ画像でも鍵が毎回違うため、先読みした項目も保存済みのディスク項目も当たらない。オーナーは `KsResource` で任意のキーを指定し、キーがある要素は URL ではなくそのキー文字列を基に鍵を作ることを求めた (探索 2026-09-23)。

前提: 先読みの宣言は画面内に見えているアイテムを対象にしない (Android は窓が「可視範囲の先」だけで、起動直後のセルは窓の更新より先に作られる。iOS の `prefetchItemsAt` は最初から見えているセルに来ない)。Nuke の `ImageRequest.imageID` はメモリとディスクの両方の鍵に効き、Coil は `memoryCacheKey` / `diskCacheKey` で鍵を指定できる。

## Decision

**先読みの要素 `KsResource` と `KsImage` の画像ソース (`KsImageSource.remote` / `Remote`) の両方に、同じ任意キーを持たせる。キーを指定した画像は、URL の代わりにそのキー文字列を基に鍵を作る。** キーは省略でき、省略した画像は従来どおり URL から鍵を作る。取得そのものには常に URL を使う。

書き口 (引数名は `key`。オーナー判断 2026-09-23): Swift `KsResource(url, width: .column, key: photo.id)` / `KsImage(source: .remote(url, key: photo.id))`、Kotlin `KsResource(url, width = KsWidth.Column, key = photo.id)` / `KsImageSource.Remote(url, key = photo.id)`。キーの既定値を省略 (nil / null) にするため、既存の `.remote(url)` / `Remote(url)` の書き方はそのまま通る。

先読みと表示で同じキーを書くのは利用者の責任とし、2 か所の記述はアプリ側でモデルから `KsResource` / 画像ソースを作る関数を 1 つ用意すればまとめられる (モデル自体には手を入れない)。

**キーを指定した画像は、取得 (ネットワーク) 以外のすべてでキーを URL の代わりに使う** (探索 2026-09-23 論点 2): メモリの鍵 (幅・枠サイズなど従来付け足す部分はそのまま付く)、ディスクの鍵 (iOS は `imageID`、Android は `diskCacheKey`)、削除後に古い項目へ当たらないための世代、URL ごとの鍵の索引 (core/ADR-0013)、先読みの取得単位と `fence`、`KsImageCache.remove(source)` (画像ソースにキーがあればキーで消す)。1 か所でも URL が残ると、URL が変わる画像ではそこだけ毎回食い違うため。ディスクの鍵をキーにすることで、起動をまたいでも取得し直さない。

キーは画像の中身を一意に特定する文字列であることを利用者の責任とし、利用者向けの注意書きに含める。

## Alternatives Considered

| 案 | 却下理由 |
|---|---|
| B: `KsResource` にだけキーを持たせる | 表示側 (`KsImage`) は URL から鍵を作るため、キーで先読みした項目が表示で使われない |
| C: アプリ全体でひとつの「URL → キー」変換を登録する (`KsImageCache` に変換関数を登録する形) | URL から作れないキー (画像 ID など) を書けない。アプリ全体で共有する状態が増え、登録の順番やテスト間の持ち越しが論点になる。署名がクエリに付くだけの場面なら手軽なので、後から A に足す余地は残す |
| D: キーは `KsResource` にだけ書き、ライブラリが先読みの宣言から「URL → キー」の対応を覚えて `KsImage` が URL から引く | 先読みの宣言は画面内に見えているアイテムを対象にしないため、起動直後の 1 画面ぶんがキーの分からないまま URL の鍵で表示され、署名付き URL では起動のたびにそこだけ取得し直す |
| D': D に加え、コレクションがセルを表示するときにも宣言を評価して対応を登録する | 書く場所は 1 か所で済むが、コレクションの外の画面や先読みを宣言していない `KsImage` ではキーが効かず、何も起きずに URL の鍵へ戻る (取得し直しが起きても気づけない)。`KsImage` の動きが周りのコレクションの宣言に左右される見えないつながりができ、表示のたびの宣言評価と対応表の寿命管理で実装も重い |

## Consequences

- 正: 署名付き URL のように URL が変わる画像でも、同じキーなら先読みした項目と保存済みの項目を使える
- 正: URL から作れないキー (画像 ID など) を使える。アプリ全体で共有する状態を持たず、書いたとおりに動く
- 正: 両プラットフォームで同じ形にでき、キーの既定値を省略にすることで既存の画像ソースの書き方は変わらない
- 負: 利用者は先読みの要素とセルの `KsImage` の 2 か所に同じキーを書く。食い違うと、先読みした項目が表示で使われない
- 負: 違う画像に同じキーを付けると取り違える (キーの一意性は利用者の責任)
- 負: ローダーに付属するビュー (`LazyImage` / `AsyncImage`) を URL で直接使う場合とは、キーを指定した項目を共有しない (キャッシュが別になるだけで壊れない)
- 負: 公開型の形が変わる: `KsResource` (core/ADR-0013 で新設) にキーの引数が、`KsImageSource.remote` / `Remote` にキーの値が加わる

## Revisit When

- 署名がクエリに付くだけの画像で、2 か所に同じキーを書く手間が実利用で重いと分かったとき (案 C の「URL → キー」変換の登録を A に足す)

出典: kasane/changes/prefetch-display-size/exploration.md (追加探索 2026-09-23 論点 1) / core/ADR-0008 / core/ADR-0013
