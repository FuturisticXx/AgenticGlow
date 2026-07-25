cask "agenticglow" do
  version "0.5.10"
  sha256 "733ab21084eadd9f4efaeeda0544ce94d2362609724a45577d9251a6ef4632e8"

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

  uninstall quit:   "com.twodamax.agenticglow",
            script: {
              executable: "#{appdir}/AgenticGlow.app/Contents/MacOS/AgenticGlow",
              args:       ["--remove-integrations"],
              sudo:       false,
            }

  zap trash: [
    "~/Library/Application Support/AgenticGlow",
    "~/Library/Caches/com.twodamax.agenticglow",
    "~/Library/Containers/com.twodamax.agenticglow",
    "~/Library/Containers/com.twodamax.agenticglow.widget",
    "~/Library/Group Containers/group.com.twodamax.agenticglow",
    "~/Library/Group Containers/Z52AX2BH7T.group.com.twodamax.agenticglow",
    "~/Library/Preferences/com.twodamax.agenticglow.plist",
  ]
end
