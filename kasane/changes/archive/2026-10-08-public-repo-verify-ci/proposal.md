# Proposal: public-repo-verify-ci

## Why

SwiftPM と Maven で配布するには、リポジトリを GitHub に公開する必要がある。今は remote を持たない手元だけのリポジトリで、ライセンス・貢献の受け口・検証 CI のどれも無い。

テストは手元の完了判定で全件流している。しかし、手元の状態に頼らないきれいな環境での検証と、リリース候補が入る節目で必ず通す検査が無い。

フェーズの議論で、履歴の扱い・ブランチの役割・貢献の受け方・ライセンス・公開の時期・検証 CI が保証する範囲とランナーを決めた (cross/ADR-0009〜0013、いずれも proposed)。本変更は、その決定を実物にする。

## What Changes

- **公開リポジトリの体裁**: MIT License の `LICENSE` (名義は `kamusoft`)、準備中と分かる短い README を英日 2 枚、Issue のフォーム 3 本 (バグ報告・提案・質問。英語)、貢献の案内を英日 2 枚置く (cross/ADR-0011・0012)
- **ブランチ**: `develop` を作り、日々の開発の場所を `main` から移す。`main` は `develop` からの Pull Request だけを受ける (cross/ADR-0010)
- **検証 CI**: 入口の workflow 1 本と、iOS / Android の再利用 workflow 2 本を置く
  - 走る時点は、`develop` への push の後と、`main` 宛ての Pull Request
  - 走らせるのは、lint (5 つの検査) と、両プラットフォームの本体のテスト全件 (Simulator / JVM)、Sample のビルドとユニットテスト (cross/ADR-0013)
  - テストの実行が 0 件のときは失敗にする
  - iOS は GitHub の標準のランナー `xcode-27`、Android は Linux の標準のランナーと JDK 21 を使う
- **公開の実施**: 公開前の確認 (履歴に残る証跡の画像の目視・gitleaks による履歴全体の走査・標準の検査) を通してから、GitHub に公開リポジトリを作って履歴ごと push する (cross/ADR-0009)。続けて GitHub の設定を入れる
  - `main` の保護 (lint・iOS・Android を必須の検査にする)、`develop` の保護 (強制 push と削除の禁止)
  - Pull Request を作れる人を共同作業者に限る、Discussions などを閉じる、secret の検査と push の保護を有効にする
- **公開の当日の手順**: 最初の push は非公開の状態で行い、GitHub の画面で中身を目で確かめてから public に切り替える。非公開の時間は確認の間だけで、検証 CI は public にしてから動かす
- **GitHub への操作** (リポジトリの作成・push・public への切り替え・設定) は取り消せない外向きの操作なので、オーナーの承認を得てから行い、実行したコマンドと設定の読み直しを証跡に残す

影響する能力: verification-ci (新規。検証 CI がいつ走り、何を走らせ、何で失敗するか) / repository-publication (新規。公開リポジトリの体裁・貢献の受け口・ブランチと保護)

- 蒸留時に反映: decisions — cross/ADR-0009〜0013 を実装の形で確かめて accepted に昇格する。検証 CI の構成 (再利用 workflow と入口、検査の名前の固定) を ADR にするかを design の ADR 候補から判断する
- 蒸留時に反映: handbook — cross に、ブランチの運用と GitHub の設定の文書を新設する (`develop` への push と `main` 宛ての Pull Request の進め方、`main` と `develop` の保護の内容・入れ方・確かめ方)
- 蒸留時に反映: handbook — cross に、検証 CI の文書を新設する (走る時点・走らせる範囲・緑が保証する範囲・失敗したときの見方・検査を足すときの注意)
- 蒸留時に反映: handbook — `kasane/handbook/cross/test-execution.md` に、端末をつないで走らせるテストの流し方と、流す時点 (画像のデコードに触る変更) を足す
- 蒸留時に反映: handbook — `kasane/handbook/cross/local-development-setup.md` に、作業用のブランチの基点が `develop` であることと、clone した後の準備 (remote・hook の有効化) を足す

## Non-Goals

- **配布物の形と、公開物を利用者の立場でビルドする確認** — 別の能力で、phase-7-2-package-distribution が扱う。`main` 宛ての Pull Request にその確認を足すのも同フェーズ
- **README の本文と `skills/`** — 別の能力で、phase-7-3-user-docs が扱う。本変更が置くのは準備中の案内だけ
- **リリースの workflow・リリースノート・Pull Request のテンプレート** — 別の能力で、phase-7-4-release-pipeline が扱う
- **Sample の UI テスト・端末をつないで走らせるテスト・性能検証を CI に載せること** — cross/ADR-0013 で載せないと決めた
- **Xcode 26 でビルドできることの確認** — フェーズの議論でオーナーが行わないと決めた (検証は Xcode 27 だけ)
- **履歴に残る証跡の画像を履歴から除くこと** — cross/ADR-0009 で行わないと決めた。公開前の目視で除く必要のあるものが見つかったら、実装を止めてオーナーに諮る (同 ADR の前提が崩れるため)

## Impact

- 破壊的変更: なし。公開 API・ライブラリの挙動・テストの中身は変えない
- 公開は取り消せない。公開前の確認を通ることを、push の条件にする
- 公開の後は、commit とそのメッセージ、変更の記録がすべて公開される
- 開発の基点が `main` から `develop` に変わる。作業用のブランチと worktree の切り方が変わる
- リスク: `xcode-27` のランナーは public preview で、稼働の保証が無い。CI の Simulator の負荷で iOS のテストが不安定になる可能性がある。lint は Linux で初めて走るので、手元 (macOS) と結果が違う可能性がある (兄弟ライブラリで起きた)

## 級: L

公開は取り消せず、能力が 2 つにまたがり、Sample の検証の組み方・公開の当日の手順・GitHub の設定の入れ方に設計の決めごとが残るため。

domain: cross
roadmap: v1-foundation/phase-7-1-public-repo-verify-ci
