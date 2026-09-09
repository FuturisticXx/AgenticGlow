cask "agenticglow" do
  version "0.6.0"
  sha256 "84975e3d0ffce03a573b27baaf18b5cb346c03bcf6149315ccf9d1bb6fe8e025"

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
