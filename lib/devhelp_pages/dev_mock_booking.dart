import 'package:app1/models/job.dart';
import 'package:app1/models/service_options.dart';
import 'package:app1/models/timeslot_model.dart';
import 'package:app1/models/user_model.dart';
import 'package:app1/pages/home_page.dart';
import 'package:app1/repositories/job_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Reuse the hand-drawn widgets + colors + MechPreview from your existing BookingPage file.
// (This keeps the “previous code practices” look & feel consistent.)
import 'package:app1/pages/booking_page.dart'
    show kPaper, kInk, PencilPanel, PencilHSeparator, MechPreview;

/// Dev mock page to build booking logic step-by-step.
/// - Lists first 10 mechanics
/// - Select one -> shows ONLY that mechanic's possible (genre/serviceType/brand) combos (via serviceIndex)
/// - Select date + time slot that matches their weekly availability
/// - Creates Booking locally (in memory)
class DevMockBooking extends StatefulWidget {
  const DevMockBooking({super.key});

  @override
  State<DevMockBooking> createState() => _DevMockBookingState();
}

class _DevMockBookingState extends State<DevMockBooking> {
  // 🔧 Adjust these to match your Firestore structure if needed
  static const String kMechsCollection = 'mechs';
  static const String kServiceIndexCollection = 'serviceIndices';

  // ---- Mechanics ----
  bool _loadingMechs = true;
  List<_MechRow> _mechs = <_MechRow>[];
  _MechRow? _selectedMech;

  // ---- Global genres (fallback mapping to real Genre/ServiceType objects) ----
  bool _loadingGenres = true;
  List<Genre> _allGenres = const <Genre>[];

  // ---- ServiceIndex-derived options for selected mech ----
  bool _loadingMechServices = false;
  List<_ServiceIndexRow> _mechIndexRows = <_ServiceIndexRow>[];

  // ---- Current selections ----
  String? _selectedGenreName;
  String? _selectedServiceTypeName;
  String? _selectedBrand;

  DateTime? _selectedDate;
  String? _selectedTimeSlot;

  // ---- Local booking result ----
  Booking? _localBooking;
  DateTime? _localScheduledDate;
  String? _localScheduledTime;

  // -------------------------
  // Lifecycle
  // -------------------------
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadGenres(), _loadFirst10Mechanics()]);

    // Auto-select first mech if present
    if (mounted && _mechs.isNotEmpty) {
      await _selectMechanic(_mechs.first);
    }
  }

  // -------------------------
  // Firestore loads
  // -------------------------
  Future<void> _loadFirst10Mechanics() async {
    setState(() => _loadingMechs = true);

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection(kMechsCollection)
              .limit(10)
              .get();

      final rows =
          snap.docs.map((d) {
            final data = d.data();
            final userRef = data['userRef'] as DocumentReference?;
            final mech = Mech.fromMap(
              data,
              d.reference,
            ); // same pattern as BookingPage
            return _MechRow(
              mech: mech,
              mechRef: d.reference,
              userRef: userRef,
              raw: data,
            );
          }).toList();

      setState(() => _mechs = rows);
    } catch (e) {
      _snack('Error loading mechanics: $e');
    } finally {
      if (mounted) setState(() => _loadingMechs = false);
    }
  }

  Future<void> _loadGenres() async {
    setState(() => _loadingGenres = true);

    try {
      final repo = JobRepository();
      final genres = await repo.fetchGenericGenres();
      setState(() => _allGenres = genres);
    } catch (_) {
      // Minimal fallback so the page stays usable even if Firestore genres fail.
      setState(() => _allGenres = _fallbackGenres);
    } finally {
      if (mounted) setState(() => _loadingGenres = false);
    }
  }

  Future<void> _selectMechanic(_MechRow row) async {
    setState(() {
      _selectedMech = row;

      // reset selections
      _selectedGenreName = null;
      _selectedServiceTypeName = null;
      _selectedBrand = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _localBooking = null;
      _localScheduledDate = null;
      _localScheduledTime = null;

      _mechIndexRows = <_ServiceIndexRow>[];
      _loadingMechServices = true;
    });

    await _loadServiceIndexForSelectedMech();
  }

  Future<void> _loadServiceIndexForSelectedMech() async {
    final row = _selectedMech;
    if (row == null) return;

    // We try to query serviceIndex by userRef (because your BookingPage expects mech docs contain userRef).
    // If your index uses a different field, change the where(...) below.
    final userRef = row.userRef;

    if (userRef == null) {
      setState(() => _loadingMechServices = false);
      return;
    }

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection(kServiceIndexCollection)
              .where('userRef', isEqualTo: userRef)
              .get();

      final rows =
          snap.docs
              .map((d) {
                final data = d.data();
                return _ServiceIndexRow(
                  genre: (data['genre'] ?? '').toString(),
                  serviceType: (data['serviceType'] ?? '').toString(),
                  brand: (data['brand'] ?? '').toString(),
                );
              })
              .where((r) => r.genre.isNotEmpty && r.serviceType.isNotEmpty)
              .toList();

      setState(() => _mechIndexRows = rows);
    } catch (e) {
      _snack('Error loading services for mechanic: $e');
    } finally {
      if (mounted) setState(() => _loadingMechServices = false);
    }
  }

  // -------------------------
  // Derived options
  // -------------------------
  List<String> get _availableGenreNames {
    final fromIndex =
        _mechIndexRows.map((r) => r.genre).toSet().toList()..sort();
    if (fromIndex.isNotEmpty) return fromIndex;

    // fallback to global genres
    final fromGlobal = _allGenres.map((g) => g.name).toList()..sort();
    return fromGlobal;
  }

  List<String> get _availableServiceTypeNames {
    final g = _selectedGenreName;
    if (g == null) return const <String>[];

    final fromIndex =
        _mechIndexRows
            .where((r) => r.genre == g)
            .map((r) => r.serviceType)
            .toSet()
            .toList()
          ..sort();

    if (fromIndex.isNotEmpty) return fromIndex;

    // fallback from global genres
    final genreObj = _allGenres
        .where((x) => x.name == g)
        .cast<Genre?>()
        .firstWhere((x) => x != null, orElse: () => null);

    if (genreObj == null) return const <String>[];
    final fromGlobal =
        genreObj.serviceTypes.map((st) => st.name).toList()..sort();
    return fromGlobal;
  }

  List<String> get _availableBrands {
    final g = _selectedGenreName;
    final st = _selectedServiceTypeName;
    if (g == null || st == null) return const <String>[];

    final fromIndex =
        _mechIndexRows
            .where((r) => r.genre == g && r.serviceType == st)
            .map((r) => r.brand)
            .where((b) => b.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (fromIndex.isNotEmpty) return fromIndex;

    // fallback from global genre brands (if your Genre has applicableBrands)
    final genreObj = _allGenres
        .where((x) => x.name == g)
        .cast<Genre?>()
        .firstWhere((x) => x != null, orElse: () => null);

    if (genreObj == null) return const <String>[];
    final fromGlobal = genreObj.applicableBrands.toList()..sort();
    return fromGlobal;
  }

  bool get _brandRequired => _availableBrands.isNotEmpty;

  // -------------------------
  // Availability / slot building
  // -------------------------
  List<TimeRange> _getSlotsForDate(Mech mech, DateTime date) {
    final schedule =
        mech.availability.getSchedule();

    if (schedule == null) return const <TimeRange>[];

    // weekday: 1=Mon ... 7=Sun
    return schedule[date.weekday] ?? const <TimeRange>[];
  }

  int _timeStringToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  String _minutesToHHmm(int mins) {
    final h = (mins ~/ 60).toString().padLeft(2, '0');
    final m = (mins % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  List<String> _expandTimeRangesToSlots(
    List<TimeRange> ranges, {
    int stepMinutes = 30,
  }) {
    final slots = <String>[];

    for (final r in ranges) {
      final start = _timeStringToMinutes(r.start);
      final end = _timeStringToMinutes(r.end);

      // guard
      if (end <= start) continue;

      for (int t = start; t + stepMinutes <= end; t += stepMinutes) {
        slots.add(_minutesToHHmm(t));
      }
    }

    // unique + sorted
    final set =
        slots.toSet().toList()..sort(
          (a, b) => _timeStringToMinutes(a).compareTo(_timeStringToMinutes(b)),
        );
    return set;
  }

  List<String> get _availableTimeSlots {
    final row = _selectedMech;
    final date = _selectedDate;
    if (row == null || date == null) return const <String>[];

    final ranges = _getSlotsForDate(row.mech, date);
    return _expandTimeRangesToSlots(ranges, stepMinutes: 30);
  }

  // -------------------------
  // Create local booking
  // -------------------------
  Future<void> _createLocalBooking() async {
    final row = _selectedMech;
    if (row == null) {
      _snack('Pick a mechanic first.');
      return;
    }

    if (_selectedGenreName == null || _selectedServiceTypeName == null) {
      _snack('Pick a genre and service type.');
      return;
    }

    if (_brandRequired && _selectedBrand == null) {
      _snack('Pick a brand for this service.');
      return;
    }

    if (_selectedDate == null || _selectedTimeSlot == null) {
      _snack('Pick a date and time slot.');
      return;
    }

    // Map names -> real objects (best effort)
    final genreObj = _allGenres.firstWhere(
      (g) => g.name == _selectedGenreName,
      orElse:
          () =>
              Genre(_selectedGenreName!, const [], applicableBrands: const []),
    );

    final stObj = genreObj.serviceTypes.firstWhere(
      (s) => s.name == _selectedServiceTypeName,
      orElse: () => ServiceType(_selectedServiceTypeName!, const []),
    );

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'local_user';
    final mechId = row.userRef?.id ?? row.mechRef.id;

    // NOTE: Job currently doesn't store scheduled date/time in your job.dart.
    // We keep schedule locally in this dev page (and you can later move it into Booking/Job model).
    final job = Job(
      customerId: userId,
      mechanicId: mechId,
      service: Service(
        'Bike Service',
        const [],
      ), // placeholder; adapt if you have a real Service selection
      genre: genreObj,
      serviceType: stObj,
      brand: _brandRequired ? _selectedBrand! : 'N/A',
      status: JobStatus.requested,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final booking = Booking(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      jobStatus: JobStatus.requested,
      paymentStatus: PaymentStatus.noFee,
      job: job,
      mechId: mechId,
      userId: userId,
    );

    setState(() {
      _localBooking = booking;
      _localScheduledDate = _selectedDate;
      _localScheduledTime = _selectedTimeSlot;
    });

    try {
      await JobRepository().backupBooking(booking);
      _snack('Local booking created & backed up ✅');
    } catch (e) {
      _snack('Local booking created, backup failed: $e');
    }
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    const gap = 16.0;

    return MainLayout(
      bodyWidget: Scaffold(
        backgroundColor: kPaper,
        appBar: AppBar(
          title: const Text('Dev Mock Booking'),
          backgroundColor: kPaper,
          elevation: 0,
          foregroundColor: kInk,
        ),
        body: Padding(
          padding: const EdgeInsets.all(gap),
          child: Row(
            children: [
              // LEFT: mechanics list
              Expanded(flex: 3, child: _buildLeftPane()),
              const SizedBox(width: 12),
              // RIGHT: booking builder
              Expanded(flex: 4, child: _buildRightPane()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mechanics (first 10)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => PencilHSeparator(width: c.maxWidth),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PencilPanel(
            padding: const EdgeInsets.all(10),
            child:
                _loadingMechs
                    ? const Center(child: CircularProgressIndicator())
                    : _mechs.isEmpty
                    ? Center(
                      child: Text(
                        'No mechanics found in "$kMechsCollection".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black.withOpacity(0.65)),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _mechs.length,
                      itemBuilder: (context, i) {
                        final row = _mechs[i];
                        final selected =
                            _selectedMech?.mechRef.id == row.mechRef.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: selected ? 1.0 : 0.92,
                            child: Stack(
                              children: [
                                MechPreview(
                                  mech: row.mech,
                                  jobDescription: selected ? 'Selected' : null,
                                  availabilitySummary: _summarizeAvailability(
                                    row.mech,
                                  ),
                                  onTap: () => _selectMechanic(row),
                                ),
                                if (selected)
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPane() {
    final row = _selectedMech;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Build booking',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: kInk,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => PencilHSeparator(width: c.maxWidth),
        ),
        const SizedBox(height: 10),

        Expanded(
          child:
              row == null
                  ? Center(
                    child: Text(
                      'Select a mechanic to start.',
                      style: TextStyle(color: Colors.black.withOpacity(0.65)),
                    ),
                  )
                  : ListView(
                    children: [
                      _buildServicePickerCard(),
                      const SizedBox(height: 12),
                      _buildScheduleCard(row.mech),
                      const SizedBox(height: 12),
                      _buildCreateButtonCard(),
                      const SizedBox(height: 12),
                      _buildLocalBookingPreviewCard(),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildServicePickerCard() {
    return SizedBox(
      height: 170,
      child: PencilPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _pickerSegment(
                label: 'Genre',
                child:
                    _loadingGenres || _loadingMechServices
                        ? const _InlineLoading()
                        : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedGenreName,
                            hint: const Text('Select genre'),
                            items:
                                _availableGenreNames
                                    .map(
                                      (g) => DropdownMenuItem<String>(
                                        value: g,
                                        child: Text(g),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (g) {
                              setState(() {
                                _selectedGenreName = g;
                                _selectedServiceTypeName = null;
                                _selectedBrand = null;
                                _selectedDate = null;
                                _selectedTimeSlot = null;
                                _localBooking = null;
                              });
                            },
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: _pickerSegment(
                label: 'Service Type',
                child:
                    _loadingGenres || _loadingMechServices
                        ? const _InlineLoading()
                        : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedServiceTypeName,
                            hint: const Text('Select service type'),
                            items:
                                _availableServiceTypeNames
                                    .map(
                                      (st) => DropdownMenuItem<String>(
                                        value: st,
                                        child: Text(st),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                _selectedGenreName == null
                                    ? null
                                    : (st) {
                                      setState(() {
                                        _selectedServiceTypeName = st;
                                        _selectedBrand = null;
                                        _selectedDate = null;
                                        _selectedTimeSlot = null;
                                        _localBooking = null;
                                      });
                                    },
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: _pickerSegment(
                label: 'Brand',
                child:
                    _loadingGenres || _loadingMechServices
                        ? const _InlineLoading()
                        : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _brandRequired ? _selectedBrand : 'N/A',
                            hint: Text(_brandRequired ? 'Select brand' : 'N/A'),
                            items:
                                !_brandRequired
                                    ? const [
                                      DropdownMenuItem<String>(
                                        value: 'N/A',
                                        child: Text('N/A'),
                                      ),
                                    ]
                                    : _availableBrands
                                        .map(
                                          (b) => DropdownMenuItem<String>(
                                            value: b,
                                            child: Text(b),
                                          ),
                                        )
                                        .toList(),
                            onChanged:
                                (_selectedServiceTypeName == null ||
                                        !_brandRequired)
                                    ? null
                                    : (b) {
                                      setState(() {
                                        _selectedBrand = b;
                                        _selectedDate = null;
                                        _selectedTimeSlot = null;
                                        _localBooking = null;
                                      });
                                    },
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Mech mech) {
    final dateLabel =
        _selectedDate == null ? 'Pick a date' : _formatDate(_selectedDate!);
    final slots = _availableTimeSlots;

    final canPickDate =
        _selectedGenreName != null &&
        _selectedServiceTypeName != null &&
        (!_brandRequired || _selectedBrand != null);

    return PencilPanel(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedule',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: kInk,
              ),
            ),
            const SizedBox(height: 10),

            Text(
              slots.isEmpty
                  ? 'No time slots (check mechanic availability setup).'
                  : 'Select a time slot:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in slots)
                  ChoiceChip(
                    label: Text(t),
                    selected: _selectedTimeSlot == t,
                    onSelected:
                        _selectedDate == null
                            ? null
                            : (v) {
                              setState(() {
                                _selectedTimeSlot = v ? t : null;
                                _localBooking = null;
                              });
                            },
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(dateLabel)),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: canPickDate ? () => _pickDate(context) : null,
                  child: const Text('Choose date'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButtonCard() {
    final ready =
        _selectedMech != null &&
        _selectedGenreName != null &&
        _selectedServiceTypeName != null &&
        (!_brandRequired || _selectedBrand != null) &&
        _selectedDate != null &&
        _selectedTimeSlot != null;

    return PencilPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ready
                  ? 'Ready to create local booking.'
                  : 'Complete selections to enable booking.',
              style: TextStyle(color: Colors.black.withOpacity(0.7)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: ready ? _createLocalBooking : null,
            child: const Text('Create booking (local)'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalBookingPreviewCard() {
    if (_localBooking == null) {
      return PencilPanel(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No local booking yet.\nPick service + schedule, then tap “Create booking (local)”.',
          style: TextStyle(color: Colors.black.withOpacity(0.7)),
        ),
      );
    }

    final booking = _localBooking!;
    final when =
        (_localScheduledDate == null || _localScheduledTime == null)
            ? '—'
            : '${_formatDate(_localScheduledDate!)} at $_localScheduledTime';

    return PencilPanel(
      padding: const EdgeInsets.all(12),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Local booking preview',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 10),
              Text('booking.id: ${booking.id}'),
              Text('jobStatus: ${booking.jobStatus.name}'),
              Text('paymentStatus: ${booking.paymentStatus.name}'),
              Text('mechId: ${booking.mechId}'),
              Text('userId: ${booking.userId}'),
              const SizedBox(height: 8),
              Text(
                'Service: ${booking.job.genre.name} · ${booking.job.serviceType.name}',
              ),
              Text('Brand: ${booking.job.brand}'),
              Text('When: $when'),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _localBooking = booking.copyWith(
                          paymentStatus: _nextPaymentStatus(booking.paymentStatus),
                        );
                      });
                    },
                    child: const Text('Cycle payment state'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _localBooking = null),
                    child: const Text('Delete local'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickerSegment({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: kInk,
            ),
          ),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: const TextStyle(color: kInk),
            child: child,
          ),
        ],
      ),
    );
  }

  // -------------------------
  // Helpers
  // -------------------------
  String _summarizeAvailability(Mech mech) {
    if (mech.availability.defaultSchedule != WeeklyAvailability.empty()) {
      return 'Availability: ${mech.availability.defaultSchedule.title}';
    }
    if (mech.availability.isNotEmpty) {
      return 'Availability: ${mech.availability.getSchedule().title}';
    }
    return 'Availability varies';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null;
        _localBooking = null;
      });
    }
  }

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  PaymentStatus _nextPaymentStatus(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.noFee:
        return PaymentStatus.feePaid;
      case PaymentStatus.feePaid:
        return PaymentStatus.waitingPayment;
      case PaymentStatus.waitingPayment:
        return PaymentStatus.paid;
      case PaymentStatus.paid:
        return PaymentStatus.refunded;
      case PaymentStatus.refunded:
        return PaymentStatus.noFee;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------------------------------------------------------
// Internal helper classes (keeps this page independent)
// ---------------------------------------------------------
class _MechRow {
  final Mech mech;
  final DocumentReference mechRef;
  final DocumentReference? userRef;
  final Map<String, dynamic> raw;

  const _MechRow({
    required this.mech,
    required this.mechRef,
    required this.userRef,
    required this.raw,
  });
}

class _ServiceIndexRow {
  final String genre;
  final String serviceType;
  final String brand;

  const _ServiceIndexRow({
    required this.genre,
    required this.serviceType,
    required this.brand,
  });
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Loading...'),
      ],
    );
  }
}

// Minimal fallback if fetchGenericGenres fails
final List<Genre> _fallbackGenres = <Genre>[
  Genre(
    'Brakes',
    [
      ServiceType('Brake Bleed', ['Shimano', 'SRAM', 'Tektro']),
      ServiceType('Pad Replacement', ['Shimano', 'SRAM', 'Tektro']),
      ServiceType('Disc Replacement', ['Shimano', 'SRAM', 'Tektro']),
    ],
    applicableBrands: ['Shimano', 'SRAM', 'Tektro'],
  ),
  Genre(
    'Drivetrain',
    [
      ServiceType('Chain Replacement', ['Shimano', 'SRAM']),
      ServiceType('Cassette Replacement', ['Shimano', 'SRAM']),
      ServiceType('Derailleur Adjustment', ['Shimano', 'SRAM', 'Microshift']),
    ],
    applicableBrands: ['Shimano', 'SRAM', 'Microshift'],
  ),
  Genre(
    'Suspension',
    [
      ServiceType('Fork Service', ['Fox', 'RockShox', 'Öhlins']),
      ServiceType('Shock Service', ['Fox', 'RockShox', 'Öhlins']),
    ],
    applicableBrands: ['Fox', 'RockShox', 'Öhlins'],
  ),
];
