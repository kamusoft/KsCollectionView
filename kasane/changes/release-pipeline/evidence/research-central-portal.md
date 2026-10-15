# 調査: 公開のプラグインと Central Portal の挙動 (tasks 1.1)

調べた日: 2026-10-15 / 調べ方: vanniktech `gradle-maven-publish-plugin` の 0.37.0 の tag のソース (jar のクラスの一覧と照合) と、Central Portal の公式の文書・OpenAPI の定義 (`https://central.sonatype.com/swagger.json`) を読んだ。ソースの位置は、プラグインのリポジトリ相対で書く。

| 項目 | 結論 | 根拠 | 自信度 |
|---|---|---|---|
| `publishToMavenCentral` は決着を待つか | 自動で公開しない設定 (既定) では待たない。送った直後に「Skipping deployment validation!」を出して終わる。待つのは自動で公開する設定のときだけ (`VALIDATED` か `PUBLISHED` まで、上限は既定 15 分) | `plugin/.../central/MavenCentralBuildService.kt:95-99, 152-188`・`central-portal/.../SonatypeCentralPortal.kt:95-173` | 高 |
| 送信はいつ行われるか | ビルドの終わりに、BuildService の `close()` の中で送る | `MavenCentralBuildService.kt` | 高 |
| 自動で公開する設定の既定 | Gradle のプロパティ `mavenCentralAutomaticPublishing` → 環境変数 `SONATYPE_AUTOMATIC_RELEASE` → 無ければ false。false なら `publishingType=USER_MANAGED` (保留) で送る。`publishAndReleaseToMavenCentral` は設定によらず自動で公開する | `MavenPublishBaseExtension.kt:105-173`・`Properties.kt` | 高 |
| 送信の ID の取り出し方 | ファイルには書かない。ログに lifecycle の水準 (既定で表示) で `Uploaded bundle to Central Portal as USER_MANAGED, deployment id: <UUID>` を出す。送信の名前は、座標が 1 つなら `<group>-<artifactId>-<version>` | `MavenCentralBuildService.kt:141-150, 181` | 高 |
| 認証 | user token の `ユーザー名:パスワード` を Base64 にし、`Authorization: Bearer <b64>`。Gradle の `mavenCentralUsername`・`mavenCentralPassword` と同じ user token | publish-portal-api・`SonatypeCentralPortalOkHttpInterceptor.kt` | 高 |
| 状態の照会 | `POST /api/v1/publisher/status?id=<ID>` (GET ではない)。200 で `{deploymentId, deploymentName, deploymentState, purls, errors}`。ID が無いと 404 | swagger.json | 高 |
| 公開の指示 | `POST /api/v1/publisher/deployment/{id}`。204。対象は `VALIDATED` (USER_MANAGED) | swagger.json・publish-portal-api | 高 |
| 取り下げ | `DELETE /api/v1/publisher/deployment/{id}`。204。`VALIDATED` か `FAILED` のときだけ受け付ける | swagger.json・publish-portal-api | 高 |
| 一覧 | `GET /api/v1/publisher/deployments?namespace=&deploymentName=&deploymentState=&page=&size=&sortField=&sortDirection=` (swagger にだけ載っていて、文書のページには無い) | swagger.json | 高 |
| 状態の値 | `PENDING`・`VALIDATING`・`VALIDATED`・`PUBLISHING`・`PUBLISHED`・`FAILED` の 6 つ | 文書・プラグインの enum | 高 |
| 公開済みの判定 | `GET /api/v1/publisher/published?namespace=jp.kamusoft&name=<artifactId>&version=<版>` (認証が要る。無いと 401) が `{"published": true|false}` を返す。認証なしなら `https://repo1.maven.org/maven2/jp/kamusoft/<artifactId>/<版>/<artifactId>-<版>.pom` の 200 / 404 で見られる | swagger.json・実地で 401 を確認 | API は高。repo1 の反映の遅れは中 (確かめていない) |
| POM の `scm` の tag | Gradle 標準の `MavenPomScm` に `tag: Property<String>` がある。`pom { scm { tag.set(providers.gradleProperty("<名前>")) } }` の形で `-P` から受け取れる。vanniktech のプロパティ (`POM_SCM_*`) に tag は無い | javap で確認・`MavenPublishBaseExtension.kt:386-393` | 高 |
| 名前空間 `jp.kamusoft` | Central Portal で検証済みにしておく必要がある (ドメイン `kamusoft.jp` の DNS の TXT レコードで検証)。検証済みかどうかは確かめていない (tasks 1.3 でオーナーに確かめてもらう) | central.sonatype.org/register/namespace | 高 |

## 実装への影響

- workflow で `mavenCentralAutomaticPublishing` を渡さない (渡すと送った後に自動で公開される)。リリースの workflow の定義の検査で、この名前が `release.yml` に現れないことを確かめる
- 決着の待ちと公開の指示は、計画どおり `scripts/release/central-portal.py` が受け持つ (プラグインは待たない)
- 公開済みの判定は、secret を持たない validate では repo1 の POM を、secret を持つ publish では Publisher API の `published` を使う (決定は deviation.md)
