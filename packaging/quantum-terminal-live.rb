cask "quantum-terminal-live" do
  version "3.1.2"
  sha256 "5b71b4b9a848bb3a4dfba3311d1d388bd900db3b8ca3184edbe49803a59b877e"

  url "https://github.com/ZeroXSHDW/quantum-terminal-live/releases/download/v#{version}/Quantum-Terminal-Live-#{version}.dmg"
  name "Quantum Terminal Live"
  desc "Procedural 8K cyber-security vault — live desktop layer and 30s screen saver"
  homepage "https://github.com/ZeroXSHDW/quantum-terminal-live"

  livecheck do
    url :homepage
    regex(/releases\/tag\/v?(\d+(?:\.\d+)+)/i)
  end

  app "Quantum Terminal Live.app"

  caveats <<~EOS
    The 8K screen-saver loop is a separate asset. Download
    Quantum-Terminal-Live-30s.mov from the GitHub Releases page and copy it to
    ~/Movies/Quantum Terminal/, then select the "Quantum Terminal" playlist in
    Aerial (System Settings → Wallpaper).
  EOS
end
