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
  url "https://github.com/i10s/pc-futbol-local/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "67707bf360badb816a170d41e1f681d012026973197f72717adb373e2507e10c"
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

      Share a saved career with a friend (Cloudflare-backed):
        pcf saves share my-career.pcfsave   # → prints a short code
        pcf saves get  ABCDEFGHJK           # ← download by code
    EOS
  end

  test do
    assert_match "PC Fútbol", shell_output("#{bin}/pcf list")
  end
end
