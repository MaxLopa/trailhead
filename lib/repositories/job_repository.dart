import 'package:app1/models/service_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobRepository {
  final FirebaseFirestore _db;
  final CollectionReference _genres;

  JobRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _genres = (firestore ?? FirebaseFirestore.instance).collection('genres');

  Future<List<DocumentReference>> queryIndiciesWithOptions(
    String genre,
    String serviceType,
    String brand,
  ) async {
    final indicies = _db.collection('serviceIndices');

    final snap =
        await indicies
            .where('genre', isEqualTo: genre)
            .where('serviceType', isEqualTo: serviceType)
            .where('brand', isEqualTo: brand)
            .get();

    // each doc has a `mechRef` field pointing to the mechanic profile
    return snap.docs
        .map((doc) => doc.data()['mechRef'] as DocumentReference)
        .toList();
  }

  Future<List<Genre>> fetchGenericGenres() async {
    final snap = await _genres.get();
    List<Genre> genres = [];

    for (final doc in snap.docs) {
      genres.add(Genre.fromMap(doc.data() as Map<String, dynamic>));
    }
    return genres;
  }
}
