# 配布物の形 (SPM / Maven)

SPM と Maven の配布物の形を決め、公開物を利用者の立場でビルドして確かめる。

## 論点

(残りなし。2026-10-09 にすべて決定事項へ移した)

## 決定事項

### SwiftPM をどこから配るか (2026-10-09)

- SwiftPM の配布物は、配信用の公開リポジトリ `KsCollectionView-SPM` に `ios/` の本体の写しを置いて配る ([cross/ADR-0015](../../../../decisions/cross/0015-swiftpm-via-distribution-repository.md)、proposed)
- このリポジトリのルートにはマニフェストを置かず、`ios/Package.swift` をただ 1 枚のマニフェストとして、書き換えずに写す (cross/ADR-0002 のまま)
- 配信用リポジトリは Issue と Pull Request を受けず、このリポジトリへ案内する。写しはリリースのたびに CI が送り、手では commit しない
- Android は Maven Central から配る (cross/ADR-0003 が前提にしている。議論側の既定)

### 配布物の中身 (2026-10-09、議論側の既定)

iOS の写しと Android の発行物は、兄弟ライブラリと同じ形を既定にする。

| 対象 | 既定 |
|---|---|
| iOS の写しに入れるもの | `ios/Package.swift`・`ios/Sources/`・`ios/Tests/`・ルートの `LICENSE`・配信用の README (このリポジトリへ案内する固定文) の 5 点。Sample・開発の記録・Android は入れない |
| iOS のマニフェスト | 書き換えない。テストの定義が残るので、テストのソースも写す。依存の解決結果のファイルは入れない |
| 写しを作る道具 | git を操作しない。commit・push・tag はリリースの workflow の側で行う (phase-7-4) |
| Android の公開の設定 | 兄弟と同じプラグイン (`com.vanniktech.maven.publish`) を使う |
| Android の発行物 | release の 1 種類。sources jar を付け、javadoc jar は空で置く |
| POM | 名前・説明・URL・ライセンス (MIT)・開発者 (名義は `kamusoft`)・リポジトリの場所 |
| 署名 | 鍵を環境変数で受け取り、鍵が無ければ署名を飛ばす (手元と、利用者の立場の確認で使うため) |
| 開発中の版の歯止め | 版が `-SNAPSHOT` のときは、Maven Central 向けのタスクを失敗させる |
| 利用者向けの R8 の規則 | 同梱しない (名前から引くクラスは見当たらない)。コード縮小を有効にしたアプリで動くかは、確かめる範囲の論点 (2-b) で扱う |

### 対応する Xcode の宣言と案内 (2026-10-09)

- マニフェスト (`ios/Package.swift`) の宣言を、確かめている版に合わせて Swift 6.4 のツールに上げる。対応する Xcode は 27 以上と案内する
- Xcode 26 でのビルドは確かめない (phase-7-1 の決定のまま)。宣言を下げるのは、その版でのビルドを確かめたときに限る
- README の「必要な環境」の文面は phase-7-3-user-docs で書く
- ADR にはしていない (宣言は設定で、下げる向きの変更は利用者を壊さない)。「宣言を、確かめている版に合わせる」ことは、提案のときに規約 (handbook) の候補として扱う

### 利用者の立場のビルドの確認の形 (2026-10-09)

- 専用の小さな利用者役を `verification/` に置く (iOS・Android のそれぞれに最小のプロジェクト)。Sample は利用者役に使わず、ソースを参照する今の形のままにする
- 利用者役は、利用者と同じ書き方 (package の名前 `KsCollectionView-SPM`、Maven の座標 1 行) で公開前の成果物を参照する。iOS は写しのディレクトリ、Android は手元の Maven リポジトリに発行したものを使う
- 公開済みのものを取りに行く形でも、同じ利用者役を使えるようにする (呼ぶ側のリリースの workflow は phase-7-4)
- 利用者役のソースは、最小の利用例として書く。README の例と一致させる検査は phase-7-3-user-docs に申し送る

### 利用者役で確かめる範囲 (2026-10-09)

- 利用者役はビルドまでを確かめ、起動はしない (CI で Simulator・エミュレータを使わない cross/ADR-0013 のまま)
- Android の利用者役は、コード縮小 (R8) を有効にして、リリース用に組み立てる。iOS はコード縮小が無いので、利用者役をビルドするまでとする
- コード縮小を有効にした利用者役の起動は、今回の変更の実装のときに、手元で 1 回確かめる (議論側の既定)。節目ごとに確かめるかは、リリースの基準の議論 (phase-7-4) で扱える

### 必須の検査に足すか (2026-10-09)

- 利用者の立場のビルドの確認は、`main` 宛ての Pull Request のときだけ走らせ、`main` の必須の検査にする。`develop` への push では走らせない
- 確認の形・確かめる範囲・走らせる時点は、1 つの決定として [cross/ADR-0016](../../../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) (proposed) に残した
- 検査の名前は、兄弟と同じ `consumer-ios / verify`・`consumer-android / verify` にする (議論側の既定)。iOS と Android を別の再利用 workflow にして、検証 CI の入口から呼ぶ (cross/ADR-0014 の形)
- リリースの workflow から同じ確認を呼ぶこと (公開の前と後) は、phase-7-4 で扱う

### 申し送りへの答え (2026-10-09)

| 申し送り | 答え |
|---|---|
| phase-3: maven-publish の設定を基盤では行っていない | 「配布物の中身」の既定のとおり、公開の設定を足す |
| phase-7-1: 利用者の立場の確認は再利用 workflow として足せる。必須にするなら保護にも登録する | 「必須の検査に足すか」のとおり |
| phase-7-1: ビルドまでにするか、実行まで確かめるか | 「利用者役で確かめる範囲」のとおり、ビルドまで |
| phase-7-1: 対応する Xcode の案内の書き方 | 「対応する Xcode の宣言と案内」のとおり |

## TODO

- [x] 論点の解消
- [ ] 公開のプラグインが、このリポジトリの AGP 9 系・Gradle 9.7 で動くかを提案のときに確かめる (兄弟は AGP 8 系・Gradle 9.5)。動かなければ、代わりの道具を提案で選ぶ
- [ ] 公開 API に現れる型の依存の `api` の宣言に過不足が無いかを、提案のときに確かめる (兄弟は 2 件漏れていた)
- [ ] 配信用リポジトリ `KsCollectionView-SPM` を作る時点と、置く設定 (Issue と Pull Request を閉じる) を提案で決める
- [ ] マニフェストの宣言を上げた後に、iOS の 2 系統のテストを手元で流し直すことを提案に含める
- [ ] 利用者役の準備が失敗したときに、理由が CI の記録に残る形にすることを提案に含める (兄弟が後から直した点)
- [ ] コード縮小を有効にした利用者役を、手元で 1 回起動して確かめることを提案に含める
- [ ] iOS の利用者役のビルドの構成と行き先 (Simulator 向け・実機向け) を提案で決める。実機向けのビルドは、今どの検査も確かめていない
- [ ] 必須の検査の名前を `main` の保護に登録する時点と手順を、提案に含める (handbook の検証 CI とブランチの設定の文書への追記も)
- [ ] ksn-propose で変更提案を起こす

## 実装結果 (2026-10-09 反映)

変更 `package-distribution` で実装し、`main` に入れた。記録は `kasane/changes/archive/2026-10-09-package-distribution/` にある。

- `ios/Package.swift` の宣言を Swift 6.4 に上げた。iOS の 2 系統のテストは、上げた後も全件通った
- SwiftPM の写しを作る道具 (`scripts/distribution/sync-spm-snapshot.py`) を足した。行き先を写しの 5 点に置き換え、git を操作しない。配信用リポジトリの作業コピーを壊さないための確認は、相方レビューの指摘で 2 回足した
- Android の本体のモジュールに、Maven の発行の設定を足した。公開のプラグインは、このリポジトリの AGP 9 系・Gradle 9.7 で動いた。開発中の版のままでは、Maven Central へ送るタスクが最初に失敗する
- 公開 API に現れる型の依存の宣言は、決定事項「配布物の中身」から 1 点だけ形が変わった。注釈の依存 (`androidx.annotation`) は兄弟ライブラリに揃えて直接宣言し、色と長さの型を持つ成果物は Compose UI が届ける形のままにした (オーナーの決定。変更の deviation に記録)
- 利用者役を `verification/` に置き、確認のスクリプトで、公開の前の成果物と公開済みの配布物を切り替えてビルドできるようにした。iOS は Simulator 向けと実機向け、Android はコード縮小を有効にしたリリースを組み立てる
- コード縮小は、配布物にも利用者役にも規則を足さずに通った。手元で 1 回起動して、一覧が表示されることを確かめた
- 再利用 workflow を 2 本足し、`main` 宛ての Pull Request のときだけ走らせる。`main` の必須の検査は 3 つから 5 つになった。Pull Request 2 番で 5 つとも成功し、merge commit で `main` に入った
- SwiftPM の置き場所と、利用者役で確かめる形は、cross/ADR-0015・0016 として確定した
- 手順と値は handbook の `cross/package-distribution.md`・`cross/consumer-build-check.md`・`cross/verification-ci.md`・`cross/branch-and-github-settings.md`・`cross/public-identifiers.md` にある

### 申し送り

| 項目 | 受け皿 |
|---|---|
| 配信用リポジトリ `KsCollectionView-SPM` の作成と設定 (Issue と Pull Request を閉じる)、写しを送って tag を付ける工程 | phase-7-4-release-pipeline の agenda (phase-7-2 からの申し送り) |
| 実際に公開する workflow・署名の鍵の受け渡し・Maven Central への送信。本番の形の署名 (パスフレーズつきの鍵) は確かめていない | phase-7-4-release-pipeline の agenda (同上) |
| リリースの workflow から、利用者の立場の確認を公開済みの形で呼ぶこと。公開済みの配布物の取得は、公開物が無いので確かめていない | phase-7-4-release-pipeline の agenda (同上) |
| コード縮小を有効にした利用者役の起動を、リリースの節目ごとに確かめる決まりにするか | phase-7-4-release-pipeline の agenda (同上) |
| 利用者の立場の確認は外部の依存の取得に頼るので、コードの誤りでない理由で必須の検査が止まり得る | phase-7-4-release-pipeline の agenda (同上。管理者が保護を迂回してよい条件の論点に合流) |
| 本体をリリースの構成でビルドすると、並行性の警告が 2 か所で出る (簡易起票 `ios-release-build-concurrency-warnings`) | phase-7-4-release-pipeline の agenda (同上。初回リリースまでに片付ける範囲の論点に合流) |
| README のインストール例 (Package URL・package の名前 `KsCollectionView-SPM`・Maven の座標)、Xcode 27 以上が要ることの案内、利用者役のソースを README の例と一致させる検査 | phase-7-3-user-docs の agenda (phase-7-2 からの申し送り) |
| 写しを作る道具は、通常の clone・worktree でない作業コピー (オブジェクトの借用先が行き先の中にあるなど) までは確かめない | 見送り。通常の clone では起きず、取り直せば戻せる。道具の説明と handbook の `cross/package-distribution.md` に書いた |
| 保存した Gradle のキャッシュが次の実行で復元されること、Android SDK を取得する枝は、確かめていない | 見送り。次の `main` 宛ての Pull Request で分かる。handbook の `cross/consumer-build-check.md` に書いた |
| 新しい 2 本の workflow の時間の上限は、15 分のまま (実測は 1 回だけ) | 見送り。実測が上限に近づいたら見直す。handbook の `cross/consumer-build-check.md` に書いた |
| 識別の lint が、Maven の発行先の指定の名前と SSH の形の GitHub の URL を誤検出する。許可に足す行そのものが書き込みの hook に止まる | 見送り。文書は名前をぼかして書いた。オーナーが `kasane/config.yaml` の許可を直せば、書き直せる |

