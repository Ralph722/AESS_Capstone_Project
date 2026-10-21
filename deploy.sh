#!/bin/bash

set -euo pipefail

echo "========================================"
echo "Building Flutter Web App for Production"
echo "========================================"
echo "Firebase project: aess-alumni"
echo "Hosting site:     ustp-aess"
echo ""

flutter build web --release

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
