import 'package:app1/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Create new user profile in Firestore
  /// and return the DocRef
  Future<DocumentReference> createUser(AppUser user) async {
    final data =
        user.toMap()..addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    final userRef = _db.collection('users').doc(user.uid);

    await userRef.set(data);
    return userRef;
  }

  /// Fetch user profile by UID
  Future<AppUser?> fetchUser(String uid) async {
    final docRef = _db.collection('users').doc(uid);
    final data = (await docRef.get()).data();


    if (data == null) {
      // Either return null or throw, depending on your flow
      return null; // simplest
    }

    return AppUser.fromMap(data, docRef);
  }

  Stream<AppUser> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) {
        throw Exception('User deleted');
      }
      return AppUser.fromMap(snap.data()!, snap.reference);
    });
  }

  /// Update user profile
  Future<void> updateUser(AppUser user) async {
    final data =
        user.toMap()..addAll({'updatedAt': FieldValue.serverTimestamp()});

    await _db.collection('users').doc(user.uid).update(data);
  }
}
