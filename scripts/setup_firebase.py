#!/usr/bin/env python3
"""
Firebase Project Setup Script for VAR6 Betting App
This script will create a Firebase project and configure it automatically.
"""

import json
import subprocess
import sys
import time
from pathlib import Path

def run_command(command, description):
    """Run a command and handle errors."""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ {description} completed successfully")
            return result.stdout
        else:
            print(f"❌ {description} failed: {result.stderr}")
            return None
    except Exception as e:
        print(f"❌ {description} failed with exception: {e}")
        return None

def create_firebase_project():
    """Create Firebase project using Firebase CLI."""
    
    # Check if Firebase CLI is installed
    if not run_command("firebase --version", "Checking Firebase CLI installation"):
        print("📥 Installing Firebase CLI...")
        run_command("npm install -g firebase-tools", "Installing Firebase CLI")
    
    # Login to Firebase
    print("🔐 Please login to Firebase in your browser...")
    if not run_command("firebase login", "Firebase login"):
        print("❌ Firebase login failed. Please run 'firebase login' manually.")
        return False
    
    # Create project
    project_id = "var6-51392"
    print(f"🚀 Creating Firebase project: {project_id}")
    
    # Check if project exists
    projects_output = run_command("firebase projects:list", "Listing Firebase projects")
    if projects_output and project_id in projects_output:
        print(f"✅ Project {project_id} already exists")
    else:
        # Create new project
        create_cmd = f"firebase projects:create {project_id} --display-name 'VAR6 Betting App'"
        if not run_command(create_cmd, "Creating Firebase project"):
            print("❌ Failed to create project. Please create it manually in Firebase console.")
            return False
    
    return True

def configure_firebase_project():
    """Configure Firebase project with required services."""
    project_id = "var6-51392"
    
    print(f"⚙️ Configuring Firebase project: {project_id}")
    
    # Enable Authentication
    print("🔐 Enabling Authentication...")
    run_command(f"firebase auth:enable --project {project_id}", "Enabling Authentication")
    
    # Enable Firestore
    print("🗄️ Enabling Firestore...")
    run_command(f"firebase firestore:enable --project {project_id}", "Enabling Firestore")
    
    # Set project as default
    run_command(f"firebase use {project_id}", "Setting default project")
    
    return True

def create_firestore_rules():
    """Create Firestore security rules file."""
    rules_content = '''rules_version = '2';
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
}'''
    
    rules_file = Path("firestore.rules")
    rules_file.write_text(rules_content)
    print("📝 Created Firestore security rules file")
    
    # Deploy rules
    print("🚀 Deploying Firestore security rules...")
    run_command("firebase deploy --only firestore:rules", "Deploying Firestore rules")
    
    return True

def seed_database():
    """Seed the database with sample matches."""
    print("🌱 Seeding database with sample matches...")
    
    # Run the Dart seed script
    if run_command("dart run scripts/seed_firestore.dart", "Seeding database"):
        print("✅ Database seeded successfully!")
        return True
    else:
        print("❌ Database seeding failed")
        return False

def main():
    """Main setup function."""
    print("🚀 VAR6 Betting App - Firebase Setup")
    print("=" * 50)
    
    # Step 1: Create Firebase project
    if not create_firebase_project():
        print("❌ Failed to create Firebase project")
        sys.exit(1)
    
    # Step 2: Configure project
    if not configure_firebase_project():
        print("❌ Failed to configure Firebase project")
        sys.exit(1)
    
    # Step 3: Create and deploy Firestore rules
    if not create_firestore_rules():
        print("❌ Failed to create Firestore rules")
        sys.exit(1)
    
    # Step 4: Seed database
    if not seed_database():
        print("❌ Failed to seed database")
        sys.exit(1)
    
    print("\n🎉 Firebase setup completed successfully!")
    print("\n📱 Your app is now ready to use!")
    print("🔑 Project ID: var6-51392")
    print("🌐 Firebase Console: https://console.firebase.google.com/project/var6-51392")
    
    print("\n🧪 To test your app:")
    print("1. Run: flutter run")
    print("2. Create an account with email/password")
    print("3. Check 'Remember me' for auto-login")
    print("4. Set predictions for matches")
    print("5. Submit and view your predictions")

if __name__ == "__main__":
    main()
