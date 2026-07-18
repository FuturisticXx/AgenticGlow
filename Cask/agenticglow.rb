cask "agenticglow" do
  version "0.5.4"
  sha256 "303098ed1642ac1076b098c04e35425399f3d65e509af49295059bdf68768c67"

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
