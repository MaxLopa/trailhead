import 'package:app1/models/service_options.dart';
import 'package:app1/models/user_model.dart';
import 'package:app1/repositories/user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MechRepository {
  final UserRepository _userRepo;

  final FirebaseFirestore _db;

  MechRepository({
    required UserRepository userRepo,
    FirebaseFirestore? firestore,
  }) : _userRepo = userRepo,
       _db = firestore ?? FirebaseFirestore.instance;

  Future<DocumentReference> createMech(Mech mech, AppUser user) async {
    var userRef = _db.collection('mechs').doc(user.uid);
    mech.initUserRef(userRef);

    var data = mech.toMap();

    var mechRef = _db.collection('mechs').doc();
    mechRef.set(data);

    user.initMechRef(mechRef);

    _userRepo.updateUser(user);

    return mechRef;
  }

  Future<Mech?> fetchMech(DocumentReference docRef) async {
    var snapshot = await docRef.get();

    if (!snapshot.exists) {
      return null; // throw exception
    }

    var data = snapshot.data() as Map<String, dynamic>;

    final mech = Mech.fromMap(data, docRef);
    return mech;
  }

  Future<void> updateMech(DocumentReference mechRef, Mech mech) async {
    await mechRef.update(mech.toMap());
  }

  Future<void> updateMechServiceIndicies(
    DocumentReference mechRef,
    List<Genre> genres,
  ) async {
    final serviceIndicies = _db.collection('serviceIndices');

    // Load Mech's service indices
    final existing =
        await serviceIndicies.where('mechRef', isEqualTo: mechRef).get();

    // Batch writers
    WriteBatch batch = _db.batch();
    int opCount = 0;

    // Stupid helper to commit (can occur more than once)
    Future<void> commitBatch() async {
      await batch.commit();
      batch = _db.batch();
      opCount = 0;
    }

    // Stupid helper to flush if count exceeds limit
    Future<void> flushIfNeeded() async {
      if (opCount >= 450) {
        await commitBatch();
      }
    }

    // Batch delete existing indices
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
      opCount++;
      await flushIfNeeded();
    }

    // Batch create new indices
    for (final genre in genres) {
      for (final st in genre.serviceTypes) {
        for (final brand in st.brands) {
          final docRef = serviceIndicies.doc('${genre.name}|${st.name}|$brand|${mechRef.id}'); // DocRef with custom id
          batch.set(docRef, {
            'mechRef': mechRef,
            'genre': genre.name,
            'serviceType': st.name,
            'brand': brand,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          opCount++;
          await flushIfNeeded();
        }
      }
    }

    // Final commit if needed
    if (opCount > 0) {
      await commitBatch();
    }
  }

  Future<List<Genre>> fetchGenericGenres() async {
    final col = FirebaseFirestore.instance.collection('genres');
    final snap = await col.get();

    final List<Genre> genres = [];
    for (final doc in snap.docs) {
      final data = doc.data(); // Map<String, dynamic>
      try {
        // Attach id if your model expects it (optional)
        final enriched = {...data, 'id': (data['id'] ?? doc.id)};
        final g = Genre.fromMap(enriched);
        genres.add(g);
      } catch (e) {}
    }
    return genres;
  }
}
