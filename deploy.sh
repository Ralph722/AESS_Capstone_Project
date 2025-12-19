#!/bin/bash

echo "========================================"
echo "Building Flutter Web App for Production"
echo "========================================"
flutter build web --release

if [ $? -ne 0 ]; then
    echo ""
    echo "Build failed! Please check the errors above."
    exit 1
fi

echo ""
echo "========================================"
echo "Deploying to Firebase Hosting"
echo "========================================"
firebase deploy --only hosting

if [ $? -ne 0 ]; then
    echo ""
    echo "Deployment failed! Please check the errors above."
    exit 1
fi

echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo "Your app is now live at:"
echo "https://alumni-3fb4d.web.app"
echo "https://alumni-3fb4d.firebaseapp.com"
echo ""

