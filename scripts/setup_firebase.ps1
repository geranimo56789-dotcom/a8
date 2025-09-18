# VAR6 Betting App - Firebase Setup Script for Windows
# This script will help you set up Firebase step by step

Write-Host "🚀 VAR6 Betting App - Firebase Setup" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

# Step 1: Check if Node.js is installed
Write-Host "📥 Checking Node.js installation..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js is installed: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js from https://nodejs.org/" -ForegroundColor Red
    Write-Host "After installing Node.js, run this script again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 2: Install Firebase CLI
Write-Host "📥 Installing Firebase CLI..." -ForegroundColor Yellow
try {
    npm install -g firebase-tools
    Write-Host "✅ Firebase CLI installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install Firebase CLI" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 3: Login to Firebase
Write-Host "🔐 Please login to Firebase in your browser..." -ForegroundColor Yellow
Write-Host "A browser window will open for you to sign in to Google." -ForegroundColor Cyan
Read-Host "Press Enter when you're ready to login"
try {
    firebase login
    Write-Host "✅ Firebase login successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase login failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 4: Create Firebase project
$projectId = "var6-51392"
Write-Host "🚀 Creating Firebase project: $projectId" -ForegroundColor Yellow

# Check if project exists
try {
    $projects = firebase projects:list
    if ($projects -match $projectId) {
        Write-Host "✅ Project $projectId already exists" -ForegroundColor Green
    } else {
        # Create new project
        Write-Host "Creating new project..." -ForegroundColor Yellow
        firebase projects:create $projectId --display-name "VAR6 Betting App"
        Write-Host "✅ Project created successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to create/check project" -ForegroundColor Red
    Write-Host "Please create the project manually in Firebase console:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/" -ForegroundColor Cyan
    Read-Host "Press Enter to continue with manual setup"
}

# Step 5: Initialize Firebase in project
Write-Host "⚙️ Initializing Firebase in project..." -ForegroundColor Yellow
try {
    # Create firebase.json if it doesn't exist
    if (-not (Test-Path "firebase.json")) {
        $firebaseConfig = @"
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
"@
        $firebaseConfig | Out-File -FilePath "firebase.json" -Encoding UTF8
        Write-Host "✅ Created firebase.json" -ForegroundColor Green
    }
    
    # Set project as default
    firebase use $projectId
    Write-Host "✅ Project set as default" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to initialize Firebase project" -ForegroundColor Red
}

# Step 6: Create Firestore rules
Write-Host "📝 Creating Firestore security rules..." -ForegroundColor Yellow

# Create the rules file directly instead of using PowerShell string interpolation
$rulesContent = @"
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Matches: public read-only
    match /matches/{matchId} {
      allow read: if true;
      allow write: if false;
    }

    // User predictions: owner only, locked after match time
    match /users/{userId}/predictions/{matchId} {
      function isOwner() {
        return request.auth != null && request.auth.uid == userId;
      }
      
      allow read: if isOwner();
      
      allow create, update: if isOwner()
        && request.resource.data.matchId == matchId
        && request.time < get(/databases/$(database)/documents/matches/$(matchId)).data.timeUtc
        && request.resource.data.homeScore is int
        && request.resource.data.awayScore is int
        && request.resource.data.homeScore >= 0
        && request.resource.data.awayScore >= 0;

      allow delete: if false; // Prevent tampering
    }
  }
}
"@

$rulesContent | Out-File -FilePath "firestore.rules" -Encoding UTF8
Write-Host "✅ Created firestore.rules" -ForegroundColor Green

# Step 7: Deploy Firestore rules
Write-Host "🚀 Deploying Firestore security rules..." -ForegroundColor Yellow
try {
    firebase deploy --only firestore:rules
    Write-Host "✅ Firestore rules deployed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to deploy Firestore rules" -ForegroundColor Red
    Write-Host "You can deploy them manually later with: firebase deploy --only firestore:rules" -ForegroundColor Yellow
}

# Step 8: Seed database
Write-Host "🌱 Seeding database with sample matches..." -ForegroundColor Yellow
try {
    dart run scripts/seed_firestore.dart
    Write-Host "✅ Database seeded successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Database seeding failed" -ForegroundColor Red
    Write-Host "You can seed it manually later with: dart run scripts/seed_firestore.dart" -ForegroundColor Yellow
}

# Final instructions
Write-Host "" -ForegroundColor White
Write-Host "🎉 Firebase setup completed!" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "📱 Your app is now ready to use!" -ForegroundColor Cyan
Write-Host "🔑 Project ID: $projectId" -ForegroundColor Yellow
Write-Host "🌐 Firebase Console: https://console.firebase.google.com/project/$projectId" -ForegroundColor Cyan

Write-Host "" -ForegroundColor White
Write-Host "🧪 To test your app:" -ForegroundColor Yellow
Write-Host "1. Run: flutter run" -ForegroundColor White
Write-Host "2. Create an account with email/password" -ForegroundColor White
Write-Host "3. Check 'Remember me' for auto-login" -ForegroundColor White
Write-Host "4. Set predictions for matches" -ForegroundColor White
Write-Host "5. Submit and view your predictions" -ForegroundColor White

Write-Host "" -ForegroundColor White
Write-Host "🔐 Don't forget to enable Email/Password authentication in Firebase console!" -ForegroundColor Red
Write-Host "📚 Check FINAL_SETUP.md for detailed instructions" -ForegroundColor Yellow

Read-Host "Press Enter to exit"
