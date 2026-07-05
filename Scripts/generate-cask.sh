#!/usr/bin/env bash
set -euo pipefail

version="${1:?usage: generate-cask.sh VERSION DMG}"
dmg="${2:?usage: generate-cask.sh VERSION DMG}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

test -f "$dmg"
sha="$(shasum -a 256 "$dmg" | awk '{print $1}')"
mkdir -p Cask

cat > Cask/agenticglow.rb <<RUBY
cask "agenticglow" do
  version "${version}"
  sha256 "${sha}"

  url "https://github.com/FuturisticXx/AgenticGlow/releases/download/v#{version}/AgenticGlow-#{version}.dmg"
  name "AgenticGlow"
  desc "Local Codex and Claude session status for the macOS menu bar"
  homepage "https://github.com/FuturisticXx/AgenticGlow"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma
  app "AgenticGlow.app"

  uninstall quit: "com.twodamax.agenticglow",
            script: {
              executable: "#{appdir}/AgenticGlow.app/Contents/MacOS/AgenticGlow",
              args: ["--remove-integrations"],
              sudo: false,
            }

  zap trash: [
    "~/Library/Application Support/AgenticGlow",
    "~/Library/Preferences/com.twodamax.agenticglow.plist",
  ]
end
RUBY
