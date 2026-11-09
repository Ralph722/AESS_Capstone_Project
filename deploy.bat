@echo off
setlocal EnableExtensions

echo ========================================
echo Building Flutter Web App for Production
echo ========================================
echo Firebase project: aess-alumni
echo Hosting site:     ustp-aess
echo.

REM Full Material Icons font is required on web. Tree-shaken fonts leave
REM empty icon chips on Dashboard / Program Insights / other admin screens.
call flutter build web --release --no-tree-shake-icons
if errorlevel 1 (
  echo.
  echo Build failed! Please check the errors above.
  pause
  exit /b 1
)

set "ICON_FONT=build\web\assets\fonts\MaterialIcons-Regular.otf"
if not exist "%ICON_FONT%" (
  echo.
  echo ERROR: MaterialIcons-Regular.otf missing after build.
  echo Re-run with: flutter build web --release --no-tree-shake-icons
  pause
  exit /b 1
)

for %%A in ("%ICON_FONT%") do set "ICON_SIZE=%%~zA"
REM Tree-shaken fonts are ~30-55KB; full font is ~1.6MB. Fail under 500KB.
if %ICON_SIZE% LSS 500000 (
  echo.
  echo ERROR: MaterialIcons font is only %ICON_SIZE% bytes - icons will be blank live.
  echo Build must use --no-tree-shake-icons so the full font is bundled.
  pause
  exit /b 1
)
echo Icon font OK: MaterialIcons-Regular.otf (%ICON_SIZE% bytes)

echo.
echo ========================================
echo Deploying to Firebase Hosting
echo ========================================
call firebase deploy --only hosting --project aess-alumni
if errorlevel 1 (
  echo.
  echo Deployment failed! Please check the errors above.
  pause
  exit /b 1
)

echo.
echo ========================================
echo Deployment Complete!
echo ========================================
echo Your app is now live at:
echo https://ustp-aess.web.app
echo https://ustp-aess.firebaseapp.com
echo.
echo Do not use legacy hosts alumni-3fb4d / aess-alumni for QA - they may
echo still serve an old tree-shaken icon font.
echo.
pause
