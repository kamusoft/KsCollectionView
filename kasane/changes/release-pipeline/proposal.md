# Proposal: release-pipeline

## Why

配布物の形 (SwiftPM の写しと、Android の Maven の発行物) と、それを利用者の立場で確かめる仕組みはできた (変更 `package-distribution`)。しかし、実際に公開する工程が無い。配信用リポジトリ `KsCollectionView-SPM` はまだ無く、Maven Central へ送る workflow も、署名の鍵の受け渡しも無い。README と利用者向け Skill は、最新の版の確かめ先として本リポジトリの Release の一覧を案内しているが、Release は 1 つも無い。

`main` の運用にも決まりが足りない。リリース候補にする節目、管理者が保護を迂回してよいか、マージの後に `main` を `develop` へ取り込み直すか、secret を検出したときにすることが、決まっていない。

フェーズの議論で、兄弟ライブラリ KsSettingsView の形を踏襲して、版と tag の付け方 (cross/ADR-0021)、リリースの起動と公開の順序 (cross/ADR-0022)、リリースノートの材料 (cross/ADR-0023)、Release の置き場所と印 (cross/ADR-0024)、`main` の運用の決まりを決めた。本変更は、その決定を実物にし、初回の版 `0.1.0-beta.1` を公開する。

## What Changes

- **リリースの workflow**: 版を入力して手動で起動する workflow を足す。公開しない試し (dry-run) も選べる。本番は `main` からだけ起動でき、1 本ずつ流れる
  - 最初に、入力の版の形・起動したブランチ・両リポジトリの tag の状態を確かめ、リリースノートを組み立てる
  - 公開の前に、検証 CI と同じ検証を通し、配布物 (SwiftPM の写しと、署名した Maven の発行物) を組み立て、その成果物を使う利用者役の確認を通す
  - 公開は取り消せる操作から進める: 配信用リポジトリへ写しを push (tag なし) → Maven Central へ保留で送る → 検証の決着を待つ → 公開して、取得できるまで待つ → 配信用リポジトリの tag → 本リポジトリの tag → Release
  - 公開の後に、公開物を取得する利用者役の確認を通す
  - 同じ版で再実行できる。tag や公開済みの配布物が起動した commit のものなら続け、別の commit のものなら止める (Android の発行物に元の commit を書いておき、照合する)。保留の送信の控えは試行をまたいで引き継ぎ、送信の状態を照会して扱う
  - secret は `main` だけが使える Environment にまとめ、署名の鍵はメモリの上で渡す
- **リリースの道具**: workflow が呼ぶスクリプトを `scripts/release/` に足し、スクリプトのテストに入れる (版と tag の検査・リリースノートの収集と検査と組み立て・Central Portal の API の操作・署名と中身の検査・公開を待つ処理)。公開のプラグインには、保留の送信を後から公開するタスクが無いので、そこは API を直に呼ぶ
- **workflow の定義の検査**: 権限の決まりに、リリースの workflow の公開のジョブだけが書き込みを持ってよい例外を足し、リリースの workflow の定義 (起動・環境・公開の step の順) をテストで検査する
- **リリースノートの材料**: `main` 宛ての Pull Request のひな形を足し、変更の節 (`## Changes`) の書き方を置く。節は必須で、欠けていたり読めない行があればリリースを止める
- **利用者役**: リリースの工程が作った成果物を受け取ってビルドする形を足す (今は、手元で作るか、公開済みのものを取るかの 2 つ)
- **リリースの Skill**: プロジェクト内に、リリースの入口になる専用の Skill を置く。手順の正は handbook で、Skill は起動のたびにそれを読み、写しを持たない。Skill が自分で持つのは、変更の節の下書きの作り方・確認を版と文面の 1 回にまとめる境界・止まる条件の 3 つ
- **配信用リポジトリと GitHub の設定**: `KsCollectionView-SPM` を作り、Issue と Pull Request を閉じて本リポジトリへ案内する。書き込み用の deploy key と、リリース用の Environment を作る
  - GitHub への操作は外向きなので、オーナーの承認を得てから行い、実行したコマンドと読み直した設定を証跡に残す
  - secret の値 (署名の鍵・パスフレーズ・Central Portal の認証の情報・deploy key の秘密鍵) は、オーナーが登録する
- **通しの確認**: 公開しない試しで、公開の直前までを通す
- **初回のリリース**: `0.1.0-beta.1` を公開し、公開の後の確認まで通す。公開は取り消せないので、起動の前にオーナーの承認を得る
  - 手動で起動する workflow は既定のブランチ (`main`) にファイルが要るので、先に準備の Pull Request で `main` に入れる
  - 前もって、README 2 枚の「まだ公開していない」の 1 文を外す
  - 配信用 README のひな形が、ルートの README と食い違っていないかを確かめる

影響する能力: release-workflow (新規。リリースの起動・公開の順序・再実行) / release-notes (新規。変更の節の書き方と組み立て) / release-skill (新規。リリースの入口の Skill) / consumer-verification (工程の成果物を受け取る形が増える) / verification-ci (権限の例外と、リリースの workflow の定義の検査) / repository-publication (配信用リポジトリ・Environment) / user-readme (「まだ公開していない」の 1 文を外す)

- 蒸留時に反映: decisions — cross/ADR-0021〜0024 を、実装の形で確かめて accepted に昇格する
- 蒸留時に反映: handbook — cross にリリースの手順の文書を新設する (毎回の手順・初回だけの手順・失敗したときのやり直し・リリースの前後に確かめること)。リリースの Skill が読む手順の正になる
- 蒸留時に反映: handbook — `kasane/handbook/cross/branch-and-github-settings.md` に、`main` の運用の決まり (節目の基準を置かない・管理者も迂回しない・`main` を `develop` へ取り込み直さない)、secret を検出したときの手順、配信用リポジトリと Environment の設定を足す
- 蒸留時に反映: handbook — `kasane/handbook/cross/verification-ci.md`・`consumer-build-check.md`・`package-distribution.md` に、リリースの workflow からの呼ばれ方・工程の成果物を受け取る形・公開する工程の所在を足す
- 蒸留時に反映: handbook — `kasane/handbook/cross/user-skill-refresh.md` に、リリースの事前の確認で追従の要否を見ることを足す

## Non-Goals

- **初回リリースの基準と、片付ける範囲 (性能の再検証・実機の読み上げ・iOS 16 と 17・簡易起票 9 件)** — オーナーの決定でロードマップの外へ出した (確かめていないことは簡易起票 `deferred-verification-backlog`)
- **iOS のテストをリリースの workflow で走らせること** — cross/ADR-0013 で検証 CI では走らせないと決めていて、各変更の完了判定に任せる (フェーズの決定)
- **README と Skill の版を書き換える仕組み** — cross/ADR-0018 で持たないと決めている
- **配信用リポジトリに Release を作ること** — cross/ADR-0024 で本リポジトリにだけ作ると決めた
- **管理者が保護を迂回する仕組み** — フェーズの決定で、管理者も迂回しない
- **専用の Skill の置き方そのもの (実体の置き場・もう 1 つの CLI からのリンク・AGENTS.md の宣言)** — 進行中の変更 `user-skill-refresh-skill` が追従の Skill で決める。本変更はその形に揃える
- **NuGet と MAUI の公開** — cross/ADR-0001 で MAUI に対応しない

## Impact

- 破壊的変更: 公開 API とライブラリの挙動は変えない。README から「まだ公開していない」の 1 文が消える
- 外へ公開する: Maven Central への公開は取り消せない。配信用リポジトリの tag と Release は利用者に見える
- secret が 6 つ増え、本リポジトリの Environment に置かれる。漏れたときの手順は handbook に置く
- リリースのたびに、macOS のランナーを使うジョブが 3 本走る (iOS の検証・公開の前と後の iOS の利用者役)
- リスク: Maven Central の検証の決着と同期にかかる時間、tag を付けた写しを SwiftPM が解決できること、プレリリースの印の無い Release が最新に選ばれることは、実物で確かめるしかない。公開しない試しと初回のリリースで確かめ、初回で失敗したら直して同じ版で再実行する
- リスク: 進行中の変更 `user-skill-refresh-skill` と、触るファイル (AGENTS.md・Skill の置き場・`kasane/decisions/cross/index.md`) が重なる。ADR の番号はすでに一度重なり、本変更の側を付け直した
- 依存: リリースの Skill の置き方は `user-skill-refresh-skill` の結論に従う。その変更が先に終わっていなければ、リリースの Skill のタスクはそれを待つ

## 級: L

外部への取り消せない公開・secret の受け渡し・GitHub の設定の変更があり、能力が 7 つにまたがるため。

domain: cross
roadmap: v1-foundation/phase-7-4-release-pipeline
