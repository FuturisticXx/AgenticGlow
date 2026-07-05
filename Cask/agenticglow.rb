cask "agenticglow" do
  version "0.1.1"
  sha256 "ead3891c296770f8e455c9495f68987530e24a96197539287dbbd2bcf14aec35"

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
