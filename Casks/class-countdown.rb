cask "class-countdown" do
  version "1.1.0"
  sha256 "98e46b25325ba18b7776df27442a7dfed4513477ca8ab48eee6cd2c44b4b694c"

  url "https://github.com/moonLeak/class-countdown/releases/download/v#{version}/ClassCountdown-#{version}.dmg"
  name "ClassCountdown"
  desc "Menu bar countdown showing how much longer the current calendar event has left"
  homepage "https://github.com/moonLeak/class-countdown"

  depends_on macos: ">= :tahoe"

  app "ClassCountdown.app"

  zap trash: [
    "~/Library/Preferences/com.carson.classcountdown.plist",
  ]

  caveats <<~EOS
    This app is not notarized by Apple. Install it with --no-quarantine:

      brew install --cask --no-quarantine class-countdown

    If it is already installed but will not launch:

      xattr -dr com.apple.quarantine /Applications/ClassCountdown.app
  EOS
end
