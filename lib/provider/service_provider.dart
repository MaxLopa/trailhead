import 'package:app1/models/user_model.dart';
import 'package:app1/repositories/job_repository.dart';
import 'package:app1/repositories/mech_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_options.dart';

/// Holds the available genres for booking.
/// Selections are now local to the BookingPage widget.
class ServiceState extends ChangeNotifier {
  List<Genre> _genres = <Genre>[];

  List<Genre> get genres => _genres;

  void init(List<Genre> genres) {
    _genres = List<Genre>.from(genres);
    notifyListeners();
  }
}
