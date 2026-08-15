# homebrew-sud-workbench

Homebrew tap for [SUD Workbench](https://github.com/skalyan91/sud-workbench), a
native-feeling macOS desktop app for viewing and editing SUD dependency treebanks.

```sh
brew tap skalyan91/sud-workbench
brew install --build-from-source sud-workbench
```

This installs a **Formula**, not a Cask, on purpose: SUD Workbench isn't signed or
notarized. A Formula builds the app from source on your own machine, so the `.app`
it produces is never downloaded as a finished binary and never picks up the
`com.apple.quarantine` flag that would otherwise make Gatekeeper block it on open.

Requires `python@3.12` (installed automatically as a dependency).

After install:

```sh
sud-workbench                                  # launch it
# or, to make it feel like a normal app:
ln -s "$(brew --prefix)/opt/sud-workbench/dist/SUD Workbench.app" /Applications/
```

A Formula can't do that symlink for you automatically — tried it, in both `install` and
`post_install`; Homebrew's own build sandbox refuses writes outside the Cellar in either
one. That's exactly the boundary Casks exist to cross and Formulae can't, and this has to
be a Formula (see above: an unsigned, unnotarized app distributed as a pre-built Cask
binary gets Gatekeeper-quarantined; building from source doesn't).
