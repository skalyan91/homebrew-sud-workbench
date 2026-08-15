# frozen_string_literal: true

class SudWorkbench < Formula
  desc "Native-feeling desktop app for viewing and editing SUD dependency treebanks"
  homepage "https://github.com/skalyan91/sud-workbench"
  url "https://github.com/skalyan91/sud-workbench/archive/refs/tags/v0.3.4.tar.gz"
  sha256 "30fe5e94c616bccfe19305e5c77b755a39a9ba08c66eaeff0e62043e548525e8"
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

  def caveats
    <<~EOS
      SUD Workbench was built from source and installed to:
        #{opt_prefix}/dist/SUD Workbench.app

      Launch it with `sud-workbench`, or make it feel like a normal app:
        ln -s "#{opt_prefix}/dist/SUD Workbench.app" /Applications/

      A Formula can't do that symlink FOR you at install time ("isn't there a brew
      command that'll drop the app bundle directly into Applications?" -- no: tried it,
      twice, in both install and post_install; Homebrew's own build sandbox refuses
      writes outside the Cellar in both -- "Operation not permitted @ rb_file_s_symlink"
      against /Applications, a real failure on a real install, not a guess). That's
      exactly the boundary Casks exist to cross and Formulae can't -- see this file's
      own header for why this has to be a Formula instead.

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
