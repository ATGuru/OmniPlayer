#!/bin/bash

# ═══════════════════════════════════════════════════════════
# OmniPlayer — Project Setup Script
# Run from inside your omnix_audio/ project root
# ═══════════════════════════════════════════════════════════

set -e  # Exit on any error

CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${CYAN}"
echo "  ██████╗ ███╗   ███╗███╗   ██╗██╗██╗  ██╗"
echo "██╔═══██╗████╗ ████║████╗  ██║██║╚██╗██╔╝"
echo "██║   ██║██╔████╔██║██╔██╗ ██║██║ ╚███╔╝ "
echo "██║   ██║██║╚██╔╝██║██║╚██╗██║██║ ██╔██╗ "
echo "╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║██╔╝ ██╗"
echo "  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝"
echo -e "          PLAYER — Setup Script${RESET}"
echo ""

# ── 0. Confirm we're in the right place ─────────────────────
if [ ! -f "pubspec.yaml" ]; then
  echo -e "${RED}ERROR: pubspec.yaml not found.${RESET}"
  echo "Run this script from inside your omnix_audio/ project root."
  exit 1
fi

echo -e "${CYAN}[1/6] Creating asset directories...${RESET}"
mkdir -p assets/fonts
mkdir -p assets/images
echo -e "${GREEN}  ✓ assets/fonts/ and assets/images/ created${RESET}"

# ── 1. Download fonts via Google Fonts API ──────────────────
echo ""
echo -e "${CYAN}[2/6] Downloading Orbitron font...${RESET}"

# Orbitron weights: 400, 700, 900
declare -A ORBITRON=(
  ["Orbitron-Regular.ttf"]="https://fonts.gstatic.com/s/orbitron/v31/yMJMMIlzdpvBhQQL_SC3X9yhF25-T1nysimBoWgz.woff2"
  ["Orbitron-Bold.ttf"]="https://fonts.gstatic.com/s/orbitron/v31/yMJMMIlzdpvBhQQL_SC3X9yhF25-T1nySimBoWgz.woff2"
  ["Orbitron-Black.ttf"]="https://fonts.gstatic.com/s/orbitron/v31/yMJMMIlzdpvBhQQL_SC3X9yhF25-T1nysSmBoWgz.woff2"
)

# Use python to download — more reliable than curl for Google Fonts
python3 - <<'PYEOF'
import urllib.request
import os

fonts = {
    "Orbitron-Regular.ttf": "400",
    "Orbitron-Bold.ttf":    "700",
    "Orbitron-Black.ttf":   "900",
    "Rajdhani-Light.ttf":   "300",
    "Rajdhani-Regular.ttf": "400",
    "Rajdhani-SemiBold.ttf":"600",
    "Rajdhani-Bold.ttf":    "700",
}

families = {
    "Orbitron":  ["300", "400", "700", "900"],
    "Rajdhani":  ["300", "400", "600", "700"],
}

headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
}

for family, weights in families.items():
    weight_str = ",".join([f"0,{w}" for w in weights])
    url = f"https://fonts.googleapis.com/css2?family={family.replace(' ', '+')}:wght@{weight_str}&display=swap"
    
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            css = r.read().decode("utf-8")
    except Exception as e:
        print(f"  Could not fetch CSS for {family}: {e}")
        continue

    # Parse woff2 URLs from CSS
    import re
    woff2_urls = re.findall(r'src: url\((https://fonts\.gstatic\.com[^)]+\.woff2)\)', css)
    weight_vals = re.findall(r'font-weight:\s*(\d+)', css)

    weight_map = {
        "300": "Light",
        "400": "Regular",
        "600": "SemiBold",
        "700": "Bold",
        "900": "Black",
    }

    seen = set()
    pairs = list(zip(weight_vals, woff2_urls))
    
    for weight, wurl in pairs:
        suffix = weight_map.get(weight, weight)
        filename = f"{family}-{suffix}.ttf"
        outpath = f"assets/fonts/{filename}"
        
        if filename in seen or os.path.exists(outpath):
            seen.add(filename)
            continue
        seen.add(filename)

        try:
            req2 = urllib.request.Request(wurl, headers=headers)
            with urllib.request.urlopen(req2) as r2:
                data = r2.read()
            with open(outpath, "wb") as f:
                f.write(data)
            print(f"  ✓ Downloaded {filename}")
        except Exception as e:
            print(f"  ✗ Failed {filename}: {e}")

PYEOF

echo ""
echo -e "${CYAN}[3/6] Verifying font files...${RESET}"
REQUIRED_FONTS=(
  "Orbitron-Regular.ttf"
  "Orbitron-Bold.ttf"
  "Orbitron-Black.ttf"
  "Rajdhani-Light.ttf"
  "Rajdhani-Regular.ttf"
  "Rajdhani-SemiBold.ttf"
  "Rajdhani-Bold.ttf"
)

ALL_OK=true
for font in "${REQUIRED_FONTS[@]}"; do
  if [ -f "assets/fonts/$font" ]; then
    SIZE=$(wc -c < "assets/fonts/$font")
    echo -e "${GREEN}  ✓ $font (${SIZE} bytes)${RESET}"
  else
    echo -e "${RED}  ✗ MISSING: $font${RESET}"
    ALL_OK=false
  fi
done

# ── 2. Patch build.gradle ────────────────────────────────────
echo ""
echo -e "${CYAN}[4/6] Patching android/app/build.gradle...${RESET}"

GRADLE_FILE="android/app/build.gradle"

if [ -f "$GRADLE_FILE" ]; then
  # Only patch if not already patched
  if grep -q "minSdkVersion 21" "$GRADLE_FILE"; then
    echo -e "${GREEN}  ✓ build.gradle already patched${RESET}"
  else
    # Replace minSdkVersion (flutter default is 21 now but let's ensure)
    sed -i 's/minSdkVersion [0-9]*/minSdkVersion 21/' "$GRADLE_FILE"
    sed -i 's/targetSdkVersion [0-9]*/targetSdkVersion 34/' "$GRADLE_FILE"
    sed -i 's/compileSdkVersion [0-9]*/compileSdkVersion 34/' "$GRADLE_FILE"
    echo -e "${GREEN}  ✓ Set minSdk=21, targetSdk=34, compileSdk=34${RESET}"
  fi
else
  echo -e "${RED}  ✗ build.gradle not found — patch manually:${RESET}"
  echo "     minSdkVersion 21"
  echo "     targetSdkVersion 34"
  echo "     compileSdkVersion 34"
fi

# ── 3. Create stub files so flutter pub get doesn't fail ────
echo ""
echo -e "${CYAN}[5/6] Creating stub Dart files for missing screens...${RESET}"

mkdir -p lib/features/player/screens
mkdir -p lib/features/player/widgets
mkdir -p lib/features/library/screens
mkdir -p lib/features/library/widgets
mkdir -p lib/core/database/daos
mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/providers

# Player screen stub
cat > lib/features/player/screens/player_screen.dart << 'DART'
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      body: Center(
        child: Text(
          'PLAYER — STEP 4',
          style: OmniPlayerTextStyles.orbitronLabel,
        ),
      ),
    );
  }
}
DART

# Library screen stub
cat > lib/features/library/screens/library_screen.dart << 'DART'
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      body: Center(
        child: Text(
          'LIBRARY — STEP 2',
          style: OmniPlayerTextStyles.orbitronLabel,
        ),
      ),
    );
  }
}
DART

echo -e "${GREEN}  ✓ Stub screens created${RESET}"

# ── 4. flutter pub get ───────────────────────────────────────
echo ""
echo -e "${CYAN}[6/6] Running flutter pub get...${RESET}"
flutter pub get

echo ""
echo -e "${MAGENTA}═══════════════════════════════════════${RESET}"
echo -e "${GREEN}  OMNIPLAYER SETUP COMPLETE${RESET}"
echo -e "${MAGENTA}═══════════════════════════════════════${RESET}"
echo ""
echo -e "  Next: ${CYAN}flutter run${RESET} to verify app boots"
echo -e "  Then say ${CYAN}go${RESET} for Step 2 — Drift DB + scanner"
echo ""

if [ "$ALL_OK" = false ]; then
  echo -e "${RED}  ⚠ Some fonts failed to download.${RESET}"
  echo "  If Google Fonts is blocked, download manually from:"
  echo "  https://fonts.google.com/specimen/Orbitron"
  echo "  https://fonts.google.com/specimen/Rajdhani"
  echo "  Place .ttf files in assets/fonts/"
fi
