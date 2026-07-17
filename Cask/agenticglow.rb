cask "agenticglow" do
  version "0.5.1"
  sha256 "36240e1f599c9f916181b957ad3bd3cf25744d89a067c48b2593dbf26c2b5f57"

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
