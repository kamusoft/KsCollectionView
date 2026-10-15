## ADDED Requirements

### Requirement: iOS のマニフェストが要求するツールの版

`ios/Package.swift` は、Swift 6.4 のツールを要求しなければならない (SHALL)。宣言を上げた後も、iOS の本体と Sample のテストは全件通らなければならない。

**Side Effects**: なし

#### Scenario: 宣言が確かめている版と一致する
- **GIVEN** `ios/Package.swift` がある
- **WHEN** 先頭のツールの版の宣言を読む
- **THEN** Swift 6.4 のツールを要求している

#### Scenario: 宣言を上げてもテストが通る
- **GIVEN** 宣言を Swift 6.4 に上げた状態である
- **WHEN** 手元で、iOS の本体と Sample のテストを絞り込みなしで流す
- **THEN** どちらも実行が 0 件でなく、失敗が無い

### Requirement: SwiftPM の写しを作る

写しを作る道具は、行き先のディレクトリを受け取り、その中身を次の 5 点だけにしなければならない (SHALL)。行き先が無ければ、作ってから写す。

- `Package.swift`: `ios/Package.swift` と内容が同じ
- `Sources/`: `ios/Sources/` のうち、git が追跡しているファイル
- `Tests/`: `ios/Tests/` のうち、git が追跡しているファイル
- `LICENSE`: ルートの `LICENSE` と内容が同じ
- `README.md`: このリポジトリへ案内する固定文

行き先に元からあった中身は、`.git` を除いて残してはならない。道具は、git の commit・push・tag を行ってはならない。写しは、そのディレクトリをルートとする SwiftPM のパッケージとして解決できなければならない。

**Requires**:
- 写しの元 (`ios/Package.swift`・`ios/Sources/`・`ios/Tests/`・`LICENSE`・固定文) がすべてあること
- 行き先が、このリポジトリの中でも、このリポジトリを含むディレクトリでもないこと
- 行き先が、まだ無いパスか、空のディレクトリか、配信用リポジトリの作業コピー (git の最上位で、`origin` が `kamusoft/KsCollectionView-SPM` を指す) であること

**Side Effects**:
- 行き先のディレクトリ: 作成 (無いとき)、`.git` を除く既存の中身の削除、写しの 5 点の作成

#### Scenario: 空の行き先に 5 点が置かれる
- **GIVEN** 空のディレクトリがある
- **WHEN** それを行き先にして道具を流す
- **THEN** 行き先の直下にあるのは `Package.swift`・`Sources`・`Tests`・`LICENSE`・`README.md` の 5 つだけである

#### Scenario: 無い行き先は作られる
- **GIVEN** このリポジトリの外に、まだ無いパスがある
- **WHEN** それを行き先にして道具を流す
- **THEN** そのパスにディレクトリが作られ、直下に写しの 5 点がある

#### Scenario: マニフェストが本体と同じ内容である
- **GIVEN** 道具が写しを作った
- **WHEN** 写しの `Package.swift` と `ios/Package.swift` を比べる
- **THEN** 内容が同じである

#### Scenario: 追跡していないファイルは写されない
- **GIVEN** `ios/Sources/` の下に、git が追跡していないファイルがある
- **WHEN** 道具を流す
- **THEN** 写しの `Sources/` に、そのファイルは無い

#### Scenario: 本体から消えたファイルは残らない
- **GIVEN** 配信用リポジトリの作業コピーに、前の写しがある。前の写しには、今の `ios/Sources/` に無いファイルがある
- **WHEN** その作業コピーを行き先にして道具を流す
- **THEN** 今の `ios/Sources/` に無いファイルは、行き先から消えている

#### Scenario: 行き先の git の状態を進めない
- **GIVEN** 配信用リポジトリの作業コピーがある
- **WHEN** それを行き先にして道具を流す
- **THEN** 行き先の `.git` は残り、commit も tag も増えていない

#### Scenario: README がこのリポジトリへ案内する
- **GIVEN** 道具が写しを作った
- **WHEN** 写しの `README.md` を読む
- **THEN** 固定文と内容が同じで、このリポジトリの URL が書かれている

#### Scenario: 元が欠けていると何も消さない
- **GIVEN** 写しの元のうち 1 つが無い。行き先は、前の写しのある配信用リポジトリの作業コピーである
- **WHEN** 道具を流す
- **THEN** 失敗で終わり、行き先の中身は変わっていない

#### Scenario: このリポジトリの中を行き先にすると拒否する
- **GIVEN** このリポジトリの中のディレクトリがある
- **WHEN** それを行き先にして道具を流す
- **THEN** 失敗で終わり、そのディレクトリの中身は変わっていない

#### Scenario: このリポジトリを含むディレクトリを行き先にすると拒否する
- **GIVEN** このリポジトリを含むディレクトリがある
- **WHEN** それを行き先にして道具を流す
- **THEN** 失敗で終わり、そのディレクトリの中身は変わっていない

#### Scenario: 中身があって配信用リポジトリの作業コピーでない行き先を拒否する
- **GIVEN** 中身があり、配信用リポジトリの作業コピーではないディレクトリがある
- **WHEN** それを行き先にして道具を流す
- **THEN** 失敗で終わり、そのディレクトリの中身は変わっていない

### Requirement: Android の発行物

本体のモジュールを Maven のリポジトリへ発行したとき、座標 `jp.kamusoft:kscollectionview:<版>` に、本体 (AAR)・sources jar・javadoc jar・POM・Gradle のメタデータが置かれなければならない (SHALL)。

- 発行するのは release の 1 種類とする。javadoc jar は中身が空でよい
- POM は、名前・説明・URL・MIT License・開発者・リポジトリの場所を持つ
- 次の依存は compile の範囲で宣言する: 公開 API の宣言に現れる型を持つ依存、利用者が直接使うことを契約にしている依存 (Coil の Compose 連携。利用者が同じローダーのキャッシュを共有するため — core/ADR-0012)、Compose の版を揃える BOM
- それ以外の、内部だけで使う依存は runtime の範囲で宣言する。今 compile の範囲に届けている依存を、runtime の範囲へ動かさない
- 版は、外から渡した値を使う。渡さなければ、バージョンカタログの既定の値を使う
- 署名の鍵を渡したときは、発行物のそれぞれに署名を付ける。渡さないときは、署名なしで発行できる

**Side Effects**:
- 発行先に指定した Maven のリポジトリ (手元のディレクトリ): 発行物の作成
- 本体のモジュールのビルドの出力 (`android/` の下。git の追跡の対象外): 作成、更新

#### Scenario: 鍵なしで手元に発行できる
- **GIVEN** 署名の鍵を渡していない
- **WHEN** 本体のモジュールを、手元のディレクトリへ発行する
- **THEN** 座標の場所に、AAR・sources jar・javadoc jar・POM・Gradle のメタデータがあり、署名のファイルは無い

#### Scenario: 外から渡した版で発行される
- **GIVEN** 版を外から渡した
- **WHEN** 本体のモジュールを、手元のディレクトリへ発行する
- **THEN** 発行物は、渡した版の場所に置かれる

#### Scenario: POM が決めた項目を持つ
- **GIVEN** 手元のディレクトリへ発行した
- **WHEN** POM を読む
- **THEN** 名前・説明・URL・MIT License・開発者・リポジトリの場所がある

#### Scenario: 依存の範囲が公開面と合う
- **GIVEN** 手元のディレクトリへ発行した
- **WHEN** POM の依存を読む
- **THEN** 公開 API の宣言に現れる外部の型を持つ依存は、すべて compile の範囲にある。Coil の Compose 連携も compile の範囲にあり、Compose の BOM は依存の管理に入っている

#### Scenario: 鍵を渡すと署名が付く
- **GIVEN** 使い捨ての署名の鍵がある
- **WHEN** 鍵を渡して、本体のモジュールを手元のディレクトリへ発行する
- **THEN** 発行物のそれぞれに、署名のファイルが付いている

### Requirement: 開発中の版を Maven Central へ送らない

版が `-SNAPSHOT` で終わるとき、Maven Central へ送るタスクは、送信を始める前に失敗しなければならない (SHALL)。手元への発行は、版に関わらず行えなければならない。

**Requires**:
- Maven Central へ送るタスクを実行するとき、版が `-SNAPSHOT` で終わらないこと

**Side Effects**:
- Maven Central: 発行物の送信 (版が `-SNAPSHOT` で終わらず、認証の情報を与えて、送るタスクを実行したときに限る。本変更の実装と確認では実行しない)

#### Scenario: 開発中の版のままでは送れない
- **GIVEN** 版が既定の `0.1.0-SNAPSHOT` である
- **WHEN** Maven Central へ送るタスクを実行する
- **THEN** 送信を始める前に失敗し、開発中の版は送れないことが出力に出る

#### Scenario: 開発中の版でも手元には発行できる
- **GIVEN** 版が既定の `0.1.0-SNAPSHOT` である
- **WHEN** 本体のモジュールを、手元のディレクトリへ発行する
- **THEN** 発行は成功する
