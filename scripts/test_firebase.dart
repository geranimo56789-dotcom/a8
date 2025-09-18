import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/firebase_options.dart';

Future<void> main() async {
  print('🚀 Testing Firebase Connection...');

  try {
    // Initialize Firebase
    print('📱 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully!');

    // Test Firestore connection
    print('🗄️ Testing Firestore connection...');
    final firestore = FirebaseFirestore.instance;

    // Try to read from a test collection
    final testDoc = await firestore.collection('test').doc('connection').get();
    print('✅ Firestore connection successful!');

    // Test writing a document
    print('✍️ Testing write operation...');
    await firestore.collection('test').doc('connection').set({
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'connected',
      'project': 'var6-51392',
    });
    print('✅ Write operation successful!');

    // Clean up test data
    await firestore.collection('test').doc('connection').delete();
    print('🧹 Test data cleaned up');

    print('\n🎉 All Firebase tests passed!');
    print('🔑 Project ID: var6-51392');
    print('🌐 Your app is ready to use!');
  } catch (e) {
    print('❌ Firebase test failed: $e');
    print('\n🔧 Troubleshooting:');
    print('1. Check your internet connection');
    print(
      '2. Verify Firebase project exists: https://console.firebase.google.com/project/var6-51392',
    );
    print('3. Ensure Firestore is enabled in your project');
    print('4. Check that your API key is correct');
  }
}
