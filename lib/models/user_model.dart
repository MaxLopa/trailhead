import 'package:app1/models/service_options.dart';
import 'package:app1/models/timeslot_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Mech {
  DocumentReference? userRef;
  DocumentReference? mechRef;

  final String name;
  final String bio;
  final double rating;
  final int completedJobs;

  List<Genre> servicesOffered;

  Availability availability;

  Mech({
    required this.name,
    required this.bio,
    required this.rating,
    required this.completedJobs,
    this.servicesOffered = const [],
    this.userRef,
    this.mechRef,
    Availability? availability,
  }) : availability = availability ?? Availability.empty();

  factory Mech.fromMap(Map<String, dynamic> data, DocumentReference mechRef) {
    return Mech(
      name: data['name'] ?? 'Mechanic',
      bio: data['bio'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      completedJobs: (data['completedJobs'] ?? 0) as int,
      servicesOffered:
          (data['servicesOffered'] as List<dynamic>? ?? [])
              .map(
                (genreMap) =>
                    Genre.fromMap(Map<String, dynamic>.from(genreMap as Map)),
              )
              .toList(),
      availability: Availability.initial(
        data['defaultWeek'] != null
            ? WeeklyAvailability.fromMap(
              Map<String, dynamic>.from(data['defaultWeek'] as Map),
            )
            : WeeklyAvailability.empty(),
        (data['availabilities'] as List<dynamic>? ?? [])
            .map(
              (availabilityMap) => WeeklyAvailability.fromMap(
                Map<String, dynamic>.from(availabilityMap as Map),
              ),
            )
            .toList(),
      ),

      userRef: data['userRef'] as DocumentReference?,
      mechRef: mechRef,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bio': bio,
      'rating': rating,
      'completedJobs': completedJobs,
      'userRef': userRef,
      'servicesOffered': servicesOffered.map((genre) {
        return genre.toMap();
      }),
      'availability': availability.toMap(),
    };
  }

  void initUserRef(DocumentReference userRef) {
    this.userRef = userRef;
  }

  void updateAvailability(
    List<WeeklyAvailability> availabilities,
    WeeklyAvailability defaultWeek, {
    List<WkOverride> overrides = const [],
  }) {
    availability = Availability(
      defaultWeek,
      availabilities,
      overrides,
      {}
    );
  }
}

class AppUser {
  String? uid;
  String name;
  String email;
  String phone;
  String pfpUrl;
  Map<String, dynamic>? location;
  bool isMechanic;

  DocumentReference? userRef;
  DocumentReference? mechRef;

  AppUser({
    this.uid = '',
    required this.name,
    required this.email,
    required this.phone,
    this.pfpUrl = '',
    required this.location,
    required this.isMechanic,
    this.mechRef,
    this.userRef,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, DocumentReference userRef) {
    AppUser newUser = AppUser(
      uid: userRef.id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      pfpUrl: map['pfpUrl'] ?? '',
      location: map['location'],
      isMechanic: map['isMechanic'] ?? false,
      userRef: userRef,
      mechRef:
          (map['isMechanic'] == true && map['mechanicProfile'] != null)
              ? (map['mechanicProfile'] as DocumentReference)
              : null,
    );

    return newUser;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'pfpUrl': pfpUrl,
      'location': location,
      'isMechanic': isMechanic,
      'mechanicProfile': (isMechanic && mechRef != null) ? mechRef : null,
    };
  }

  /// Initializes the all user backend & cross-refrencing fields after signup
  void initalizeUser(DocumentReference userRef) {
    uid = userRef.id;
    this.userRef = userRef;
  }
}
