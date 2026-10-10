# KsCollectionView Skills

Agent Skills for building list and grid screens with KsCollectionView, the list and grid library for SwiftUI on iOS and Jetpack Compose on Android. A Skill is a directory of Markdown files that a coding agent reads: what each feature does, working code for it, and the rules to follow. The Skills are published in English and Japanese; this page lists the English editions ([日本語版の索引: README_ja.md](README_ja.md)).

## Skills

| Name | For | What it covers | Skill |
|---|---|---|---|
| `kscollectionview-ios` | iOS (Swift, SwiftUI) | Showing an array as a list or a grid, templates by item type, grouping with pinned group headers, paging and pull to refresh, drag-and-drop reordering, image prefetching and the image cache, taps, and programmatic scrolling. | [en/kscollectionview-ios](en/kscollectionview-ios/SKILL.md) |
| `kscollectionview-android` | Android (Kotlin, Jetpack Compose) | The same features for the Compose library: one composable with named arguments for layout, grouping, paging and pull to refresh, reordering, image prefetching and the image cache, taps, and programmatic scrolling. | [en/kscollectionview-android](en/kscollectionview-android/SKILL.md) |

Each Skill has the same six files: `SKILL.md` (what the library is, setup, a minimal working example, and a map of the rest) and five pages under `references/` (`basics.md`, `layout.md`, `paging.md`, `reorder.md`, `images.md`). The two Skills describe the two platform libraries separately. Copy the one for the platform you build for, or both if your project has both apps.

## How to install

**1. Get a copy of this repository.** Clone it anywhere outside your own project (or download the ZIP from GitHub and unpack it, then set `KSCV` to the unpacked directory):

```bash
git clone https://github.com/kamusoft/KsCollectionView
KSCV="$PWD/KsCollectionView"
```

`KSCV` now holds the path to the clone, and the copy commands below read it, so run them in the same shell session.

**2. Copy the Skill directories you want into your own project.** Replace `<your-project-root>` with the root of your project and `<skill-name>` with a name from the table above (for example `kscollectionview-ios`). Repeat the `cp` line for each Skill you want.

If your agent tool reads Skills from `.agents/skills/`, copy them there:

```bash
cd <your-project-root>
mkdir -p .agents/skills
cp -R "$KSCV/skills/en/<skill-name>" .agents/skills/
```

If you use Claude Code, copy them to `.claude/skills/` instead, which is where it reads Skills from:

```bash
cd <your-project-root>
mkdir -p .claude/skills
cp -R "$KSCV/skills/en/<skill-name>" .claude/skills/
```

Copy the whole directory, not single files. A Skill is `SKILL.md` plus its `references/`, and the copied directory is self-contained: its documents hold no links that point outside it. For another agent tool, copy the directory to wherever that tool reads Skills from.

**3. Restart your agent** (or start a new session) so that it picks up the copied Skills. A running session does not see them.

## One language only

Copy each Skill from **one** language tree only. `en/` and `ja/` hold the same content in two languages, with the same `name` and the same code examples, so copying both puts two Skills with the same name into one project. To use the Japanese editions, replace `en` with `ja` in the copy commands above; they are listed in [README_ja.md](README_ja.md).
