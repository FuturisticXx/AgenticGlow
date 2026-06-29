#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: generate-cask.sh VERSION DMG}"
dmg="${2:?usage: generate-cask.sh VERSION DMG}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

test -f "$dmg"
sha="$(shasum -a 256 "$dmg" | awk '{print $1}')"
mkdir -p Cask

cat > Cask/klarity.rb <<RUBY
cask "klarity" do
  version "${version}"
  sha256 "${sha}"

  url "https://github.com/jwright0180/Klarity/releases/download/v#{version}/Klarity-#{version}.dmg"
  name "Klarity"
  desc "Local Codex and Claude session status for the macOS menu bar"
  homepage "https://github.com/jwright0180/Klarity"

  depends_on macos: ">= :sonoma"
  app "Klarity.app"

  uninstall quit: "com.twodamax.klarity",
            script: {
              executable: "#{appdir}/Klarity.app/Contents/MacOS/Klarity",
              args: ["--remove-integrations"],
              sudo: false,
            }

  zap trash: [
    "~/Library/Application Support/Klarity",
    "~/Library/Preferences/com.twodamax.klarity.plist",
  ]
end
RUBY
