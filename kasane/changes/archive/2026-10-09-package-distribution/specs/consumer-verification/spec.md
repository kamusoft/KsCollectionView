## ADDED Requirements

### Requirement: 利用者役の参照の書き方

利用者役は、利用者が書くのと同じ書き方で配布物を参照しなければならない (SHALL)。本体のソースを直接参照してはならない。

- iOS の利用者役は、package `KsCollectionView-SPM` の product `KsCollectionView` に依存する
- Android の利用者役は、座標 `jp.kamusoft:kscollectionview` を指す 1 行に依存する
- 配布物をどこから取るかは、切り替え (`local`・`published`) で決まる。`local` は公開の前の成果物、`published` は公開済みの配布物を指す
- Android では、`jp.kamusoft` の取得元を 1 つに固定する

**Side Effects**: なし

#### Scenario: iOS の利用者役が package の名前で product を指す
- **GIVEN** iOS の利用者役のマニフェストを、どちらかの切り替えで作った
- **WHEN** target の依存を読む
- **THEN** package `KsCollectionView-SPM` の product `KsCollectionView` を指している

#### Scenario: iOS の local は写しのディレクトリをパスで参照する
- **GIVEN** 切り替えが `local` である
- **WHEN** iOS の利用者役のマニフェストを作る
- **THEN** 依存は、`KsCollectionView-SPM` という名前の写しのディレクトリを、パスで参照している

#### Scenario: iOS の published は配信用リポジトリを版の完全一致で参照する
- **GIVEN** 切り替えが `published` で、版を渡した
- **WHEN** iOS の利用者役のマニフェストを作る
- **THEN** 依存は、配信用リポジトリの URL を、渡した版の完全一致で参照している

#### Scenario: Android の利用者役の依存は座標の 1 行である
- **GIVEN** Android の利用者役のビルドの定義がある
- **WHEN** アプリのモジュールの依存を読む
- **THEN** 本ライブラリへの依存は、座標 `jp.kamusoft:kscollectionview` を指す 1 行だけである

#### Scenario: Android の local は作業用のリポジトリだけから取る
- **GIVEN** 切り替えが `local` である
- **WHEN** Android の利用者役が依存を解決する
- **THEN** `jp.kamusoft` の取得元は、渡した作業用の Maven リポジトリだけである

#### Scenario: Android の published は Maven Central だけから取る
- **GIVEN** 切り替えが `published` である
- **WHEN** Android の利用者役のビルドの定義を読む
- **THEN** `jp.kamusoft` の取得元は、Maven Central だけである

#### Scenario: 本体のソースを参照しない
- **GIVEN** iOS と Android の利用者役がある
- **WHEN** それぞれの定義を読む
- **THEN** iOS は `ios/` をパスで参照しておらず、Android は本体のビルドを取り込んでいない

### Requirement: iOS の利用者の立場のビルドの確認

iOS の確認は、利用者役をリリースの構成で、Simulator 向けと実機向けの両方にビルドしなければならない (SHALL)。両方が成功したときだけ、成功で終わる。ビルドと成功の条件は、切り替えに関わらず同じとする。

成果物の準備は、切り替えで決まる。`local` のときは、今の `ios/` から写しを作り、利用者役に参照させる。`published` のときは、写しを作らず、渡した版の公開済みの配布物を利用者役に参照させる。

確認は、Simulator を選ばず、起動もしない。git が追跡しているファイルを変えてはならない。

**Requires**:
- 切り替えが `local` か `published` のどちらかであること
- 切り替えが `published` のとき、版が渡されていること

**Side Effects**:
- 一時の作業用のディレクトリ (写し・利用者役の写し・ビルドの出力): 作成

#### Scenario: 配布物が正しければ成功する
- **GIVEN** 今の `ios/` がビルドできる状態である
- **WHEN** 切り替えを `local` にして、iOS の確認を流す
- **THEN** Simulator 向けと実機向けの両方のビルドが成功し、確認は成功で終わる

#### Scenario: 写しに本体のソースが欠けていると失敗する
- **GIVEN** 一時のツリーで、利用者役が使う本体のソースを写しから欠いた
- **WHEN** その写しを参照して、利用者役をビルドする
- **THEN** ビルドが失敗し、確認は失敗で終わる

#### Scenario: 片方の行き先だけが失敗しても失敗する
- **GIVEN** Simulator 向けのビルドは成功し、実機向けのビルドが失敗する状態である
- **WHEN** iOS の確認を流す
- **THEN** 確認は失敗で終わる

#### Scenario: published では写しを作らずに同じビルドを行う
- **GIVEN** 切り替えが `published` で、版を渡した。ビルドのコマンドは、実際には走らない形に差し替えてある
- **WHEN** iOS の確認を流す
- **THEN** 写しを作らず、渡した版を参照する利用者役に対して、Simulator 向けと実機向けの 2 つのビルドを始める

#### Scenario: 知らない切り替えでは始めない
- **GIVEN** 切り替えに `local` でも `published` でもない値を渡した
- **WHEN** iOS の確認を流す
- **THEN** 写しもビルドも始めずに、失敗で終わる

#### Scenario: published で版が無いと始めない
- **GIVEN** 切り替えが `published` で、版を渡していない
- **WHEN** iOS の確認を流す
- **THEN** ビルドを始めずに、失敗で終わる

#### Scenario: 追跡しているファイルを変えない
- **GIVEN** 作業ツリーに変更が無い
- **WHEN** iOS の確認を流す
- **THEN** git が追跡しているファイルに、変更が無い

### Requirement: Android の利用者の立場のビルドの確認

Android の確認は、利用者役のリリースを、コード縮小を有効にして組み立てなければならない (SHALL)。組み立ての後に、実行時の依存に座標 `jp.kamusoft:kscollectionview` が指定の版で現れることを確かめる。組み立てと成功の条件は、切り替えに関わらず同じとする。

成果物の準備は、切り替えで決まる。`local` のときは、今の本体を作業用の Maven リポジトリへ発行し、利用者役にそこから取らせる。`published` のときは、発行せず、渡した版を利用者役に Maven Central から取らせる。

利用者役は、本ライブラリのためのコード縮小の規則を持ってはならない。確認は、利用者の既定の手元の Maven リポジトリに書いてはならず、git が追跡しているファイルを変えてはならない。利用者役を起動しない。

**Requires**:
- 切り替えが `local` か `published` のどちらかであること
- 切り替えが `published` のとき、版が渡されていること

**Side Effects**:
- 一時の作業用のディレクトリ (Maven のリポジトリ): 作成
- 本体のモジュールのビルドの出力 (`android/` の下。git の追跡の対象外): 作成、更新 (`local` のとき)
- 利用者役のディレクトリの下のビルドの出力 (git の追跡の対象外): 作成、更新

#### Scenario: 配布物が正しければ成功する
- **GIVEN** 今の本体が発行できる状態である
- **WHEN** 切り替えを `local` にして、Android の確認を流す
- **THEN** 利用者役のリリースが組み立てられ、実行時の依存に本ライブラリの座標が発行した版で現れ、確認は成功で終わる

#### Scenario: コード縮小が走っている
- **GIVEN** Android の確認が成功した
- **WHEN** 利用者役のビルドの出力を読む
- **THEN** リリースの組み立てに、コード縮小の対応表がある

#### Scenario: 作業用のリポジトリに発行物が無いと失敗する
- **GIVEN** 作業用の Maven リポジトリに、指定の版の発行物が無い
- **WHEN** 利用者役を組み立てる
- **THEN** 依存を解決できずに失敗し、確認は失敗で終わる

#### Scenario: 既定の手元の Maven リポジトリに書かない
- **GIVEN** 利用者の既定の手元の Maven リポジトリに、本ライブラリの発行物が無い
- **WHEN** 切り替えを `local` にして、Android の確認を流す
- **THEN** 確認の後も、既定の手元の Maven リポジトリに本ライブラリの発行物は無い

#### Scenario: published では発行せずに同じ組み立てを行う
- **GIVEN** 切り替えが `published` で、版を渡した。組み立てのコマンドは、実際には走らない形に差し替えてある
- **WHEN** Android の確認を流す
- **THEN** 本体を発行せず、渡した版を Maven Central から取る利用者役に対して、リリースの組み立てと依存の確認を始める

#### Scenario: 知らない切り替えでは始めない
- **GIVEN** 切り替えに `local` でも `published` でもない値を渡した
- **WHEN** Android の確認を流す
- **THEN** 発行も組み立ても始めずに、失敗で終わる

#### Scenario: published で版が無いと始めない
- **GIVEN** 切り替えが `published` で、版を渡していない
- **WHEN** Android の確認を流す
- **THEN** 組み立てを始めずに、失敗で終わる

#### Scenario: 追跡しているファイルを変えない
- **GIVEN** 作業ツリーに変更が無い
- **WHEN** Android の確認を流す
- **THEN** git が追跡しているファイルに、変更が無い

### Requirement: 確認の失敗が記録に残る

確認は、成果物の準備とビルドの出力を、加工せずに自分の出力へ流さなければならない (SHALL)。準備またはビルドが失敗したとき、確認はその時点で失敗で終わらなければならない。ビルドを 1 つも実行しないまま、成功で終わってはならない。

**Side Effects**: なし

#### Scenario: 準備が失敗した理由が記録に出る
- **GIVEN** 成果物の準備が失敗する状態である
- **WHEN** 確認を流す
- **THEN** 準備のコマンドが出した失敗の本文が確認の出力に出て、確認は失敗で終わる

#### Scenario: 準備が失敗したらビルドを始めない
- **GIVEN** 成果物の準備が失敗する状態である
- **WHEN** 確認を流す
- **THEN** 利用者役のビルドは始まらない

### Requirement: コード縮小を有効にした利用者役の起動の確認

本変更の実装の中で 1 回、コード縮小を有効にして組み立てた Android の利用者役を、手元で起動して確かめなければならない (SHALL)。確かめた環境と結果を、変更の証跡に残す。

**Side Effects**:
- 作業専用のエミュレータ: 作成、確認の後の削除
- 変更の証跡 (`evidence/`): 作成

#### Scenario: 起動して一覧が表示される
- **GIVEN** 切り替えを `local` にして、コード縮小を有効にして組み立てた利用者役がある
- **WHEN** 作業専用のエミュレータに入れて、起動する
- **THEN** 一覧の項目が表示され、起動から表示までの間に、本ライブラリに由来する致命的な例外が端末の記録に出ない
