# KsCollectionView Skills

KsCollectionView (iOS の SwiftUI と Android の Jetpack Compose 向けの、リストとグリッドのライブラリ) でリストやグリッドの画面を作るための Agent Skill です。Skill は、コーディングエージェントが読む Markdown のファイルを収めたディレクトリで、機能ごとに、できること、動くコード、守る約束ごとを書いています。Skill は英語版と日本語版を用意しています。このページは、日本語版の一覧です ([English index: README.md](README.md))。

## Skill の一覧

| 名前 | 対象 | 扱う内容 | Skill |
|---|---|---|---|
| `kscollectionview-ios` | iOS (Swift・SwiftUI) | 配列をリストやグリッドとして表示する、項目の種類ごとのテンプレート、グループと固定見出し、ページングと Pull to Refresh、ドラッグ & ドロップの並べ替え、画像の先読みと画像のキャッシュ、タップ、コードからのスクロール。 | [ja/kscollectionview-ios](ja/kscollectionview-ios/SKILL.md) |
| `kscollectionview-android` | Android (Kotlin・Jetpack Compose) | 同じ機能を、Compose 版のライブラリについて扱います。1 つの Composable の名前付き引数で、layout・グループ・ページングと Pull to Refresh・並べ替え・画像の先読みと画像のキャッシュ・タップ・コードからのスクロールを指定します。 | [ja/kscollectionview-android](ja/kscollectionview-android/SKILL.md) |

どの Skill も、同じ 6 つのファイルを持ちます。`SKILL.md` (ライブラリが何か、導入、最小の動く例、残りのページへの案内) と、`references/` の下の 5 枚 (`basics.md`・`layout.md`・`paging.md`・`reorder.md`・`images.md`) です。2 つの Skill は、2 つのプラットフォームのライブラリを別々に説明しています。作るプラットフォームのものをコピーしてください。両方のアプリを持つプロジェクトでは、両方をコピーします。

## 導入の手順

**1. このリポジトリを手元に取得します。** 自分のプロジェクトの外の、任意の場所へ clone します (GitHub から ZIP をダウンロードして展開し、`KSCV` に展開先のディレクトリを設定しても構いません)。

```bash
git clone https://github.com/kamusoft/KsCollectionView
KSCV="$PWD/KsCollectionView"
```

これで `KSCV` に clone 先のパスが入ります。この後のコピーのコマンドはこれを読むので、同じシェルのセッションで続けて実行してください。

**2. 使う Skill のディレクトリを、自分のプロジェクトへコピーします。** `<your-project-root>` は自分のプロジェクトのルートに、`<skill-name>` は上の表の名前 (たとえば `kscollectionview-ios`) に置き換えます。複数の Skill を入れるときは、`cp` の行を Skill の数だけ繰り返します。

使っているエージェントのツールが `.agents/skills/` から Skill を読むなら、そこへコピーします。

```bash
cd <your-project-root>
mkdir -p .agents/skills
cp -R "$KSCV/skills/ja/<skill-name>" .agents/skills/
```

Claude Code を使うなら、Claude Code が Skill を読む `.claude/skills/` へコピーします。

```bash
cd <your-project-root>
mkdir -p .claude/skills
cp -R "$KSCV/skills/ja/<skill-name>" .claude/skills/
```

ファイルを 1 つずつではなく、ディレクトリごとコピーしてください。Skill は `SKILL.md` と `references/` の組で、コピーしたディレクトリだけで完結します。中の文書に、ディレクトリの外を指すリンクはありません。ほかのエージェントのツールを使うときは、そのツールが Skill を読む場所へ、同じディレクトリをコピーします。

**3. エージェントを開き直します** (新しいセッションを始めても構いません)。動いているセッションは、コピーした Skill を読み込みません。

## 片方の言語だけを使う

それぞれの Skill は、**どちらか一方**の言語のツリーからだけコピーしてください。`en/` と `ja/` は同じ内容を 2 つの言語で書いたもので、`name` もコード例も同じです。両方をコピーすると、同じ名前の Skill が 1 つのプロジェクトに 2 つ入ります。英語版を使うときは、上のコピーのコマンドの `ja` を `en` に置き換えます。英語版の一覧は [README.md](README.md) にあります。
