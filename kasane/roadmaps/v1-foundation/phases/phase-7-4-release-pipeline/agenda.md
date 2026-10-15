# リリースの手順

リリースの工程 (版・起動・公開・リリースノート) と、`main` の運用の決まりを作り、自動化する。

## 論点

(なし。2026-10-14 にすべて決定事項へ移した)

## 申し送り (論点の材料)

各項目の先頭の印は、扱った論点 (決定事項の同じ名前の小節)。「参考」は決めることを持たない。提案のときの入力に使う。

翻案元は `../KsSettingsView/kasane/decisions/cross/` の 0019 単一バージョン・0020 手動起動と tag の後置・0030 PR 本文からのリリースノート (accepted で運用中 — 自リポジトリの ADR として判断する)。工程の実物と運用の経緯の調査は [artifacts/kssettingsview-release-research-2026-10-14.md](artifacts/kssettingsview-release-research-2026-10-14.md)。

### phase-7-1 から (2026-10-08、public-repo-verify-ci)

- [A4] 検証 CI の iOS / Android の検証は、入力を取らない再利用 workflow になっている (cross/ADR-0014)。リリースの workflow から同じ検証を呼べる。ただし iOS はビルドの確認だけで、テストは実行しない (cross/ADR-0013)。リリースの前に iOS のテストをどこで確かめるか (手元の完了判定に任せるか) を決める
- [B2] `main` の保護は、管理者には強制していない。管理者が迂回して `main` 宛ての Pull Request を進めてよい条件とやり方は、決まりが無い
- [B1] マージの後に `main` を `develop` へ取り込み直すかどうかは、決まりが無い (`main` の保護は、最新の取り込みを求めない設定)
- [B1] 「リリース候補にする節目」(いつ `develop` から `main` 宛ての Pull Request を出すか) の判断の基準は、決まりが無い
- [B3] secret の検査や push の保護が secret を検出したときにすること (値の無効化など) は、手順が無い
- [参考] `main` の workflow の時間の上限は暫定の値のまま (lint 10 分・iOS 40 分・Android 30 分)。決め直した値 (5 分・15 分・15 分) は `develop` にあり、次の `main` 宛ての Pull Request で入る

### phase-7-2 から (2026-10-09、package-distribution)

- [A2] 配信用リポジトリ `KsCollectionView-SPM` は、まだ無い。作成と設定 (Issue と Pull Request を閉じ、本リポジトリへ案内する)、写しを送って tag を付ける工程を、このフェーズで作る (cross/ADR-0015)
- [A2] 写しを作る道具 (`scripts/distribution/sync-spm-snapshot.py`) は git を操作せず、行き先には、まだ無いパス・空のディレクトリ・配信用リポジトリの作業コピーだけを受け付ける。commit・push・tag は、道具を呼ぶ側の工程が行う
- [A2] Android の公開の設定は入っている。足りないのは、実際に公開する workflow・署名の鍵の受け渡し・Maven Central への送信である
- [A2] 署名の鍵はプロパティで受け取り、無ければ署名を飛ばす。確かめた署名は、パスフレーズなしの使い捨ての鍵だけで、本番の形 (パスフレーズつき) は確かめていない。版が開発中の版のままだと、Maven Central へ送るタスクは最初に失敗する
- [A4] 利用者の立場の確認の再利用 workflow (`verify-consumer-ios.yml`・`verify-consumer-android.yml`) は、切り替えと版を入力に取る。リリースの workflow からは、公開済みの形で版を渡して呼べる (cross/ADR-0016)
- [A4] 公開済みの配布物の取得は、公開物が無いので確かめていない。最初のリリースで確かめる。リリースの workflow が作った成果物そのものを、公開の前に利用者役へ渡す形は、まだ無い
- [B2] 利用者の立場の確認は、外部の依存の取得 (Nuke・Maven の依存) に頼る。コードの誤りでない理由で `main` の必須の検査が止まり得る。phase-7-1 からの「管理者が迂回してよい条件」と一緒に決める
- [参考] 手順と値は handbook の `cross/package-distribution.md` (配布物を作る側) と `cross/consumer-build-check.md` (利用者役で確かめる側) にある

### phase-7-3 から (2026-10-10、user-docs)

- [A3] README と 4 つの `SKILL.md` は、最新の版の確かめ先を、本リポジトリの Release の一覧 (仮の値) にしている。Release をどこにどう作るかを決める。別の場所にするなら、例のある 6 つのファイルと、許可する URL の一覧 (`scripts/ci/user-docs-rules.json`) を直す
- [A3] 案内が効くように、Release を利用者に見える形で保つ決まりが要る (cross/ADR-0018 の負の帰結)。翻案元は、プレリリースの印を付けない決まりにしている
- [A4] README のインストールの節の「まだ公開していない」の 1 文を、初回のリリースのときに外す
- [A4] リリースの手順の中で、Skill の追従を確かめるかどうか (追従はオーナーが頼んだときにだけ行う決まりで、頼み忘れると古い Skill のままリリースされ得る。cross/ADR-0017)
- [A1] 本リポジトリと配信用リポジトリの、版の番号とタグの形の対応を決める。決まっていないので、Skill の導入の節に書けなかった
- [A4] 配信用リポジトリに置く README のひな形 (`scripts/distribution/spm-readme.template.md`) の案内が、ルートの README と食い違っていないかを確かめる
- [参考] 手順と決まりは handbook の `cross/user-skill-refresh.md` (追従の手順) と `cross/user-docs-writing.md` (Skill と README の書き方) にある

## ロードマップの外へ出したもの (2026-10-14)

初回リリースの基準と片付ける範囲は、オーナーの決定でこのロードマップの論点から外した (決定事項を参照)。外した項目と行き先:

| 外した項目 | 出どころ | 行き先 |
|---|---|---|
| 大量件数の性能検証をリリースの基準に含めるか (基準機 iPhone 11 の hitch・メモリの絶対値・推定高さの揺れ・Android の CI の実機の受け皿と相対基準の但し書き) | phase-2・phase-3 の申し送り | 簡易起票 `kasane/changes/deferred-verification-backlog/` |
| 実機の読み上げ (重ねた表示に隠れた項目・並べ替えの操作) と、iOS 16・17 での並べ替え | phase-5・phase-6 の申し送り | 同上 |
| コード縮小を有効にした Android の利用者役の起動を、節目ごとに確かめる決まり | phase-7-2 の申し送り | 同上 |
| Android Gradle Plugin と Kotlin の下限、Compose Foundation の届き方 | phase-7-3 の申し送り | 同上 |
| Skill のコード例の実行時の動き | phase-7-3 の申し送り | 同上 |
| 初回リリースまでに片付ける簡易起票 9 件 | 論点「初回リリースまでに片付ける範囲」・phase-7-2・phase-7-3 の申し送り | `kasane/changes/` にそのまま残る (下の一覧) |

簡易起票 9 件: `android-sample-status-bar-contrast` (直した後に README のスクリーンショットを撮り直す — 同 exploration.md に記載)・`image-fetch-concurrency-priority`・`ios-adaptive-color-settings-before-ios-18`・`ios-invalid-input-handling-gaps`・`ios-prefetched-cell-content-refresh`・`ios-pull-refresh-color-appearance-before-ios-18`・`ios-release-build-concurrency-warnings`・`ios-self-sizing-layout-loop`・`platform-placement-parity-check`。

## 決定事項

A1〜A4 と B1 は、オーナーの指示 (2026-10-14「以降の論点は兄弟ライブラリを踏襲するで決めてもらって OK」) で、兄弟ライブラリ KsSettingsView の形を踏襲して決めた。兄弟ライブラリと違う所は、各項目に理由を書いた。

### ロードマップの範囲

- グループ C (初回リリースの基準と片付ける範囲) を、このロードマップの論点から外す (オーナーの決定 2026-10-14)。行き先は「ロードマップの外へ出したもの」

### A1 版の付け方と tag の対応

- 両プラットフォームで 1 つの版にする (オーナーの決定)。tag は版の文字列そのもの (接頭辞なし) で、本リポジトリと配信用リポジトリに同じ文字列を付ける → [cross/ADR-0021](../../../../decisions/cross/0021-single-version-and-plain-tag-across-repositories.md)
- プレリリースの版は `X.Y.Z-alpha.N`・`-beta.N`・`-rc.N` の形にする。`-pre` と `-preview` は使わない (Maven の版の比較で、正式版より新しいと判定される)
- 初回の版は `0.1.0-beta.1` にする。兄弟ライブラリの初回と同じで、開発中の宣言 `0.1.0-SNAPSHOT` と系列が揃う

### A2 リリースの起動と公開の実行

- 起動のしかたと公開の順序は [cross/ADR-0022](../../../../decisions/cross/0022-manual-release-dispatch-reversible-steps-first.md)。兄弟ライブラリの NuGet と MAUI に当たる工程は持たない
- 起動の入力は、版と、公開しない試し (dry-run) の 2 つ。リリースは 1 本ずつ流し、同時に起動したものは待たせる
- secret は、`main` だけが使える Environment `release` にまとめる。署名の鍵・鍵の ID・パスフレーズ、Central Portal の利用者名とパスワード、配信用リポジトリへ書き込む deploy key の 6 つ
- 署名の鍵とパスフレーズは、環境変数でメモリの上で渡し、ファイルに書き出さない (本番の形のパスフレーズつきの鍵は、phase-7-2 では確かめていない)
- Maven は署名して組み立て直し、署名を検査してから保留で送る。保留の送信の ID は試行をまたいで引き継ぎ、失敗の経路では保留を取り下げる
- 公開を待つ上限は、30 分より長く取る (KsDialogs の初回は、Central の同期に約 60 分かかった)。値は提案で決める
- 配信用リポジトリの作成と設定 (Issue と Pull Request を閉じ、本リポジトリへ案内する)・deploy key・Environment・secret の登録は、初回だけの手動の手順として handbook に書く
- 初回の登録では、鍵を標準入力から流し、使ったファイルは `trash` で消す

### A3 リリースノートと Release

- ノートの材料は [cross/ADR-0023](../../../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md)
- Release の置き場所と印は [cross/ADR-0024](../../../../decisions/cross/0024-release-in-main-repository-marked-latest.md)
- 変更の節は `## Changes`。行は `- breaking|feature|fix|docs: 説明`、利用者向けの変更が無ければ `- none`。英語で書く (兄弟ライブラリと同じ)
- README と Skill の最新の版の確かめ先 (本リポジトリの Release の一覧) は、仮の値でなく確定になる。6 つのファイルと、許可する URL の一覧 (`scripts/ci/user-docs-rules.json`) は直さない
- 作成済みの Release は、再実行のときに飛ばし、本文を書き換えない

### リリースの Skill (A3 の補い)

兄弟ライブラリの `release` の Skill (`../KsSettingsView/.agents/skills/release/SKILL.md`) を読んで、中身も踏襲する (2026-10-14。オーナーの問い「リリーススキルの対応は含まれてたっけ?」から)。

- リリースの手順の正は handbook に置く。入口にプロジェクト内の専用の Skill を置き、Skill は起動のたびに handbook を先頭から読み、手順の写しを持たない
- Skill の置き方 (実体の置き場と、もう 1 つの CLI からのリンク) は、進行中の変更 `user-skill-refresh-skill` が追従の Skill で決める形に揃える
- Skill が自分で持つのは 3 つだけ: 変更の節の下書きの作り方、オーナーへの確認の境界、止まる条件
- 下書きの範囲は、その Pull Request が `main` へ新しく持ち込む commit だけ。利用者から見える変化だけを、利用者の言葉で 1 項目 1 行にする。確定するまで Pull Request の本文に書かない
- 確認は 1 回: 版と変更の節の文面をまとめて確かめる。確定したら以降の承認として扱い、Pull Request の作成とマージ・本番の起動・tag の作成まで止まらずに進める
- 止まるのは、検証や実行が失敗したとき・手順書に無い状況に当たったとき・確定した版や文面のままでは進めないとき。再実行するか、中止するかはオーナーが決める
- CI の完了は Skill が自分で見張る。Skill は自分からは起動せず、オーナーの明示の依頼から始める
- Pull Request のひな形 (`.github/pull_request_template.md`) を足し、変更の節の書き方を置く。本リポジトリには、まだひな形が無い

### A4 リリースの前後に確かめること

- iOS のテストは、リリースの手順に足さない。各変更の完了判定 (手元で 4 系統を全件) に任せ、リリースの workflow は検証 CI と同じ再利用 workflow を呼ぶ (cross/ADR-0013)
- 利用者役は 2 回呼ぶ。公開の前は、リリースの workflow が作った成果物を受け取って確かめ、公開の後は公開物を取得して確かめる。今の利用者役は成果物を受け取る形を持たないので、足す
- 事前の確認は 3 つ: `develop` の検証 CI が緑、push していない commit が無い、Skill の追従が要るか (前回追従した commit から変わった源泉があれば、追従するかをオーナーが決める)
- 公開の後の確認は 3 つ: 2 つの公開物 (配信用リポジトリの tag と Maven Central)、Release、最新の Release を指す URL
- 初回だけ: README 2 枚の「まだ公開していない」の 1 文を、リリースの Pull Request を出す前に `develop` で外す。リリースの工程は README を書き換えない (cross/ADR-0018)
- 初回だけ: 配信用リポジトリに置く README のひな形と、ルートの README の食い違いを、初回の前に確かめる

### B1 `main` 宛ての Pull Request の流れ

- リリース候補にする節目の基準は置かない。いつ `main` 宛ての Pull Request を出すかと、版の番号は、オーナーが決める (兄弟ライブラリも決まりを持たない)
- `main` 宛ての Pull Request は、リリースのとき以外にも出してよい。ノートは、前回の Release からの Pull Request をまとめる (cross/ADR-0023)
- マージの後に `main` を `develop` へ取り込み直さない。マージは merge commit だけなので、`develop` の履歴がそのまま `main` に入り、ノートの範囲も Release の tag で決まる
- 兄弟ライブラリの系列 (KsDialogs) で squash の後に起きた、前の版の項目がノートに重複して載る問題は、merge commit だけのマージでは起きない

### B2 管理者による保護の迂回

- 管理者も `main` の保護を迂回しない。外部の依存の取得で必須の検査が止まっても、失敗したジョブを再実行して、通るまで待つ (オーナーの決定 2026-10-14)
- 理由: リリースの workflow も、公開の前に同じ検証と利用者役の確認を流し、同じ外部の依存を取得する。迂回してもリリースは早まらず、得られるのは検査の通っていない commit が `main` に入ることだけ
- 保護の設定は今のまま (管理者に強制しない) にし、決まりは手順として handbook に書く

### B3 secret を検出したときの手順

- 値が GitHub に届いたかどうかで分ける (オーナーの決定 2026-10-14)
  - 届く前に止まった (commit の前の検査・push の保護が止めた): push していない手元の commit から値を除いて、やり直す。値の無効化はしない
  - 届いた後に見つかった (検証 CI の検査・GitHub の secret の検査が知らせた): すぐに値を無効化して作り直し、登録先の secret を差し替える。履歴は書き換えない
- 履歴を書き換えないのは、公開済みの写しや fork から値が消えず、`develop` の強制 push の禁止と、履歴をそのまま公開する決まり (cross/ADR-0009) にぶつかるため
- 誤検出 (テスト用の値など) の扱いは、提案で決める

## TODO

- [x] 翻案元 (KsSettingsView) のリリースの工程の調査 → [artifacts/kssettingsview-release-research-2026-10-14.md](artifacts/kssettingsview-release-research-2026-10-14.md)
- [x] 論点の数が分割の目安を超えたので、出口を判定する (ksn-split の判定: 分割せず、agenda を整理)
- [x] A1〜A4・B1 を決める (兄弟ライブラリの踏襲)。ADR cross/0021〜0024 を proposed で起票
- [x] B2 を決める
- [x] B3 を決める
- [x] ksn-propose で変更提案を起こす (変更 release-pipeline)

## 実装結果 (2026-10-15 反映)

変更 `release-pipeline` で実装し、初回の版 `0.1.0-beta.1` を公開した。記録は `kasane/changes/archive/2026-10-15-release-pipeline/` にある。

- リリースの workflow (`.github/workflows/release.yml`) と道具 (`scripts/release/`) を足した。版を入力して `main` から手動で起動し、公開しない試しも選べる。取り消せる操作から公開し、同じ版で再実行できる
- 利用者役に、工程の成果物を受け取る切り替え `artifact` を足した。公開の前は工程の成果物で、公開の後は公開物で確かめる
- `main` 宛ての Pull Request のひな形を足し、変更の節 (`## Changes`) からリリースノートを組み立てる。#1・#2 の本文にも変更の節を書き足した
- リリースの入口の Skill (`.agents/skills/release/`) を置いた。手順の正は handbook の `cross/release-procedure.md` で、Skill は起動のたびに読む
- 配信用リポジトリ `KsCollectionView-SPM`・書き込み用の deploy key・Environment `release` (`main` だけ)・secret 6 つを用意した
- 初回の本番は、署名の鍵に公開鍵が登録されていて署名の段で止まり、登録し直して失敗したジョブの再実行で公開まで揃った (取り消せない操作の前に止まったので、外に残ったのは tag の無い写しだけだった)。所要は公開のジョブが約 9 分
- 版と tag・起動と公開の順序・リリースノートの材料・Release の置き場所と印は、cross/ADR-0021〜0024 として確定した
- 手順と決まりは handbook の `cross/release-procedure.md` (新設)・`cross/secret-handling.md` (新設)・`cross/branch-and-github-settings.md` (`main` の運用とリリースのための設定) にある

### 決定事項から形が変わった点

- リリースの Skill の事前の確認で、対象の commit に検証 CI の記録が無いとき (開発の記録だけを変えた push の先端) は、直近の成功の commit からの変更が検証 CI を起動しないパスだけなら、その成功で代える (オーナーの決定)
- 検証 CI の push の run で、Android の画像のテスト 1 件がランナーの上でだけ落ちた。別の変更 `android-prefetch-failure-test-on-ci` でテストの確かめ方を直して取り込んだ (製品のコードは変えていない)

### 申し送り

| 項目 | 受け皿 |
|---|---|
| リリースの Skill は、実物ではまだ使っていない (初回は手順の草稿で行った)。2 回目のリリースが最初の実地になる | `deferred-verification-backlog` の exploration.md (2026-10-15 追記) |
| 共同作業者でない人が配信用リポジトリに Issue・Pull Request を作れないこと、`develop` からのジョブが Environment の保護で止まることは、設定の値で確かめただけで、実地では確かめていない | `deferred-verification-backlog` の exploration.md (同上) |
| secret の検査 (gitleaks) の指紋の形が、commit の前と検証 CI で違う見込み。最初の本物の誤検出で確かめる | `deferred-verification-backlog` の exploration.md (同上) |
| commit の前の検査の案内 (`.githooks/pre-commit`) が、誤検出の扱いの決まり (書き換えを先にし、除外は指紋を理由つきで足す) と食い違う | 見送り (オーナーの決定 2026-10-15)。hook はハーネス Kasane が配る標準の装備のため、このリポジトリでは直さない。決まりは handbook の `cross/secret-handling.md` が hook の案内より優先すると書いた |
| handbook の `cross/branch-and-github-settings.md` ほか 3 枚の散文が、構造 lint の 1 ファイルの目安 (10,000 字) を超えている (違反ではなく注意) | 見送り。分けるかは次に大きく書き換えるとき、または ksn-drift の棚卸しで決める |

