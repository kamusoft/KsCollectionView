## ADDED Requirements

### Requirement: リリースの起動

リリースの workflow は、版を入力して手動で起動したときだけ走らなければならない (SHALL)。tag の push・Pull Request のマージ・ブランチへの push では起動しない。入力は、版と、公開しない試し (dry-run) の真偽の 2 つで、dry-run の既定は偽である。

版は `X.Y.Z` か、`X.Y.Z-alpha.N`・`X.Y.Z-beta.N`・`X.Y.Z-rc.N` (N は 1 以上の整数) の形でなければならない。本番 (dry-run でない起動) は `main` からだけ受け付ける。dry-run は、どのブランチからでも受け付ける。

**Requires**:
- 版が上の形であること
- 本番の起動元が `main` であること

**Side Effects**: なし

#### Scenario: 正しい版で main から本番を起動する
- **GIVEN** `main` の先端がある
- **WHEN** 版 `0.1.0-beta.1`、dry-run を偽にして起動する
- **THEN** 最初のジョブが入力を受け付け、公開の前の確認へ進む

#### Scenario: 版の形が違うと最初に止まる
- **GIVEN** 版に `v0.1.0`・`0.1`・`0.1.0-pre.1` のどれかを入力した
- **WHEN** 起動する
- **THEN** 最初のジョブが、版の形が違うことを理由に失敗で終わり、配布物を組み立てず、外へ何も送らない

#### Scenario: main 以外から本番を起動すると止まる
- **GIVEN** `develop` から、dry-run を偽にして起動した
- **WHEN** 最初のジョブが走る
- **THEN** 起動元が `main` でないことを理由に失敗で終わり、外へ何も送らない

#### Scenario: main 以外からの dry-run は受け付ける
- **GIVEN** `develop` から、dry-run を真にして起動した
- **WHEN** 最初のジョブが走る
- **THEN** 入力を受け付け、公開の前の確認へ進む

#### Scenario: tag の push では起動しない
- **GIVEN** 本リポジトリに版の形の tag を push した
- **WHEN** GitHub Actions の起動を見る
- **THEN** リリースの workflow は起動していない

### Requirement: 1 本ずつ流れる

リリースの workflow は、同時に 1 本だけ流れなければならない (SHALL)。1 本が走っている間に起動したものは、先のものが終わるまで待つ。先のものは打ち切られない。待っているものがあるときにさらに起動すると、待っていた方は取り消され、後から起動したものが待つ (GitHub Actions の同時実行の決まり)。

**Side Effects**: なし

#### Scenario: 走っている間に起動したものは待つ
- **GIVEN** リリースの workflow が 1 本走っている
- **WHEN** もう 1 本を起動する
- **THEN** 後のものは待ちの状態になり、先のものは打ち切られずに最後まで走る

#### Scenario: 待っているものがあるときに起動すると、待っていた方が取り消される
- **GIVEN** リリースの workflow が 1 本走り、もう 1 本が待っている
- **WHEN** さらに 1 本を起動する
- **THEN** 待っていた方は取り消され、新しく起動したものが待ちの状態になり、走っているものは打ち切られない

### Requirement: 公開の前の確認

リリースの workflow は、本番でも dry-run でも、公開の前に次を通さなければならない (SHALL)。どれかが失敗したら、公開に進まない。

- 検証 CI と同じ、iOS と Android の検証
- 配布物の組み立て: SwiftPM の写しと、入力の版の Android の発行物 (署名しない) を作り、同じ run の後のジョブが使えるように置く
- 組み立てた配布物そのものを使う、iOS と Android の利用者役の確認

dry-run は、公開の前の確認が終わったところで終わる。

**Side Effects**:
- この run の artifact: 作成 (SwiftPM の写し・Android の発行物)
- ランナーの作業ディレクトリ: 作成 (写し・作業用の Maven リポジトリ・ビルドの出力)

#### Scenario: 検証が失敗すると公開に進まない
- **GIVEN** iOS か Android の検証が失敗した
- **WHEN** 後のジョブの状態を見る
- **THEN** 公開のジョブは走らず、配信用リポジトリ・Maven Central・tag・Release のどれにも何も送られていない

#### Scenario: 利用者役は組み立てた配布物を使う
- **GIVEN** 組み立ての段が、写しと発行物を置いた
- **WHEN** 公開の前の利用者役の確認が走る
- **THEN** 利用者役は、置かれた写しと発行物を参照してビルドし、自分では写しも発行物も作らない

#### Scenario: 組み立てた発行物に入力の版が入る
- **GIVEN** 版 `0.1.0-beta.1` で起動した
- **WHEN** 組み立てた Android の発行物の座標を読む
- **THEN** 版は `0.1.0-beta.1` で、`-SNAPSHOT` ではない

#### Scenario: dry-run は公開の直前で終わる
- **GIVEN** dry-run を真にして起動し、公開の前の確認がすべて通った
- **WHEN** run が終わる
- **THEN** 公開のジョブは走っておらず、配信用リポジトリ・Maven Central・tag・Release のどれにも何も送られていない

### Requirement: 公開の順序

本番で公開の前の確認が通ったら、リリースの workflow は、次の順で公開しなければならない (SHALL)。

1. 写しを配信用リポジトリへ push する (tag は付けない)
2. Android の発行物を署名して組み立て直し、Maven Central へ保留で送る
3. 検証の決着を待つ
4. 決着が成功なら公開を指示し、公開済みになるまで待つ
5. 配信用リポジトリに、版の tag を付ける
6. 本リポジトリの、起動した commit に、版の tag を付ける
7. 本リポジトリに Release を作る

Android の発行物は、元になった commit (起動した commit) を発行物の情報 (POM) に持つ。

Release は、tag と題を版の文字列にし、draft にせず、プレリリースの印を付けず、最新の Release として指定して作る。本文は、その run のリリースノートとする。

検証の決着が失敗のとき、または公開を指示する前に run が失敗したときは、後始末として保留の送信の取り下げを試み、tag も Release も作らない。後始末が走らずに残った保留の送信 (run の打ち切りなど) は、次の試行が状態を照会して扱う (「同じ版での再実行」)。公開を指示した後は、取り下げを試みない。

リリースの workflow は、本リポジトリに commit を作らない (版を上げる commit を積まない)。

**Requires**:
- 送る発行物の各ファイルに署名がそろっていること
- 署名して組み立て直した発行物が、組み立ての段の発行物と、署名を除いて同じ中身であること

**Side Effects**:
- 配信用リポジトリ: 写しの commit の push、版の tag の作成
- Maven Central: 発行物の保留の送信、公開の指示、保留の取り下げ
- 本リポジトリ: 版の tag の作成
- 本リポジトリの Release: 作成
- この run の artifact: 作成 (送信の ID の控え。消さずに残す)
- ランナーの作業ディレクトリ: 作成 (署名した発行物・ビルドの出力)

#### Scenario: tag と Release は公開の後に作られる
- **GIVEN** 本番の run が最後まで通った
- **WHEN** 各 step の終わった時刻を並べる
- **THEN** 写しの push・保留の送信・決着の待ち・公開・配信用リポジトリの tag・本リポジトリの tag・Release の順に終わっている

#### Scenario: 検証の決着が失敗なら取り下げる
- **GIVEN** Maven Central の検証の決着が失敗だった
- **WHEN** run が終わる
- **THEN** 保留の送信は取り下げられ、どちらのリポジトリにも版の tag が無く、Release も無い。run は失敗で終わる

#### Scenario: 公開の指示の前に止まったら何も公開されない
- **GIVEN** 保留で送った後、公開を指示する前に run が失敗した
- **WHEN** run が終わる
- **THEN** 保留の送信は取り下げられ、Maven Central にその版は公開されていない

#### Scenario: Release の作りを確かめる
- **GIVEN** 本番の run が版 `0.1.0-beta.1` の Release を作った
- **WHEN** その Release の属性を読む
- **THEN** tag と題は `0.1.0-beta.1`、draft でもプレリリースでもなく、最新の Release であり、本文はその run のリリースノートである

#### Scenario: 発行物が元の commit を持つ
- **GIVEN** 本番の run が Maven Central へ送った発行物
- **WHEN** その POM を読む
- **THEN** 起動した commit が書かれている

#### Scenario: 署名が欠けていると送らない
- **GIVEN** 署名して組み立て直した発行物の一部のファイルに、署名が無い
- **WHEN** 送る前の確認が走る
- **THEN** Maven Central へ送らずに失敗で終わる

#### Scenario: 中身が組み立ての段と違うと送らない
- **GIVEN** 署名して組み立て直した発行物の中身が、組み立ての段の発行物と、署名を除いて違う
- **WHEN** 送る前の確認が走る
- **THEN** Maven Central へ送らずに失敗で終わる

#### Scenario: 版を上げる commit を作らない
- **GIVEN** 本番の run が最後まで通った
- **WHEN** 本リポジトリの `main` を読む
- **THEN** 起動の前から増えた commit は無く、増えたのは版の tag だけである

### Requirement: 同じ版での再実行

リリースの workflow は、同じ版で再実行したとき、済んだ工程を繰り返さずに続けなければならない (SHALL)。再実行は、失敗したジョブの再実行と、同じ版での新しい起動のどちらでもよい。

| 工程 | 2 回目に走ったときの動き |
|---|---|
| tag の検査 (最初のジョブ) | 同じ名前の tag が、本リポジトリでは起動した commit、配信用リポジトリではその commit から作った写しの commit を指していれば、続ける。別のものを指していれば止まる |
| 公開済みの検査 (最初のジョブ) | Maven Central にその版が公開済みなら、公開済みの POM に書かれた元の commit が起動した commit と同じときだけ続ける。違えば止まる |
| 写しの push | 写しに差分が無ければ、commit を作らない |
| Maven Central (公開のジョブ) | その版が公開済みなら、送らず、公開も指示しない。前の試行の送信の控えがあれば、その送信の状態を照会し、次のとおり扱う |
| tag | すでにあれば作らない |
| Release | すでにあれば作らず、本文を書き換えない |

前の試行の送信の控えがあるときの扱い:

| 照会した状態 | 動き |
|---|---|
| 保留中 (検証中・検証済み) | 送り直さず、その送信の決着を待って公開を指示する |
| 公開の処理中 | 送り直さず、公開も指示し直さず、公開済みになるのを待つ |
| 検証の失敗・見つからない (取り下げ済み) | 控えを使わず、新しく送る |

送信の控えは、同じ run の試行の間でだけ引き継ぐ。別の run に残った保留の送信は扱わない。

**Requires**:
- 同じ名前の tag があるとき、上の表のものを指していること
- Maven Central にその版が公開済みのとき、公開済みの POM に書かれた元の commit が、起動した commit と同じであること

**Side Effects**:
- 「公開の順序」の Side Effects のうち、まだ済んでいない工程のもの

#### Scenario: 公開の後で失敗したら、再実行で残りを作る
- **GIVEN** Maven Central の公開の後、配信用リポジトリの tag を付ける前に run が失敗した
- **WHEN** 同じ版で再実行する
- **THEN** Maven Central へは送り直さず、配信用リポジトリの tag・本リポジトリの tag・Release を作って終わる

#### Scenario: tag が別の commit を指していると止まる
- **GIVEN** 本リポジトリに、起動した commit とは別の commit を指す同じ名前の tag がある
- **WHEN** 起動する
- **THEN** 最初のジョブが、tag の食い違いを理由に失敗で終わり、外へ何も送らない

#### Scenario: 配信用リポジトリの tag だけが別の写しを指すと止まる
- **GIVEN** 本リポジトリの tag は起動した commit を指すが、配信用リポジトリの同じ名前の tag は、その commit から作った写しとは別の commit を指す
- **WHEN** 起動する
- **THEN** 最初のジョブが、配信用リポジトリの tag の食い違いを理由に失敗で終わり、外へ何も送らない

#### Scenario: 別の commit から公開済みの版では止まる
- **GIVEN** Maven Central に、commit A から作った版 `0.1.0-beta.1` が公開済みで、どちらのリポジトリにもまだ tag が無い。`main` は commit B に進んだ
- **WHEN** `main` (commit B) から同じ版で起動する
- **THEN** 最初のジョブが、公開済みの発行物の元の commit が起動した commit と違うことを理由に失敗で終わり、写しの push も tag も行わない

#### Scenario: Release がすでにあれば作らない
- **GIVEN** 同じ名前の Release がすでにある
- **WHEN** 再実行が Release の工程に来る
- **THEN** Release を作らず、本文を書き換えない

#### Scenario: 写しに差分が無ければ commit を作らない
- **GIVEN** 配信用リポジトリの先端が、すでに同じ写しである
- **WHEN** 再実行が写しの push の工程に来る
- **THEN** 配信用リポジトリに新しい commit は作られない

#### Scenario: 残った保留の送信を使う
- **GIVEN** 前の試行が保留で送った後、取り下げる前に打ち切られ、送信の控えと、検証済みの保留の送信が残っている
- **WHEN** 失敗したジョブを再実行する
- **THEN** 発行物を送り直さず、残った送信に公開を指示する

#### Scenario: 取り下げ済みの控えは使わない
- **GIVEN** 前の試行の失敗の後始末で保留の送信が取り下げられ、送信の控えだけが残っている
- **WHEN** 失敗したジョブを再実行する
- **THEN** 照会で送信が見つからないので、控えを使わずに新しく送る

#### Scenario: 公開の処理中なら送り直さずに待つ
- **GIVEN** 前の試行が公開を指示した後、応答を受け取る前に失敗し、送信は公開の処理中である
- **WHEN** 失敗したジョブを再実行する
- **THEN** 送り直さず、公開も指示し直さず、公開済みになるのを待ってから tag の工程へ進む

### Requirement: 公開の後の確認

本番で公開が終わったら、リリースの workflow は次を通さなければならない (SHALL)。

- Maven Central の取得先に、その版が現れるまで待つ
- 公開物を取得する、iOS と Android の利用者役の確認
- 本リポジトリの最新の Release が、その版を指すことの確認

待つ処理は上限を持ち、上限に達したら失敗で終わる。

**Side Effects**: なし

#### Scenario: 公開物を取得してビルドする
- **GIVEN** 版 `0.1.0-beta.1` の公開が終わった
- **WHEN** 公開の後の利用者役の確認が走る
- **THEN** iOS は配信用リポジトリを版の完全一致で、Android は Maven Central から、その版を取ってビルドする

#### Scenario: 最新の Release が今回の版を指す
- **GIVEN** 版 `0.1.0-beta.1` の Release を作った
- **WHEN** 最新の Release の確認が走る
- **THEN** 本リポジトリの最新の Release を指す URL が、`0.1.0-beta.1` の Release を指している

#### Scenario: 待ちの上限に達すると失敗で終わる
- **GIVEN** Maven Central の取得先に、上限の時間まで版が現れない
- **WHEN** 上限に達する
- **THEN** 待つ処理は失敗で終わり、run は失敗で終わる

### Requirement: secret の渡し方

リリースで使う secret は、`main` だけが使える環境に置かれ、公開のジョブにだけ渡されなければならない (SHALL)。公開のジョブの中でも、使う step にだけ渡す。dry-run は secret を使わない。署名の鍵・パスフレーズ・認証の情報・書き込みの鍵は、ファイルに書き出さない。

**Side Effects**: なし

#### Scenario: main 以外から起動した run には secret が渡らない
- **GIVEN** `develop` から起動した run
- **WHEN** その run の各ジョブが受け取る secret を見る
- **THEN** どのジョブにも、リリースの secret は渡っていない

#### Scenario: dry-run は secret を使わない
- **GIVEN** `main` から dry-run を真にして起動した run
- **WHEN** run が終わる
- **THEN** 公開のジョブは走っておらず、リリースの secret を受け取ったジョブは無い
