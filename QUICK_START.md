# 🚀 VAR6 Betting App - Quick Start Guide

## ⚡ **Super Quick Setup (3 minutes)**

### **Option 1: Automatic Setup (Recommended)**
1. **Double-click** `setup_firebase.bat` in your project folder
2. **Follow the prompts** - it will do everything automatically!
3. **Wait for completion** - you'll see green checkmarks ✅

### **Option 2: Manual Setup**
If automatic setup doesn't work, follow these steps:

#### **Step 1: Install Node.js**
- Download from: https://nodejs.org/
- Install with default settings
- Restart your computer

#### **Step 2: Run PowerShell Script**
- Right-click `scripts/setup_firebase.ps1`
- Select "Run with PowerShell"
- Follow the prompts

## 🔧 **What the Setup Does:**

✅ **Creates Firebase project**: `var6-51392`  
✅ **Enables Authentication**: Email/password login  
✅ **Enables Firestore**: Database for matches & predictions  
✅ **Deploys Security Rules**: Anti-cheat protection  
✅ **Seeds Database**: 5 sample football matches  
✅ **Configures App**: All Firebase settings ready  

## 🧪 **Test Your App:**

### **1. Run the App**
```bash
flutter run
```

### **2. Create Account**
- Enter any email and password
- Check "Remember me" ✅
- Click "Create account"

### **3. Test Auto-Login**
- Close the app completely
- Reopen - it should sign you in automatically! 🎉

### **4. Explore Features**
- **Home**: See matches with editable scores
- **Set Predictions**: Use + and - buttons
- **Submit**: Save to Firebase
- **Check Predictions**: View your saved predictions
- **Settings**: Change password, email, language
- **Logout**: Secure sign-out

## 🔒 **Security Features Working:**

- ✅ **Authentication Required**: Must sign in for predictions
- ✅ **Anti-Cheat**: Predictions locked after match time
- ✅ **User Isolation**: Can't see others' predictions
- ✅ **Data Validation**: Scores must be non-negative integers
- ✅ **Audit Trail**: All predictions preserved forever

## 🎯 **What You'll See:**

### **Sample Matches Added:**
1. **Manchester United vs Arsenal** (Premier League)
2. **Chelsea vs Liverpool** (Premier League)  
3. **Barcelona vs Real Madrid** (La Liga)
4. **Bayern Munich vs Dortmund** (Bundesliga)
5. **PSG vs Marseille** (Ligue 1)

### **All matches scheduled for tomorrow** (so you can test predictions)

## 🚨 **If Something Goes Wrong:**

### **Common Issues:**

**"Firebase not initialized"**
- Check `android/app/google-services.json` exists
- Verify `lib/firebase_options.dart` has correct values

**"Permission denied"**
- Check Firestore rules are deployed
- Verify user is authenticated

**"No matches showing"**
- Run: `dart run scripts/seed_firestore.dart`
- Check Firebase console for data

### **Manual Troubleshooting:**
1. **Check Firebase Console**: https://console.firebase.google.com/project/var6-51392
2. **Verify Authentication**: Enabled → Email/Password
3. **Check Firestore**: Database created with rules published
4. **Run Flutter Doctor**: `flutter doctor`

## 🎉 **You're Ready!**

Once setup is complete, your app will:
- **Auto-login** when "Remember me" is checked
- **Show real matches** from Firestore
- **Save predictions** securely
- **Prevent cheating** with time locks
- **Work offline** with cached data

## 📱 **Next Steps:**

1. **Customize**: Update team logos, colors, branding
2. **Add More Matches**: Use Firebase console or seed script
3. **Scale**: Add more leagues, teams, match types
4. **Analytics**: Track user engagement
5. **Notifications**: Alert users about upcoming matches

---

**🎯 Your VAR6 Betting App is now fully functional with Firebase!**

**🔐 Secure, anti-cheat, and ready for production use.**

**🚀 All menus and buttons work perfectly!**
