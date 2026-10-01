// libvaultos/phosphor.hpp — Vault.OS colour tokens. Header-only.
// Phosphor is #1AFF6B (Reduced variant #66FF9C). Nothing else is "the green".
#pragma once

namespace vaultos {

struct Rgb {
  double r, g, b;
};

constexpr Rgb hex_rgb(unsigned v) {
  return {((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0};
}

constexpr unsigned kPhosphorHex = 0x1AFF6B;         // full
constexpr unsigned kPhosphorReducedHex = 0x66FF9C;  // Vault.OS-Reduced
constexpr unsigned kVaultBlackHex = 0x070807;
constexpr unsigned kSteelHex = 0x8A8F86;

constexpr Rgb kPhosphor = hex_rgb(kPhosphorHex);
constexpr Rgb kPhosphorReduced = hex_rgb(kPhosphorReducedHex);
constexpr Rgb kVaultBlack = hex_rgb(kVaultBlackHex);
constexpr Rgb kSteel = hex_rgb(kSteelHex);

constexpr const char* kThemeFull = "Vault.OS";
constexpr const char* kThemeReduced = "Vault.OS-Reduced";
constexpr const char* kSaverThemeId = "screensavers-vaultos-arch-spin";

}  // namespace vaultos
