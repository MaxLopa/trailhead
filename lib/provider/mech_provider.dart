import 'package:app1/models/timeslot_model.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import 'package:app1/models/user_model.dart';
import 'package:app1/models/service_options.dart';
import 'package:app1/repositories/mech_repository.dart';

class MechProvider extends ChangeNotifier {
  Mech? mech;
  AppUser? user;

  /// Generic “base” catalog pulled from Firestore (e.g., Brakes with all STs).
  List<Genre> allGenres = const [];

  /// selections: GenreName -> { ServiceTypeName -> {BrandName, ...} }
  final Map<String, Map<String, Set<String>>> selections = {};

  /// Active service type (by name) for the brands column
  String? activeServiceTypeName;

  void init(Mech mech, AppUser user) {
    this.mech = mech;
    this.user = user;
  }

  void initGenres({
    required List<Genre> genres,
    Mech? mech,
    AppUser? appUser,
  }) {
    allGenres = genres;
    init(mech!, user!);
    _hydrateSelectionsFromMech();
    notifyListeners();
  }

  // ---------- Derived helpers ----------
  bool get hasAnySelection => selections.isNotEmpty;

  bool isGenreChecked(String genreName) => selections.containsKey(genreName);

  bool isServiceTypeChecked(String genreName, String serviceTypeName) {
    final sts = selections[genreName];
    if (sts == null) return false;
    return sts.containsKey(serviceTypeName);
  }

  bool isBrandChecked(String serviceTypeName, String brandName) {
    for (final genreEntry in selections.values) {
      final set = genreEntry[serviceTypeName];
      if (set != null && set.contains(brandName)) return true;
    }
    return false;
  }

  List<ServiceType> serviceTypesForGenre(Genre g) => g.serviceTypes;

  /// Brands for the given ServiceType name pulled from the owning Genre’s applicableBrands.
  List<dynamic> brandsForServiceTypeName(String stName) {
    final owningGenre = allGenres.firstWhereOrNull(
      (g) => g.serviceTypes.any((s) => s.name == stName),
    );
    if (owningGenre == null) return const [];
    final dynamic genreBrands = (owningGenre as dynamic).applicableBrands ?? [];
    if (genreBrands is List) return genreBrands;
    return const [];
  }

  // ---------- Mutations ----------
  void toggleGenre(String genreName) {
    if (selections.containsKey(genreName)) {
      selections.remove(genreName);
      if (activeServiceTypeName != null) {
        final stillExists = selections.values.any(
          (m) => m.containsKey(activeServiceTypeName!),
        );
        if (!stillExists) activeServiceTypeName = null;
      }
    } else {
      selections[genreName] = {};
    }
    notifyListeners();
  }

  void toggleServiceType(String genreName, String serviceTypeName) {
    final sts = selections.putIfAbsent(genreName, () => {});
    if (sts.containsKey(serviceTypeName)) {
      sts.remove(serviceTypeName);
      if (activeServiceTypeName == serviceTypeName) {
        activeServiceTypeName = null;
      }
    } else {
      sts[serviceTypeName] = <String>{};
      activeServiceTypeName = serviceTypeName; // focus middle column
    }
    notifyListeners();
  }

  void setActiveServiceType(String serviceTypeName) {
    activeServiceTypeName = serviceTypeName;
    notifyListeners();
  }

  void toggleBrand(String serviceTypeName, String brandName) {
    for (final genreEntry in selections.entries) {
      final serviceMap = genreEntry.value;
      if (serviceMap.containsKey(serviceTypeName)) {
        final set = serviceMap[serviceTypeName]!;
        if (set.contains(brandName)) {
          set.remove(brandName);
        } else {
          set.add(brandName);
        }
        break;
      }
    }
    notifyListeners();
  }

  void clearAll() {
    selections.clear();
    activeServiceTypeName = null;
    notifyListeners();
  }

  Future<void> saveMenu(MechRepository repo) async {
    if (mech == null || user?.mechRef == null) return;

    final genres =
        selections.entries.map((genre) {
          final stList =
              genre.value.entries.map((stMap) {
                return ServiceType.fromMap({
                  'name': stMap.key,
                  'brands': stMap.value.toList(),
                });
              }).toList();

          final Set<String> applicableBrands = <String>{};
          for (final st in stList) {
            applicableBrands.addAll(st.brands);
          }

          return Genre(
            genre.key,
            stList,
            applicableBrands: applicableBrands.toList(),
          );
        }).toList();

    // mutate the existing mech instance (no copyWith)
    mech!.servicesOffered = genres;

    await repo.updateMech(user!.mechRef!, mech!);
    await repo.updateMechServiceIndicies(
      user!.mechRef!,
      genres,
    );
    notifyListeners();
  }

  // ---------- Internal ----------
  void _hydrateSelectionsFromMech() {
    final m = mech;
    if (m == null) return;
    if (m.servicesOffered.isEmpty) return;

    for (final g in m.servicesOffered) {
      final stMap = selections.putIfAbsent(
        g.name,
        () => <String, Set<String>>{},
      );
      for (final st in g.serviceTypes) {
        final set = stMap.putIfAbsent(st.name, () => <String>{});
        final dynamic savedBrands =
            (st as dynamic).brands ??
            (st as dynamic).applicableBrands ??
            const [];
        if (savedBrands is List) {
          for (final b in savedBrands) {
            set.add(_brandName(b));
          }
        }
      }
    }
    // Optional: focus first selected ST
    // activeServiceTypeName = selections.values.firstOrNull?.keys.firstOrNull;
  }

  String _brandName(dynamic b) {
    try {
      final n = (b as dynamic).name;
      if (n is String) return n;
    } catch (_) {}
    return b.toString();
  }

  void updateAvailability(
    List<WeeklyAvailability> availabilities,
    WeeklyAvailability defaultWeek,
    MechRepository repo,
  ) {
    if (mech == null) return;
    mech!.updateAvailability(availabilities, defaultWeek);

    _updateMech(repo);
    notifyListeners();
  }

  Future<void> _updateMech(MechRepository repo) async {
    if (mech == null || user?.mechRef == null) return; // Making sure that the mech object exists and the Mech has a Ref in Firebase
    await repo.updateMech(user!.mechRef!, mech!);
  }

  List<WeeklyAvailability> getAvailabilities() {
    if (mech == null) return [];
    return mech!.availabilities;
  }

  WeeklyAvailability? getDefaultWeek() {
    if (mech == null) return null;
    return mech!.defaultWeek;
  }
}
