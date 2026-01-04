import 'package:app1/models/service_options.dart';
import 'package:app1/models/timeslot_model.dart';
import 'package:app1/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceDevRepository {
  final FirebaseFirestore _db;

  ServiceDevRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _genres =>
      _db.collection('services');

  CollectionReference<Map<String, dynamic>> get _brands =>
      _db.collection('brands');

  Future<void> syncNewOptions(List<Genre> genres, List<String> brands) async {
    syncBrands(brands);
    syncServices(genres);
  }

  Future<void> syncServices(List<Genre> genres) async {
    final batch = _db.batch();
    for (var genre in genres) {
      final docRef = FirebaseFirestore.instance
          .collection('genres')
          .doc(genre.name);

      final data = {
        'name': genre.name,
        'serviceTypes':
            genre.serviceTypes.map((st) {
              return st.toMap();
            }).toList(),
        'applicableBrands': genre.applicableBrands,
      };
      batch.set(docRef, data);
    }
    await batch.commit();
  }

  Future<void> syncBrands(List<String> brands) async {
    final batch = _db.batch();
    for (var brand in brands) {
      final docRef = FirebaseFirestore.instance.collection('brands').doc(brand);

      final data = {'brandName': brand};
      batch.set(docRef, data);
    }
    batch.commit();
  }

  Future<List<String>?> fetchBrands(String genre) async {
    final docRef = _db.collection('genres').doc(genre);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return null;

    if (snapshot.exists) {
      final data = snapshot.data();
      return List<String>.from(data?['applicableBrands'] ?? []);
    }
    return null;
  }

  Future<void> seedGenresAndBrands() async {
    var genres = _db.collection('genres');
    var brands = _db.collection('brands');

    final batch = _db.batch();

    for (var genreMap in _genresSeed) {
      final genreDoc = genres.doc(genreMap['name']);

      batch.set(genreDoc, genreMap);

      final applicableBrands = List<String>.from(genreMap['applicableBrands']);
      for (var brand in applicableBrands) {
        final brandDoc = brands.doc(brand);
        batch.set(brandDoc, {'name': brand});
      }
    }

    await batch.commit();
  }

  Future<void> seedMechsFromMapList() async {
    final batch = _db.batch();
    final mechs = _db.collection('mechs');

    for (int i = 0; i < _mechsSeed.length; i++) {
      // Make a defensive copy so we can tweak fields if needed
      final data = _mechsSeed[i].toMap();

      // Ensure userRef is null so Firestore stores it as null (not missing).
      data['userRef'] = null;

      // Stable dev IDs (dev_mech_1, dev_mech_2, ...)
      final docRef = mechs.doc('dev_mech_${i + 1}');
      updateMechServiceIndicies(docRef, _mechsSeed[i].servicesOffered);

      batch.set(docRef, data, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// One-time migration:
  /// - Reads all legacy docs from `genres` collection
  /// - Packs them into a list
  /// - Deletes any existing docs in `Genres`
  /// - Writes a single aggregated doc at `Genres/global`
  /// - Deletes the old docs from `genres`
  Future<void> migrateGenresToSingleDoc() async {
    // 1) Read all current documents from the old `genres` collection
    final col = _db.collection('genres');
    QuerySnapshot querySnap = await col.get();

    // var allData = querySnap.docs.map((element) => element.data()).toList(); // Used to migrate from previous form where the genres were individual docs
    var doc = col.doc(
      'globals',
    ); // globals is the docRef id for all the generic genre object to be used globally

    doc.set({'genres': _genresSeed});
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
        if (st.brands.isEmpty) {
          final docRef = serviceIndicies.doc(
            '${genre.name}|${st.name}|${mechRef.id}',
          ); // DocRef with custom id
          batch.set(docRef, {
            'mechRef': mechRef,
            'genre': genre.name,
            'serviceType': st.name,
            'brand': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          opCount++;
          await flushIfNeeded();
        } else {
          for (final brand in st.brands) {
            final docRef = serviceIndicies.doc(
              '${genre.name}|${st.name}|$brand|${mechRef.id}',
            ); // DocRef with custom id
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
    }

    // Final commit if needed
    if (opCount > 0) {
      await commitBatch();
    }
  }
}

final List<Map<String, dynamic>> _genresSeed = [
  {
    'name': 'Brakes',
    'applicableBrands': ['Shimano', 'SRAM', 'TRP', 'Magura', 'Hope', 'Tektro'],
    'serviceTypes': [
      {
        'name': 'Brake Bleed',
        'description':
            'Remove air from hydraulic brake system and restore lever feel.',
      },
      {
        'name': 'Brake Fluid Flush',
        'description':
            'Fully replace old brake fluid with fresh fluid throughout the system.',
      },
      {
        'name': 'Brake Component Replacement',
        'description':
            'Replace brake components as specified by the rider (pads, rotors, small parts).',
      },
      {
        'name': 'Brake Decontamination',
        'description':
            'Clean rotors and pads to remove oil or residue buildup.',
      },
      {
        'name': 'Brake System Rebuild',
        'description':
            'Full teardown and rebuild of brake system (calipers and/or levers).',
      },
    ],
  },
  {
    'name': 'Drivetrain',
    'applicableBrands': ['Shimano', 'SRAM', 'Box Components', 'MicroSHIFT'],
    'serviceTypes': [
      {
        'name': 'Drivetrain Tune-Up',
        'description':
            'Clean drivetrain and fine tune shifting for smooth performance.',
      },
      {
        'name': 'Drivetrain Component Replacement',
        'description':
            'Replace drivetrain components as specified (chain, cassette, derailleur, chainring, etc.).',
      },
      {
        'name': 'Cable & Housing Replacement',
        'description':
            'Replace shifting cables and housings for smoother operation.',
      },
      {
        'name': 'Drivetrain Installation',
        'description':
            'Install and set up a new drivetrain or major drivetrain upgrade.',
      },
    ],
  },
  {
    'name': 'Suspension',
    'applicableBrands': [
      'Fox',
      'RockShox',
      'Marzocchi',
      'Öhlins',
      'Manitou',
      'SR Suntour',
    ],
    'serviceTypes': [
      {
        'name': 'Fork 50-Hour Service',
        'description':
            'Routine 50-hour service for front fork (oil refresh, inspection, basic maintenance).',
      },
      {
        'name': 'Shock 50-Hour Service',
        'description':
            'Routine 50-hour service for rear shock (air can service, inspection, basic maintenance).',
      },
      {
        'name': 'Fork 100-Hour',
        'description':
            'Full 100-hour damper service for front fork as per manufacturer intervals.',
      },
      {
        'name': 'Shock 100-Hour',
        'description':
            'Full 100-hour damper service for rear shock as per manufacturer intervals.',
      },
      {
        'name': 'Suspension Installation',
        'description':
            'Install or swap fork and/or rear shock and set up for rider.',
      },
      {
        'name': 'Suspension Setup & Tuning',
        'description':
            'Adjust suspension settings (sag, rebound, compression) for rider weight and style.',
      },
    ],
  },
  {
    'name': 'Bearings',
    'applicableBrands': [],
    'serviceTypes': [
      {
        'name': 'Pivot Bearing Replacement',
        'description':
            'Replace frame pivot bearings for smoother suspension movement.',
      },
      {
        'name': 'Bottom Bracket Replacement',
        'description':
            'Install new bottom bracket and grease shell interfaces.',
      },
      {
        'name': 'Headset Service',
        'description': 'Clean, grease, and reassemble headset bearings.',
      },
      {
        'name': 'Hub Bearing Service',
        'description':
            'Inspect, clean, or replace hub and wheel bearings as needed.',
      },
    ],
  },
  {
    'name': 'Wheels',
    'applicableBrands': [],
    'serviceTypes': [
      {
        'name': 'Wheel Truing',
        'description':
            'Adjust spoke tension to correct lateral or radial runout.',
      },
      {
        'name': 'Spoke Replacement',
        'description': 'Replace broken spokes and retrue wheel.',
      },
      {
        'name': 'Tubeless Setup',
        'description': 'Install tubeless tape, valves, and sealant.',
      },
      {
        'name': 'Rim Replacement ⚠️',
        'description': 'Replace damaged rim and rebuild wheel.',
      },
      {
        'name': 'Hub Service',
        'description': 'Disassemble, clean, and lubricate hub internals.',
      },
    ],
  },
  {
    'name': 'Tires',
    'applicableBrands': [
      'Maxxis',
      'Schwalbe',
      'Continental',
      'WTB',
      'Vittoria',
    ],
    'serviceTypes': [
      {
        'name': 'Tire Installation',
        'description': 'Mount and inflate new tires to recommended pressure.',
      },
      {
        'name': 'Tube Replacement',
        'description': 'Replace punctured inner tube and inspect tire casing.',
      },
      {
        'name': 'Sealant Refresh',
        'description':
            'Add new sealant to tubeless tires for continued puncture protection.',
      },
      {
        'name': 'Tire Cleaning',
        'description': 'Clean and inspect tires for cuts or damage.',
      },
    ],
  },
  {
    'name': 'Cockpit',
    'applicableBrands': [],
    'serviceTypes': [
      {
        'name': 'Bar & Stem Install',
        'description':
            'Install or adjust handlebar and stem to proper alignment.',
      },
      {
        'name': 'Grips or Tape Replacement',
        'description': 'Replace worn grips or handlebar tape.',
      },
      {
        'name': 'Dropper Post Service',
        'description': 'Clean, lubricate, or bleed dropper seatpost.',
      },
      {
        'name': 'Seatpost Height Setup',
        'description': 'Adjust seatpost height and saddle angle for fit.',
      },
      {
        'name': 'Control Alignment',
        'description':
            'Align shifters, brake levers, and dropper remote ergonomically.',
      },
    ],
  },
  {
    'name': 'Frame & General Maintenance',
    'applicableBrands': [],
    'serviceTypes': [
      {
        'name': 'Full Bike Wash',
        'description':
            'Clean bike frame, drivetrain, and components thoroughly.',
      },
      {
        'name': 'Bolt Check',
        'description':
            'Inspect and torque all major bolts to manufacturer spec.',
      },
      {
        'name': 'Frame Inspection',
        'description': 'Inspect frame for cracks, wear, and alignment.',
      },
      {
        'name': 'Bearing Grease Injection ⚠️',
        'description':
            'Inject grease into frame pivot points without full teardown.',
      },
    ],
  },
  {
    'name': 'E-Bike Systems',
    'applicableBrands': [
      'Bosch',
      'Shimano STEPS',
      'Brose',
      'Yamaha',
      'Specialized',
    ],
    'serviceTypes': [
      {
        'name': 'Firmware Update',
        'description':
            'Update e-bike motor firmware and check system diagnostics.',
      },
      {
        'name': 'Battery Health Check',
        'description': 'Test and assess battery capacity and cell balance.',
      },
      {
        'name': 'Motor Cleaning',
        'description': 'Clean exterior of motor and inspect connections.',
      },
    ],
  },
];

/// Shared services list for all dev mechs, built from your genre seed maps.
final List<Genre> kDevServicesOffered =
    _genresSeed
        .map<Genre>(
          (genreMap) => Genre(
            genreMap['name'],
            genreMap['serviceTypes']
                .map<ServiceType>(
                  (st) => ServiceType(
                    st['name'],
                    List<String>.from(
                      genreMap['applicableBrands'] as List<dynamic>,
                    ),
                  ),
                )
                .toList(),
            applicableBrands:
                genreMap['applicableBrands'] != null
                    ? List<String>.from(
                      genreMap['applicableBrands'] as List<dynamic>,
                    )
                    : <String>[],
          ),
        )
        .toList();

/// Dev mechs with inline WeeklyAvailability construction.
final List<Mech> _mechsSeed = <Mech>[
  Mech(
    name: 'Brian',
    bio:
        'Brake and suspension specialist focused on high-performance trail and enduro setups.',
    rating: 4.9,
    completedJobs: 125,
    userRef: null,
    servicesOffered: kDevServicesOffered,
    availability: Availability.initial(
      WeeklyAvailability({
        DateTime.monday: [TimeRange(start: '09:00', end: '17:00')],
        DateTime.tuesday: [TimeRange(start: '09:00', end: '17:00')],
        DateTime.wednesday: [TimeRange(start: '09:00', end: '17:00')],
        DateTime.thursday: [TimeRange(start: '09:00', end: '17:00')],
        DateTime.friday: [TimeRange(start: '09:00', end: '17:00')],
      }, title: 'Weekdays 9–5'),
      [
        WeeklyAvailability({
          DateTime.monday: [TimeRange(start: '09:00', end: '17:00')],
          DateTime.tuesday: [TimeRange(start: '09:00', end: '17:00')],
          DateTime.wednesday: [TimeRange(start: '09:00', end: '17:00')],
          DateTime.thursday: [TimeRange(start: '09:00', end: '17:00')],
          DateTime.friday: [TimeRange(start: '09:00', end: '17:00')],
        }, title: 'Weekdays 9–5'),
      ],
    ),
  ),

  Mech(
    name: 'Derek',
    bio:
        'Evening and after-work mechanic offering brake, drivetrain, and wheel services.',
    rating: 4.7,
    completedJobs: 80,
    userRef: null,
    servicesOffered: kDevServicesOffered,
    availability: Availability.initial(
      WeeklyAvailability({
        DateTime.monday: [TimeRange(start: '12:00', end: '20:00')],
        DateTime.tuesday: [TimeRange(start: '12:00', end: '20:00')],
        DateTime.wednesday: [TimeRange(start: '12:00', end: '20:00')],
        DateTime.thursday: [TimeRange(start: '12:00', end: '20:00')],
        DateTime.friday: [TimeRange(start: '12:00', end: '20:00')],
      }, title: 'Weekdays 12–8'),
      [
        WeeklyAvailability({
          DateTime.monday: [TimeRange(start: '12:00', end: '20:00')],
          DateTime.tuesday: [TimeRange(start: '12:00', end: '20:00')],
          DateTime.wednesday: [TimeRange(start: '12:00', end: '20:00')],
          DateTime.thursday: [TimeRange(start: '12:00', end: '20:00')],
          DateTime.friday: [TimeRange(start: '12:00', end: '20:00')],
        }, title: 'Weekdays 12–8'),
      ],
    ),
  ),

  Mech(
    name: 'Shawn',
    bio:
        'Morning availability, fast turnaround on full tune-ups and suspension basics.',
    rating: 4.5,
    completedJobs: 60,
    userRef: null,
    servicesOffered: kDevServicesOffered,
    availability: Availability.initial(
      WeeklyAvailability({
        DateTime.monday: [TimeRange(start: '08:00', end: '14:00')],
        DateTime.tuesday: [TimeRange(start: '08:00', end: '14:00')],
        DateTime.wednesday: [TimeRange(start: '08:00', end: '14:00')],
        DateTime.thursday: [TimeRange(start: '08:00', end: '14:00')],
        DateTime.friday: [TimeRange(start: '08:00', end: '14:00')],
      }, title: 'Weekdays 8–2'),
      [
        WeeklyAvailability({
          DateTime.monday: [TimeRange(start: '08:00', end: '14:00')],
          DateTime.tuesday: [TimeRange(start: '08:00', end: '14:00')],
          DateTime.wednesday: [TimeRange(start: '08:00', end: '14:00')],
          DateTime.thursday: [TimeRange(start: '08:00', end: '14:00')],
          DateTime.friday: [TimeRange(start: '08:00', end: '14:00')],
        }, title: 'Weekdays 8–2'),
      ],
    ),
  ),

  Mech(
    name: 'Maxim',
    bio:
        'Late-day mechanic specializing in wheel work, tubeless setup, and e-bike systems.',
    rating: 4.8,
    completedJobs: 95,
    userRef: null,
    servicesOffered: kDevServicesOffered,
    availability: Availability.initial(
      WeeklyAvailability({
        DateTime.monday: [TimeRange(start: '15:00', end: '21:00')],
        DateTime.tuesday: [TimeRange(start: '15:00', end: '21:00')],
        DateTime.wednesday: [TimeRange(start: '15:00', end: '21:00')],
        DateTime.thursday: [TimeRange(start: '15:00', end: '21:00')],
        DateTime.friday: [TimeRange(start: '15:00', end: '21:00')],
      }, title: 'Weekdays 3–9'),
      [
        WeeklyAvailability({
          DateTime.monday: [TimeRange(start: '15:00', end: '21:00')],
          DateTime.tuesday: [TimeRange(start: '15:00', end: '21:00')],
          DateTime.wednesday: [TimeRange(start: '15:00', end: '21:00')],
          DateTime.thursday: [TimeRange(start: '15:00', end: '21:00')],
          DateTime.friday: [TimeRange(start: '15:00', end: '21:00')],
        }, title: 'Weekdays 3–9'),
      ],
    ),
  ),

  Mech(
    name: 'Victorius',
    bio:
        'Split-shift availability with focus on pivots, bearings, and detailed drivetrains.',
    rating: 4.6,
    completedJobs: 70,
    userRef: null,
    servicesOffered: kDevServicesOffered,
    availability: Availability.initial(
      WeeklyAvailability({
        DateTime.monday: [
          TimeRange(start: '07:00', end: '11:00'),
          TimeRange(start: '13:00', end: '17:00'),
        ],
        DateTime.tuesday: [
          TimeRange(start: '07:00', end: '11:00'),
          TimeRange(start: '13:00', end: '17:00'),
        ],
        DateTime.wednesday: [
          TimeRange(start: '07:00', end: '11:00'),
          TimeRange(start: '13:00', end: '17:00'),
        ],
        DateTime.thursday: [
          TimeRange(start: '07:00', end: '11:00'),
          TimeRange(start: '13:00', end: '17:00'),
        ],
        DateTime.friday: [
          TimeRange(start: '07:00', end: '11:00'),
          TimeRange(start: '13:00', end: '17:00'),
        ],
      }, title: 'Split shifts'),
      [
        WeeklyAvailability({
          DateTime.monday: [
            TimeRange(start: '07:00', end: '11:00'),
            TimeRange(start: '13:00', end: '17:00'),
          ],
          DateTime.tuesday: [
            TimeRange(start: '07:00', end: '11:00'),
            TimeRange(start: '13:00', end: '17:00'),
          ],
          DateTime.wednesday: [
            TimeRange(start: '07:00', end: '11:00'),
            TimeRange(start: '13:00', end: '17:00'),
          ],
          DateTime.thursday: [
            TimeRange(start: '07:00', end: '11:00'),
            TimeRange(start: '13:00', end: '17:00'),
          ],
          DateTime.friday: [
            TimeRange(start: '07:00', end: '11:00'),
            TimeRange(start: '13:00', end: '17:00'),
          ],
        }, title: 'Split shifts'),
      ],
    ),
  ),
];
