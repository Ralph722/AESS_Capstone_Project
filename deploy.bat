@echo off
echo ========================================
echo Building Flutter Web App for Production
echo ========================================
flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed! Please check the errors above.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================
echo Deploying to Firebase Hosting
echo ========================================
firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Deployment failed! Please check the errors above.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================
echo Deployment Complete!
echo ========================================
echo Your app is now live at:
echo https://alumni-3fb4d.web.app
echo https://alumni-3fb4d.firebaseapp.com
echo.
pause

