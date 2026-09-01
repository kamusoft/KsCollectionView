---
id: 0005
title: ページング契約の外形 — 利用者所有の5状態 enum + コールバック、ライブラリはトリガーと標準フッター
status: proposed
date: 2026-09-01
---

## Context

無限スクロール (ページング状態機械) は roadmap のゴールで、実装は phase-5 が担う。phase-1 では DSL に現れる公開契約の外形だけを決める。本ライブラリの主目的は自社 KMP アプリ量産であり、ページングの取得ロジック・状態遷移は KMP 共有の ViewModel に置きたい。

## Decision

- ライブラリは5状態の公開 enum (`KsPagingState`: idle / refreshing / appending / failed / endReached) を提供する。1値でしか表せないため不正な状態の組み合わせが型で排除される
- **状態の所有者は利用者 (VM)**。DSL には「現在の状態」と「次ページ要求コールバック」を渡す (単方向データフロー)
- ライブラリの責務: 末尾近傍到達でのコールバック発火 (多重発火の抑止込み)、状態に応じた標準フッター描画 (appending → ローディング / failed → リトライボタン / endReached → 終端表示。カスタムテンプレートで差し替え可)、Pull to Refresh と refreshing の接続
- 渡し方は各流儀 (core/ADR-0002): Swift は modifier (`.paging(state) { }`)、Kotlin は名前付き引数 (`paging = KsPaging(state, onLoadMore)`)。Compose の Modifier は見た目・レイアウト装飾限定で、挙動設定は名前付き引数が慣習のため

## Alternatives Considered

- **ライブラリがページング全体を内包する (データソース抽象 `loadPage(cursor)` を渡す、Android Paging ライブラリ風)**: 却下。利用者の実装は最少になるが、データの所有権がライブラリに移り、検索・フィルタ・手動更新との合成や KMP 共有 VM との統合が難しくなる
- **enum を定めず bool フラグ群 (`isRefreshing` / `isAppending` / …)**: 却下。不正な組み合わせが表現できてしまい、フッター描画の分岐契約も曖昧になる

## Consequences

- 正: 状態遷移ロジックが KMP 共有コードに置け、両プラットフォームの VM がほぼ同一構造になる
- 正: phase-5 の状態機械 (遷移の強制・トリガー詳細) をこの enum の上に載せられる
- 負: 状態遷移を利用者が自分で書くため、誤った遷移 (appending 中に refresh 等) の防護は型では効かない。ガイドとフッター挙動でカバーする
- 未決: `failed` にエラー内容を持たせるかは phase-5 またはサンプル作成時に確定する

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: ページング契約の外形) / core/ADR-0002
