# clj-doc-browse.el

[![MELPA](https://melpa.org/packages/clj-doc-browse-badge.svg)](https://melpa.org/#/clj-doc-browse)

Emacs package for browsing Clojure library documentation embedded in JARs, via [CIDER](https://cider.mx).

## What it does

Clojure libraries built with [codox-md](https://github.com/dcj/codox-md) embed Markdown API documentation as classpath resources. This package lets you browse that documentation from Emacs with rendered Markdown and source link navigation.

## Prerequisites

- Emacs 27.1+
- [CIDER](https://cider.mx) connected to a running nREPL
- [markdown-mode](https://jblevins.org/projects/markdown-mode/)
- The [clj-doc-browse](https://github.com/dcj/clj-doc-browse) Clojure library on the REPL classpath
- [cider-nrepl](https://github.com/clojure-emacs/cider-nrepl) middleware (for source link navigation)

### nREPL setup

Your `:nrepl` alias should include both `clj-doc-browse` and `cider-nrepl`:

```clojure
;; deps.edn
:nrepl {:extra-deps {nrepl/nrepl {:mvn/version "1.6.0"}
                     cider/cider-nrepl {:mvn/version "0.50.3"}
                     com.dcj/clj-doc-browse {:mvn/version "0.1.0"}}
        :main-opts ["-m" "nrepl.cmdline"
                    "--middleware" "[cider.nrepl/cider-middleware]"]}
```

## Installation

### Manual

Clone this repo and add to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/clj-doc-browse-el")
(autoload 'clj-doc-browse "clj-doc-browse" "Browse Clojure library docs" t)
(autoload 'clj-doc-browse-libraries "clj-doc-browse" "List documented libraries" t)
(autoload 'clj-doc-browse-search "clj-doc-browse" "Search library docs" t)
```

### MELPA

Available from [MELPA](https://melpa.org/#/clj-doc-browse). Add MELPA to your package archives if you haven't already:

```elisp
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
```

Then:

```
M-x package-install RET clj-doc-browse RET
```

### use-package

```elisp
(use-package clj-doc-browse
  :ensure t
  :after cider)
```

## Usage

Connect CIDER to your nREPL (`M-x cider-connect`), then:

### `M-x clj-doc-browse`

Prompts for a namespace name, fetches the Markdown documentation via CIDER, and displays it in a `*clj-docs*` buffer with `markdown-view-mode`.

### `M-x clj-doc-browse-libraries`

Lists all documented libraries found on the classpath (displayed in the minibuffer).

### `M-x clj-doc-browse-search`

Full-text search across all embedded documentation. Results are displayed in a `*clj-doc-search*` buffer.

## Key bindings in the `*clj-docs*` buffer

| Key | Action |
|---|---|
| `C-c C-o` | Follow source link at point — opens the source file in Emacs (even from JARs) |
| `RET` | Same as `C-c C-o` |
| `n` / `p` | Next / previous heading (from `markdown-view-mode`) |
| `SPC` / `DEL` | Scroll down / up |
| `q` | Close the buffer |

Source links resolve via CIDER's `cider-find-file`, so they work for both local source files and source inside dependency JARs.

## How it works

1. Your Clojure code calls `(doc.browse/show "my.namespace")` which reads Markdown from a classpath resource
2. The nREPL response (a Markdown string) is inserted into an Emacs buffer
3. `markdown-view-mode` renders the Markdown with hidden markup
4. Source links are intercepted by a custom keymap that resolves the classpath path via `clojure.java.io/resource` and opens the file with `cider-find-file`

## Related projects

- [codox-md](https://github.com/dcj/codox-md) — Generates the Markdown docs at build time
- [clj-doc-browse](https://github.com/dcj/clj-doc-browse) — Clojure library for runtime doc discovery (required on REPL classpath)

## License

Copyright (C) 2026 Clark Communications Corporation

[MIT License](LICENSE)
