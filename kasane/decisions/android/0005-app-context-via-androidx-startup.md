---
id: 0005
title: 公開 API は Context を引数に取らず、androidx.startup の Initializer でアプリケーションコンテキストを捕捉する
status: accepted
date: 2026-09-07
---

## Context

画像キャッシュの操作 (`KsImageCache.clear` / `remove`) は Coil の共有インスタンス (`SingletonImageLoader`) を引くために `Context` を必要とする。一方 core/ADR-0002 は公開 API のパラメータ名と構造を両プラットフォームで 1 対 1 に揃えると定めており、iOS の `KsImageCache.clear(_:)` / `remove(_:)` に `Context` に当たる引数はない。

前提: Compose を使うアプリには `androidx.startup.InitializationProvider` が既に入っている (Sample の実マニフェストで emoji2 / lifecycle / profileinstaller の 3 件を確認)。androidx.startup の Initializer はこの provider に相乗りし、ライブラリ単独の ContentProvider を増やさない。`androidx.startup:startup-runtime` は Compose 経由で利用者アプリに既に推移している。初期化を無効にする構成 (マニフェストから provider を取り除く) は androidx.startup が案内する正規の運用である。

## Decision

Android の公開 API は `Context` を引数に取らない。iOS と同じ引数構成 (`clear(scope)` / `remove(source)`) にする。

アプリケーションのコンテキストは、androidx.startup の `Initializer` (`KsAppContextInitializer`) が起動時に捕捉し、ライブラリ内部の `KsAppContext` が保持する。本体は `startup-runtime` を明示依存に持ち、マニフェストの `InitializationProvider` に meta-data をマージで登録する。

初期化が動いていない環境 (provider を取り除いた構成) では、コンテキストを要する操作は警告ログを出して何もしない (core/ADR-0011 の「落とさず・黙らず」)。core/ADR-0011 の「debug では assertion」は掛けない — debug 判定は組み込み先アプリのコンテキストから読む作りで、そのコンテキスト自体が無いのがこの局面のため。ライブラリ自身のビルド種別で代用する判定は ADR-0011 が否定している。

## Alternatives Considered

| 案 | 却下理由 |
|---|---|
| `Context` を第 1 引数に取る (`clear(context, scope)` / `remove(context, source)`) | core/ADR-0002 の「パラメータ名は両プラットフォームで 1 対 1」に反する |
| 未初期化時に例外を投げる | 初期化を外す構成は androidx.startup の正規の運用であり、そこでライブラリが例外を投げると利用者に回避手段が無くなる |

## Consequences

- 正: キャッシュ操作の引数構成が両プラットフォームで 1 対 1 になる
- 正: 利用者のアプリに ContentProvider は増えない (既存の provider へ相乗りする)
- 負: 本体の依存に `startup-runtime` が明示的に加わる (利用者への新しい推移依存にはならない)
- 負: 初期化を無効にした構成ではキャッシュ操作が効かず、消えないキャッシュが残る。画像の表示自体は初期化なしでも動くため、症状は「消したはずのキャッシュが残る」として現れる
- 負: 今後 `Context` を要する公開 API を足すときも同じ経路 (`KsAppContext`) に乗せることになり、引数で受ける設計は選べない

## Revisit When

- Compose を使うアプリが `InitializationProvider` を持たなくなったとき (相乗りの前提が崩れる)
- 利用者アプリで初期化を無効にする構成が実際に現れ、警告 no-op では足りないと分かったとき

出典: kasane/changes/archive/2026-09-08-image-loading/deviation.md (Android の `KsImageCache` のシグネチャと本体の依存、2026-09-07 / Android のキャッシュ操作の未初期化時、2026-09-07) / core/ADR-0002 / core/ADR-0011
