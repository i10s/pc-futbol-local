# Homebrew formula for PC Fútbol Local.
#
# Install the latest from master:
#   brew install --HEAD i10s/pc-futbol-local/pc-futbol-local
# or directly from this file:
#   brew install --HEAD --formula ./Formula/pc-futbol-local.rb
#
# Game data is NOT bundled; it downloads on demand into ~/.pc-futbol-local.
class PcFutbolLocal < Formula
  desc "Play the classic PC Fútbol games locally in your browser"
  homepage "https://github.com/i10s/pc-futbol-local"
  license "MIT"
  head "https://github.com/i10s/pc-futbol-local.git", branch: "master"

  # When a versioned release is cut, fill these in so `brew audit` passes:
  #   url "https://github.com/i10s/pc-futbol-local/archive/refs/tags/v0.1.0.tar.gz"
  #   sha256 "…"

  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]
    (bin/"pcf").write <<~SH
      #!/bin/bash
      export PATH="#{Formula["python@3.12"].opt_bin}:$PATH"
      export PCF_PLAY_DIR="${PCF_PLAY_DIR:-$HOME/.pc-futbol-local}"
      exec "#{libexec}/pcf" "$@"
    SH
    chmod 0755, bin/"pcf"
  end

  def caveats
    <<~EOS
      Game data is downloaded on demand into:
        ~/.pc-futbol-local   (override with PCF_PLAY_DIR)

      Get started:
        pcf list
        pcf play pcf5
    EOS
  end

  test do
    assert_match "PC Fútbol", shell_output("#{bin}/pcf list")
  end
end
