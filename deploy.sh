#!/bin/bash

set -euo pipefail

echo "========================================"
echo "Building Flutter Web App for Production"
echo "========================================"
echo "Firebase project: aess-alumni"
echo "Hosting site:     ustp-aess"
echo ""

# Full Material Icons font is required on web. Tree-shaken fonts leave
# empty icon chips on Dashboard / Program Insights / other admin screens.
flutter build web --release --no-tree-shake-icons

ICON_FONT="build/web/assets/fonts/MaterialIcons-Regular.otf"
if [[ ! -f "$ICON_FONT" ]]; then
  echo ""
  echo "ERROR: MaterialIcons-Regular.otf missing after build."
  echo "Re-run with: flutter build web --release --no-tree-shake-icons"
  exit 1
fi

ICON_SIZE=$(wc -c < "$ICON_FONT" | tr -d ' ')
# Tree-shaken fonts are ~30-55KB; full font is ~1.6MB. Fail under 500KB.
if (( ICON_SIZE < 500000 )); then
  echo ""
  echo "ERROR: MaterialIcons font is only ${ICON_SIZE} bytes — icons will be blank live."
  echo "Build must use --no-tree-shake-icons so the full font is bundled."
  exit 1
fi
echo "Icon font OK: MaterialIcons-Regular.otf (${ICON_SIZE} bytes)"

echo ""
echo "========================================"
echo "Deploying to Firebase Hosting"
echo "========================================"
firebase deploy --only hosting --project aess-alumni

echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo "Your app is now live at:"
echo "https://ustp-aess.web.app"
echo "https://ustp-aess.firebaseapp.com"
echo ""
echo "Do not use legacy hosts alumni-3fb4d / aess-alumni for QA — they may"
echo "still serve an old tree-shaken icon font."
echo ""
