## MODIFIED Requirements

### Requirement: 利用者役の参照の書き方

利用者役は、利用者が書くのと同じ書き方で配布物を参照しなければならない (SHALL)。本体のソースを直接参照してはならない。

- iOS の利用者役は、package `KsCollectionView-SPM` の product `KsCollectionView` に依存する
- Android の利用者役は、座標 `jp.kamusoft:kscollectionview` を指す 1 行に依存する
- 配布物をどこから取るかは、切り替え (`local`・`artifact`・`published`) で決まる。`local` は確認が自分で作った公開の前の成果物、`artifact` は外から渡された公開の前の成果物 (リリースの工程が組み立てたもの)、`published` は公開済みの配布物を指す
- Android では、`jp.kamusoft` の取得元を 1 つに固定する

**Side Effects**: なし

#### Scenario: iOS の利用者役が package の名前で product を指す
- **GIVEN** iOS の利用者役のマニフェストを、どれかの切り替えで作った
- **WHEN** target の依存を読む
- **THEN** package `KsCollectionView-SPM` の product `KsCollectionView` を指している

#### Scenario: iOS の local は写しのディレクトリをパスで参照する
- **GIVEN** 切り替えが `local` である
- **WHEN** iOS の利用者役のマニフェストを作る
- **THEN** 依存は、`KsCollectionView-SPM` という名前の写しのディレクトリを、パスで参照している

#### Scenario: iOS の artifact は渡された写しをパスで参照する
- **GIVEN** 切り替えが `artifact` で、写しのディレクトリを渡した
- **WHEN** iOS の利用者役のマニフェストを作る
- **THEN** 依存は、渡された写しのディレクトリを、パスで参照している

#### Scenario: iOS の published は配信用リポジトリを版の完全一致で参照する
- **GIVEN** 切り替えが `published` で、版を渡した
- **WHEN** iOS の利用者役のマニフェストを作る
- **THEN** 依存は、配信用リポジトリの URL を、渡した版の完全一致で参照している

#### Scenario: Android の利用者役の依存は座標の 1 行である
- **GIVEN** Android の利用者役のビルドの定義がある
- **WHEN** アプリのモジュールの依存を読む
- **THEN** 本ライブラリへの依存は、座標 `jp.kamusoft:kscollectionview` を指す 1 行だけである

#### Scenario: Android の local と artifact は作業用のリポジトリだけから取る
- **GIVEN** 切り替えが `local` か `artifact` である
- **WHEN** Android の利用者役が依存を解決する
- **THEN** `jp.kamusoft` の取得元は、作業用の Maven リポジトリ (`artifact` では渡されたもの) だけである

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

成果物の準備は、切り替えで決まる。`local` のときは、今の `ios/` から写しを作り、利用者役に参照させる。`artifact` のときは、写しを作らず、渡された写しのディレクトリを利用者役に参照させる。`published` のときは、写しを作らず、渡した版の公開済みの配布物を利用者役に参照させる。

確認は、Simulator を選ばず、起動もしない。git が追跡しているファイルを変えてはならない。

**Requires**:
- 切り替えが `local`・`artifact`・`published` のどれかであること
- 切り替えが `artifact` のとき、写しのディレクトリが渡され、その中にマニフェストがあること
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

#### Scenario: artifact では渡された写しで同じビルドを行う
- **GIVEN** 切り替えが `artifact` で、写しのディレクトリを渡した。ビルドのコマンドは、実際には走らない形に差し替えてある
- **WHEN** iOS の確認を流す
- **THEN** 写しを作らず、渡された写しを参照する利用者役に対して、Simulator 向けと実機向けの 2 つのビルドを始める

#### Scenario: artifact で写しが無いと始めない
- **GIVEN** 切り替えが `artifact` で、写しのディレクトリを渡していないか、渡したディレクトリにマニフェストが無い
- **WHEN** iOS の確認を流す
- **THEN** ビルドを始めずに、失敗で終わる

#### Scenario: published では写しを作らずに同じビルドを行う
- **GIVEN** 切り替えが `published` で、版を渡した。ビルドのコマンドは、実際には走らない形に差し替えてある
- **WHEN** iOS の確認を流す
- **THEN** 写しを作らず、渡した版を参照する利用者役に対して、Simulator 向けと実機向けの 2 つのビルドを始める

#### Scenario: 知らない切り替えでは始めない
- **GIVEN** 切り替えに `local`・`artifact`・`published` のどれでもない値を渡した
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

成果物の準備は、切り替えで決まる。`local` のときは、今の本体を作業用の Maven リポジトリへ発行し、利用者役にそこから取らせる。`artifact` のときは、発行せず、渡された Maven リポジトリから、渡した版を利用者役に取らせる。`published` のときは、発行せず、渡した版を利用者役に Maven Central から取らせる。

利用者役は、本ライブラリのためのコード縮小の規則を持ってはならない。確認は、利用者の既定の手元の Maven リポジトリに書いてはならず、git が追跡しているファイルを変えてはならない。利用者役を起動しない。

**Requires**:
- 切り替えが `local`・`artifact`・`published` のどれかであること
- 切り替えが `artifact` のとき、Maven リポジトリのディレクトリと版が渡されていること
- 切り替えが `published` のとき、版が渡されていること

**Side Effects**:
- 一時の作業用のディレクトリ (Maven のリポジトリ): 作成 (`local` のとき)
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

#### Scenario: artifact では発行せずに渡されたリポジトリで組み立てる
- **GIVEN** 切り替えが `artifact` で、Maven リポジトリのディレクトリと版を渡した。組み立てのコマンドは、実際には走らない形に差し替えてある
- **WHEN** Android の確認を流す
- **THEN** 本体を発行せず、渡されたリポジトリから渡した版を取る利用者役に対して、リリースの組み立てと依存の確認を始める

#### Scenario: artifact でリポジトリか版が無いと始めない
- **GIVEN** 切り替えが `artifact` で、Maven リポジトリのディレクトリか版のどちらかを渡していない
- **WHEN** Android の確認を流す
- **THEN** 組み立てを始めずに、失敗で終わる

#### Scenario: published では発行せずに同じ組み立てを行う
- **GIVEN** 切り替えが `published` で、版を渡した。組み立てのコマンドは、実際には走らない形に差し替えてある
- **WHEN** Android の確認を流す
- **THEN** 本体を発行せず、渡した版を Maven Central から取る利用者役に対して、リリースの組み立てと依存の確認を始める

#### Scenario: 知らない切り替えでは始めない
- **GIVEN** 切り替えに `local`・`artifact`・`published` のどれでもない値を渡した
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

## ADDED Requirements

### Requirement: 利用者役の再利用 workflow が成果物を受け取る

iOS と Android の利用者役の再利用 workflow は、切り替え `artifact` のとき、同じ run の artifact の名前を入力に受け取り、その artifact を取り込んで確認に渡さなければならない (SHALL)。切り替え `local` と `published` の入力と動きは変えない。検証 CI の入口は、今のまま `local` で呼ぶ。

**Requires**:
- 切り替えが `artifact` のとき、artifact の名前が渡されていること

**Side Effects**:
- ランナーの作業ディレクトリ: 作成 (取り込んだ artifact の中身。`artifact` のとき)

#### Scenario: artifact の名前を渡すと取り込んで確認する
- **GIVEN** 同じ run に、写し (または Maven リポジトリ) の artifact がある
- **WHEN** 切り替えを `artifact` にし、その名前を渡して再利用 workflow を呼ぶ
- **THEN** workflow はその artifact を取り込み、取り込んだディレクトリを確認に渡す

#### Scenario: artifact の名前が無いと始めない
- **GIVEN** 切り替えが `artifact` で、artifact の名前を渡していない
- **WHEN** 再利用 workflow を呼ぶ
- **THEN** 確認を始めずに、失敗で終わる

#### Scenario: 検証 CI の呼び方は変わらない
- **GIVEN** `main` 宛ての Pull Request で検証 CI が走る
- **WHEN** 利用者役の 2 本の呼び方を読む
- **THEN** どちらも切り替え `local` で呼ばれ、artifact の名前を渡していない
