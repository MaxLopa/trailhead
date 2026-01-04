import 'package:app1/models/job.dart';
import 'package:app1/models/service_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobRepository {
  final FirebaseFirestore _db;
  final CollectionReference _genres;
  final CollectionReference _bookings;


  JobRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _genres = (firestore ?? FirebaseFirestore.instance).collection('genres'),
      _bookings = (firestore ?? FirebaseFirestore.instance).collection('bookings');

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
    final snap = await _genres.doc('globals').get();

    if (!snap.exists) return [];

    final data = snap.data() as Map<String, dynamic>;
    final raw = data['genres'] as List<dynamic>? ?? [];

    return raw
        .map((e) => Genre.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> backupBooking(Booking booking) async {
    await _bookings.doc(booking.id).set(booking.toMap(), SetOptions(merge: true));
  }

  Future<Booking?> fetchBookingById(String bookingId) async {
    final snap = await _bookings.doc(bookingId).get();
    if (!snap.exists) return null;
    return Booking.fromMap(snap.data() as Map<String, dynamic>);
  }

  Future<List<Booking>> fetchBookingsForUser(String userId) async {
    final snap =
        await _bookings.where('userId', isEqualTo: userId).get();
    return snap.docs
        .map((d) => Booking.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }
}
