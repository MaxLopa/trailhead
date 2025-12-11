import 'package:app1/models/service_options.dart';
import 'package:app1/models/timeslot_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Mech {
  DocumentReference? userRef;

  final String name;
  final String bio;
  final double rating;
  final int completedJobs;

  List<Genre> servicesOffered;

  WeeklyAvailability? defaultWeek;
  List<WeeklyAvailability> availabilities;

  Mech({
    required this.name,
    required this.bio,
    required this.rating,
    required this.completedJobs,
    this.userRef,
    this.servicesOffered = const [],
    this.defaultWeek,
    this.availabilities = const [],
  });

  factory Mech.fromMap(
    Map<String, dynamic> map,
    DocumentReference userRef,
  ) {
    return Mech(
      name: map['name'] ?? 'Mechanic',
      bio: map['bio'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      completedJobs: (map['completedJobs'] ?? 0) as int,
      userRef: userRef,
      servicesOffered:
          (map['servicesOffered'] as List<dynamic>? ?? [])
              .map(
                (genreMap) =>
                    Genre.fromMap(Map<String, dynamic>.from(genreMap as Map)),
              )
              .toList(),
      defaultWeek:
          map['defaultWeek'] != null
              ? WeeklyAvailability.fromMap(
                Map<String, dynamic>.from(map['defaultWeek'] as Map),
              )
              : null,
      availabilities:
          (map['availabilities'] as List<dynamic>? ?? [])
              .map(
                (availabilityMap) => WeeklyAvailability.fromMap(
                  Map<String, dynamic>.from(availabilityMap as Map),
                ),
              )
              .toList(),
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
      'defaultWeek': defaultWeek?.toMap(),
      'availabilities':
          availabilities.map((availability) {
            return availability.toMap();
          }).toList(),
    };
  }

  void initUserRef(DocumentReference userRef) {
    this.userRef = userRef;
  }

  void updateAvailability(
    List<WeeklyAvailability> availabilities,
    WeeklyAvailability defaultWeek,
  ) {
    this.availabilities = availabilities;
    this.defaultWeek = defaultWeek;
  }
}

class AppUser {
  String uid;
  String name;
  String email;
  String phone;
  String pfpUrl;
  Map<String, dynamic>? location;
  bool isMechanic;
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
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    AppUser newUser = AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      pfpUrl: map['pfpUrl'] ?? '',
      location: map['location'],
      isMechanic: map['isMechanic'] ?? false,
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

  void initalizeUID(String uid) {
    this.uid = uid;
  }

  void initMechRef(DocumentReference profile) {
    mechRef = profile;
    isMechanic = true;
  }
}
