# Quicklook Anything

Quick Look previews and Finder thumbnails for source code, Markdown notes and Jupyter notebooks on macOS. Select a file in Finder and press Space.

- **Code**: syntax-highlighted previews and thumbnails for more than 50 languages and data formats, with 100 themes and your choice of monospace font.
- **Markdown**: Obsidian-flavored notes with KaTeX math, GFM tables, highlighted code blocks, wikilinks, embedded images, callouts, `==highlights==`, `#tags`, task lists and frontmatter properties.
- **Jupyter notebooks** (`.ipynb`): Markdown cells, highlighted code cells and their outputs, including images.

Quicklook Anything is based on [PreviewCode](https://github.com/smittytone/PreviewCode) by Tony Smith; see [Credits](#credits).

## Install

Paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/KehengZhu/QuicklookAnything/main/install.sh | zsh
```

Run the same command again to upgrade; your settings are kept.

Requires macOS 13 (Ventura) or later, on Apple silicon or Intel. Nothing else (no Xcode, Homebrew or Obsidian) is needed.

### What the installer changes

- Copies **Quicklook Anything.app** to `/Applications` (or `~/Applications` if you cannot write to `/Applications`) and registers its Quick Look extensions.
- Turns off other Quick Look extensions for Markdown and Jupyter notebooks (Obsidian's, for example), and the App Store PreviewCode's, so they do not compete with these previews. Uninstalling turns them back on.
- Never changes which app opens a file: double-clicking a file opens it in the same app as before.

The app is signed but not notarized by Apple. macOS does not apply its download check (Gatekeeper) to files fetched by `curl`, so the installer runs without a warning; it checks the download's code signature itself before installing.

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/KehengZhu/QuicklookAnything/main/install.sh | zsh -s -- --uninstall
```

## Usage

Select a file in Finder and press Space, or use Finder's preview pane (**View > Show Preview**) or **Get Info**. Finder icons for code files show a thumbnail of their contents.

You can turn the extensions off and on in **System Settings > General > Login Items & Extensions > Quick Look**.

## Settings

Open **Quicklook Anything** from Applications to choose the theme (one for light mode and one for dark, or a single theme for both), the font, its size and style, line spacing, and the Quick Look window size.

Markdown notes and notebooks follow the system's light or dark mode. Images embedded in a note are found next to the note, in its Obsidian vault, or anywhere in the vault by name; for vaults outside iCloud Drive's Obsidian folder, only images next to the note can be shown.

## Supported Files

Markdown (`.md`, `.markdown`) and Jupyter notebooks (`.ipynb`), plus:

### Compiled Languages

- ActionScript (`.actionscript`)
- Ada (`.ads`, `.adb`)
- AppleScript (`.applescript`)
- Arduino (`.arduino`, `.ino`)
- Basic (`.basic`, `.bas`, `.lis`)
- Brainfuck (`.brainfuck`, `.b`, `.bf`)
- C (`.c`, `.h`)
- C++ (`.cpp`, `.hpp`)
- C# (`.csx`, `.cs`, `.c-sharp`, `.csharp`)
- Clojure (`.clojure`, `.clj`, `.cljc`, `.cljs`)
- CoffeeScript (`.coffee`, `.coffeescript`, `.litcoffee`)
- Dart (`.dart`)
- Elixir (`.elxir`, `.ex`, `.exs`)
- Elm (`.elm`)
- Erlang (`.erlang`, `.erl`, `.hrl`)
- Fortran (`.for`)
- F# (`.fsharp`, `.f-sharp`, `.fsi`, `.fsx`, `.fsscript`)
- Go (`.go`)
- GameMaker Language (`.gml`)
- Haskell (`.haskell`, `.hs`, `.lhs`)
- Java (`.java`)
- JavaScript (`.js`)
- Julia (`.julia`, `.jl`)
- Kotlin (`.kotlin`, `.kt`, `.ktm`, `.kts`)
- Lisp (`.lisp`, `.lsp`, `.fasl`)
- Lua (`.lua`)
- Objective-C (`.m`)
- OPL (`.opl`, `.opa`, `.tpl`)
- Pascal (`.pas`)
- Perl (`.perl`)
- PHP (`.php`)
- Python (`.py`)
- Ruby (`.rb`)
- Rust (`.rs`, `.rust`)
- Swift (`.swift`)
- TypeScript (`.typescript`, `.tsx`)
- Visual Basic Script (`.vbscript`, `.vbe`, `.vbs`, `.wsc`, `.wsf`)
- Vue.js (`.vue`)

### Shell Scripting

- Shell (`.sh`)
- Bash (`.bash`)
- C Shell (`.csh`)
- Korn Shell (`.ksh`)
- TCSH (`.tcsh`)
- Z Shell (`.zsh`)

### Assembly

- ARM Assembler (`.s`)
- x86-64 Assembler (`.asm`, `.nasm`)

### Others

- AsciiDoc (`.asciidoc`, `.adoc`, `.asc`)
- Config files (`.conf`, `.cf`, `.cfg`, `.ini`, `.rc`)
- Cmake files (`.cmake`)
- CSS (`.css`)
- DxO PhotoLab sidecar (`.dop`)
- Environment (`.env`)
- Extensible Markup Platform (`.xmp`)
- LaTex (`.latex`, `.tex`)
- Makefiles (`makefile`)
- Apple Property list files (`.plist`)
- Apple Entitlements files (`.entitlements`)
- Apple Xcode NIB files (`.xib`)
- Apple Xcode storyboard files (`.storyboard`)
- Apple Xcode strings files (`.strings`)
- Protobuf (`.proto`)
- SASS/SCSS (`.scss`, `.sass`)
- SQL script (`.sql`)
- Terraform source file (`.tf`, `.terraform`)
- Terraform variable file (`.tfvars`)
- Translation Memory eXchange (`.tmx`)
- Twig (`.twig`)
- XML Localization Interchange File Format (`.xlf`, `.xliff`)

## Known Issues

1. TypeScript `.ts` files are not previewed: macOS reserves `.ts` for MPEG-2 video. `.tsx` and `.typescript` work.
1. Clojure `.edn` files are not previewed: macOS reserves `.edn` for an Adobe format.
1. Elixir `.exs` files are not previewed when GarageBand or Logic Pro is installed, since those apps use `.exs` for instrument files.

## Building from Source

You need Xcode and an Apple Development certificate.

- `LocalBuild/build-install.sh` builds the app and installs it on this Mac with `install.sh`.
- `LocalBuild/release.sh` builds it and publishes a GitHub release, which the install command then fetches. Set the version in the Xcode project (`MARKETING_VERSION`) first.

## Credits

Quicklook Anything is a fork of [PreviewCode](https://github.com/smittytone/PreviewCode) by [Tony Smith](https://github.com/smittytone), which provides the code previews, thumbnails and settings app. Thank you, Tony, for building it and releasing it under the MIT License. If you only need code previews, consider the original [PreviewCode on the Mac App Store](https://apps.apple.com/app/previewcode/id1571797683).

It also builds on:

- [HighlighterSwift](https://github.com/smittytone/HighlighterSwift) by Tony Smith, derived from [Highlightr](https://github.com/raspu/Highlightr) by Juan Pablo Illanes (MIT)
- [Highlight.js](https://github.com/highlightjs/highlight.js) by Josh Goebel and contributors (BSD-3-Clause)
- [markdown-it](https://github.com/markdown-it/markdown-it) (MIT)
- [KaTeX](https://github.com/KaTeX/KaTeX) (MIT)

Their license texts ship with the app and are in [`Code Previewer/Licences.md`](Code%20Previewer/Licences.md) and [`Markdown Previewer/Web/lib/LICENSES.txt`](Markdown%20Previewer/Web/lib/LICENSES.txt).

## License

[MIT](LICENSE.md). Release notes are in the [CHANGELOG](CHANGELOG.md).
