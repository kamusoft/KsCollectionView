---
id: 0011
title: 不正入力 (重複 ID・未登録テンプレートキー) は debug では assertion、release では表示を継続して警告ログを出す
status: proposed
date: 2026-09-02
---

## Context

コレクションの状態モデル (core/ADR-0003) は安定 ID の配列内一意を利用者契約とし、テンプレート宣言 (core/ADR-0004) は未登録キーの扱いを「debug は assertion、release は最小高の空セル + 警告ログ」と決めていた。一方、重複 ID と重複テンプレートキー (同じキーへの二重登録) については、デルタスペックが debug の assertion だけを定め、release での挙動が未決だった。

## Decision

不正入力は種類ごとに次の挙動とし、release では落とさず・消さず・黙らずを共通方針とする。

| 不正入力 | debug | release |
|---|---|---|
| 未登録テンプレートキーの要素 | assertion | 該当位置に最小高の空セルを表示し、警告ログ (core/ADR-0004) |
| 配列内の重複 ID | assertion | 後勝ち (後の要素を採用) で表示を継続し、警告ログ |
| 同じキーへの `Template` の二重登録 | assertion | 後勝ちで登録を継続し、警告ログ |

「継続 + 警告ログ」に揃えるのは、release で利用者のアプリを落とさないこと、要素を黙って非表示にして件数整合を崩さないこと、そして開発中に気づける経路 (debug assertion) を残すことの 3 点を両立させるため。

## Alternatives Considered

- **release でも assertion (クラッシュ) で止める**: 却下。利用者のアプリをデータ由来の入力で落とすことになる。
- **重複 ID の要素を非表示にする**: 却下。未登録キーの扱いで既に「静かに消えると気づけず件数整合も崩す」として不採用になっており、同じ理由が当てはまる。
- **重複 ID は先勝ちにする**: 出典に検討記録なし (オーナー判断で後勝ちに確定)。

## Consequences

- 正: 不正入力の release 挙動が 3 種類とも同じ原則で説明でき、利用者向けドキュメントに 1 か所で書ける。
- 正: Android 実装も同じ表で揃えられる。
- 負: 後勝ちは「どの要素が表示されるか」を配列順に依存させる。重複 ID を出す利用者コードは release で気づきにくく、debug での確認に頼る。
- 負: 警告ログの出力先・形式は現時点で規約化されていない (実装は OS 標準のログ)。

出典: kasane/changes/archive/2026-09-04-ios-engine-foundation/deviation.md (重複 ID / 重複テンプレートキー、2026-09-02) / kasane/changes/archive/2026-09-04-ios-engine-foundation/specs/collection-core/spec.md (未登録キーの挙動・プレーンな配列と安定 ID) / core/ADR-0003 / core/ADR-0004
