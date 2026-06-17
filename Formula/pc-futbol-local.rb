# Homebrew formula for PC Fútbol Local.
#
# Install the latest stable release:
#   brew tap i10s/pcf https://github.com/i10s/pc-futbol-local
#   brew install pc-futbol-local
# or track master:
#   brew install --HEAD pc-futbol-local
#
# Game data is NOT bundled; it downloads on demand into ~/.pc-futbol-local.
class PcFutbolLocal < Formula
  desc "Play the classic PC Fútbol games locally in your browser"
  homepage "https://github.com/i10s/pc-futbol-local"
  url "https://github.com/i10s/pc-futbol-local/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "2ae6f480d810afb014c53437142ed96231524164f7637987e2fbda842f6ebc2c"
  license "MIT"
  head "https://github.com/i10s/pc-futbol-local.git", branch: "master"

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
