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

After install, launch it with `sud-workbench`, or open it from **/Applications** — the
Formula symlinks it there automatically (skipped, not failed, if something's already at
that path).

Uninstalling with `brew uninstall sud-workbench` removes everything Homebrew tracks — the
build, the venv, the `sud-workbench` command — but Formulae have no hook for cleaning up
files placed *outside* Homebrew's own prefix (that's Cask-only), so the /Applications
symlink is left behind, now pointing at nothing. Remove it yourself if you want it gone:

```sh
rm "/Applications/SUD Workbench.app"
```
