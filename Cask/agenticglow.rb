cask "agenticglow" do
  version "0.4.7"
  sha256 "62792a04c0f526497037bd9925e68e81bc4b7f6f96783d6f2baa840c2ea625ea"

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
