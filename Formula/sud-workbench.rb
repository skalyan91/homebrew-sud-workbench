# frozen_string_literal: true

class SudWorkbench < Formula
  desc "Native-feeling desktop app for viewing and editing SUD dependency treebanks"
  homepage "https://github.com/skalyan91/sud-workbench"
  url "https://github.com/skalyan91/sud-workbench/archive/refs/tags/v0.3.2.tar.gz"
  sha256 "63a9f37a0b08ce31dc8636fbbe0c9ccbe7f79f40e8f0d73d793893d724047952"
  license "MIT"

  # This is a Formula, not a Cask, ON PURPOSE: SUD Workbench is not signed or
  # notarized, and a Cask would distribute a prebuilt, quarantined binary that
  # Gatekeeper blocks on open. A Formula instead builds the app FROM SOURCE on
  # the installing machine — the resulting .app is never downloaded as a
  # finished binary, so `com.apple.quarantine` (which only browsers/curl-as-
  # a-downloader/AirDrop set, and which Homebrew's own fetch does not set
  # either) never lands on it, and there is nothing for Gatekeeper to block.
  #
  # depends_on "python@3.12" is not just this project's own floor (spaCy/
  # stanza/torch wheels are unreliable on newer CPython) -- it also matters
  # for the app's "Tahoe" (macOS 26) fully-rounded window corners. AppKit
  # decides whether to draw those based on the LC_BUILD_VERSION SDK the
  # RUNNING PROCESS (here: the python3.12 interpreter itself) was linked
  # against -- there is no public per-window corner-radius API in macOS 26
  # that application code calls. Homebrew's own python@3.12 bottle is
  # rebuilt against current macOS SDKs (confirmed: linked against SDK 26.4
  # as of this formula's writing) -- a python.org installer or a stale
  # cached interpreter may not be, and would run with the previous
  # appearance instead. See this project's own README ("the window's
  # corners are not fully rounded") for the same diagnosis, arrived at
  # independently of this formula.
  depends_on :macos
  depends_on "python@3.12"

  def install
    # Copy the source tree into this formula's OWN permanent prefix before building,
    # rather than building in Homebrew's transient buildpath: packaging/make_app.sh
    # bakes the absolute path it is run FROM into the launcher script it writes, so
    # that path has to already be the install's final resting place.
    prefix.install Dir["*"]

    py312 = formula_opt_bin("python@3.12")/"python3.12"
    cd prefix do
      system py312, "-m", "venv", ".venv"
      system ".venv/bin/pip", "install", "--upgrade", "pip"
      # requirements-core.txt: the same light, torch-free set the shipping macOS/Windows/
      # Linux bundles install from (packaging/make_bootstrap_app.sh, make_deb.sh, ...).
      # The heavy optional tiers (Stanza/torch, Japanese, Arabic) install on demand from
      # inside the app itself (Manage Models), matching every other distribution channel.
      system ".venv/bin/pip", "install", "-r", "requirements-core.txt"
      system "bash", "packaging/make_app.sh", (prefix/"dist").to_s
    end

    # Homebrew Formulae don't drop .app bundles into /Applications the way Casks do;
    # give the user a normal launch path either way. (Not write_exec_script: the
    # bundle's own launcher binary is literally named "SUD Workbench", spaces and
    # all, which is not a usable command name.)
    launcher = prefix/"dist/SUD Workbench.app/Contents/MacOS/SUD Workbench"
    (bin/"sud-workbench").write <<~SH
      #!/bin/bash
      exec "#{launcher}" "$@"
    SH
    (bin/"sud-workbench").chmod 0755
  end

  # Convenience symlink into /Applications, on request ("isn't there a brew command that'll
  # drop the app bundle directly into Applications?"). Formulae have no built-in mechanism
  # for this -- that's specifically what Casks do, and this can't BE a Cask (see this file's
  # header). MUST live in post_install, not install: a real end-to-end `brew install` on
  # this machine proved install's own build sandbox refuses writes outside the Cellar
  # ("Operation not permitted @ rb_file_s_symlink") -- not a guess, the first version of
  # this method sat in install and failed exactly that way. post_install runs after the
  # keg is finalized and isn't confined to the same sandbox. Points at opt_prefix
  # (Homebrew's own stable, upgrade-surviving pointer, not the raw versioned Cellar path a
  # new version would orphan), and only created if nothing already occupies that exact
  # spot -- never clobber a manual install or something else's own use of the name.
  def post_install
    applications = Pathname.new("/Applications")
    target = applications/"SUD Workbench.app"
    return if target.exist? || target.symlink?

    begin
      ln_s(opt_prefix/"dist/SUD Workbench.app", target)
    rescue => e
      opoo "Couldn't symlink into /Applications (#{e.message}). Run manually:\n  " \
           "ln -s \"#{opt_prefix}/dist/SUD Workbench.app\" /Applications/"
    end
  end

  def caveats
    <<~EOS
      SUD Workbench was built from source and installed to:
        #{opt_prefix}/dist/SUD Workbench.app

      Launch it with `sud-workbench`, or from /Applications (a symlink is placed there
      automatically, unless something already occupies that path).

      Uninstalling: `brew uninstall sud-workbench` removes everything Homebrew tracks --
      the build, the venv, the `sud-workbench` command -- but Formulae have no hook for
      cleaning up files placed OUTSIDE Homebrew's own prefix (that's a Cask-only
      capability), so the /Applications symlink above is left behind, now pointing at
      nothing. Remove it yourself if you want it gone:
        rm "/Applications/SUD Workbench.app"

      Optional: UD <-> SUD/mSUD format conversion needs grew's OCaml backend
      (not installed by this formula -- the app runs fine without it, with
      that one feature disabled):
        brew install opam && opam init -y
        opam remote add grew https://opam.grew.fr
        opam install -y grewpy_backend
    EOS
  end

  test do
    cd prefix do
      system prefix/".venv/bin/python", "-c",
             "import app; assert app.__version__ == '#{version}', app.__version__"
    end
    assert_path_exists prefix/"dist/SUD Workbench.app/Contents/MacOS/SUD Workbench"
    assert_path_exists bin/"sud-workbench"
    plist = (prefix/"dist/SUD Workbench.app/Contents/Info.plist").read
    assert_match "<string>#{version}</string>", plist
  end
end
