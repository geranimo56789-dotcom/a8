@echo off
echo 🚀 VAR6 Betting App - Simple Firebase Setup
echo ============================================
echo.
echo This will set up Firebase step by step!
echo.
echo Requirements:
echo - Node.js installed (https://nodejs.org/)
echo - Google account for Firebase
echo.
pause
echo.
echo Starting Firebase setup...
echo.

REM Check if Node.js is installed
echo 📥 Checking Node.js installation...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js not found. Please install Node.js from https://nodejs.org/
    echo After installing Node.js, run this script again.
    pause
    exit /b 1
)
echo ✅ Node.js is installed

REM Install Firebase CLI
echo 📥 Installing Firebase CLI...
call npm install -g firebase-tools
if %errorlevel% neq 0 (
    echo ❌ Failed to install Firebase CLI
    pause
    exit /b 1
)
echo ✅ Firebase CLI installed

REM Login to Firebase
echo 🔐 Please login to Firebase in your browser...
echo A browser window will open for you to sign in to Google.
pause
call firebase login
if %errorlevel% neq 0 (
    echo ❌ Firebase login failed
    pause
    exit /b 1
)
echo ✅ Firebase login successful

REM Set project
echo 🚀 Setting Firebase project: var6-51392
call firebase use var6-51392
if %errorlevel% neq 0 (
    echo ❌ Failed to set project
    pause
    exit /b 1
)
echo ✅ Project set as default

REM Deploy rules
echo 🚀 Deploying Firestore security rules...
call firebase deploy --only firestore:rules
if %errorlevel% neq 0 (
    echo ❌ Failed to deploy rules
    echo You can deploy them manually later with: firebase deploy --only firestore:rules
) else (
    echo ✅ Firestore rules deployed successfully
)

REM Seed database
echo 🌱 Seeding database with sample matches...
call dart run scripts/seed_firestore.dart
if %errorlevel% neq 0 (
    echo ❌ Database seeding failed
    echo You can seed it manually later with: dart run scripts/seed_firestore.dart
) else (
    echo ✅ Database seeded successfully!
)

echo.
echo 🎉 Firebase setup completed!
echo.
echo 📱 Your app is now ready to use!
echo 🔑 Project ID: var6-51392
echo 🌐 Firebase Console: https://console.firebase.google.com/project/var6-51392
echo.
echo 🧪 To test your app:
echo 1. Run: flutter run
echo 2. Create an account with email/password
echo 3. Check "Remember me" for auto-login
echo 4. Set predictions for matches
echo 5. Submit and view your predictions
echo.
echo 🔐 Don't forget to enable Email/Password authentication in Firebase console!
echo 📚 Check FINAL_SETUP.md for detailed instructions
echo.
pause
