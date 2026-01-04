import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app1/pages/home_page.dart';
import 'package:app1/models/service_options.dart';
import 'package:app1/repositories/job_repository.dart';
import 'package:app1/models/user_model.dart';
import 'package:app1/models/timeslot_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =====================
// Hand-drawn theme bits
// =====================

const Color kPaper = Color.fromARGB(255, 255, 255, 255);
const Color kPaper2 = Color.fromARGB(255, 255, 255, 255);
const Color kInk = Color(0xFF1A1A1A);

class PencilPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool expanded;
  final bool drawTop, drawRight, drawBottom, drawLeft;

  const PencilPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.expanded = true,
    this.drawTop = true,
    this.drawRight = true,
    this.drawBottom = true,
    this.drawLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w =
            c.maxWidth.isFinite
                ? c.maxWidth
                : MediaQuery.of(context).size.width;
        final h = expanded ? null : (c.maxHeight.isFinite ? c.maxHeight : 120.0);

        // PencilBox / PencilLine / DrawnButton come from your existing codebase
        // (you already use them in MainLayout/HomePage).
        return PencilBox(
          width: w,
          height: h ?? (c.maxHeight.isFinite ? c.maxHeight : 120.0),
          padding: padding,
          expanded: expanded,
          wobbleHeight: 8,
          strokeWidth: 2,
          color: kInk,
          drawTop: drawTop,
          drawRight: drawRight,
          drawBottom: drawBottom,
          drawLeft: drawLeft,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: kPaper2),
            child: child,
          ),
        );
      },
    );
  }
}

class PencilVSeparator extends StatelessWidget {
  final double height;
  const PencilVSeparator({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 1,
      child: PencilLine(width: height, height: 8, color: Colors.black87),
    );
  }
}

class PencilHSeparator extends StatelessWidget {
  final double width;
  const PencilHSeparator({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    return PencilLine(width: width, height: 10, color: Colors.black87);
  }
}

class BookingPage extends StatefulWidget {
  final List<Genre> allGenres;

  const BookingPage({super.key, required this.allGenres});

  /// Open from anywhere. Uses Firestore genres via JobRepository.
  static Future<void> open(BuildContext context) async {
    final jobRepo = JobRepository();

    List<Genre> genres;
    try {
      genres = await jobRepo.fetchGenericGenres();
    } catch (_) {
      genres = const [];
    }

    if (genres.isEmpty) {
      genres = _devDummyGenres;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BookingPage(allGenres: genres)));
  }

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  // Local selection state
  Genre? _selectedGenre;
  ServiceType? _selectedServiceType;
  String? _selectedBrand;
  DateTime? _selectedDate; // null = any day
  String? _selectedTime; // null = any time

  // Search results
  List<Mech> _availableMechs = <Mech>[];
  List<Mech> _otherMechs = <Mech>[];
  bool _isSearching = false;

  List<ServiceType> get _availableServiceTypes =>
      _selectedGenre?.serviceTypes ?? const <ServiceType>[];

  List<String> get _availableBrands =>
      _selectedGenre?.applicableBrands ?? const <String>[];

  bool get _brandRequired => _availableBrands.isNotEmpty;

  // ===== Availability helpers =====

  int _timeStringToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  int? _parseSelectedTimeToMinutes(String? time) {
    if (time == null || time.trim().isEmpty) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  List<TimeRange> _getSlotsForDate(Mech mech, DateTime date) {
    final schedule = mech.availability.getSchedule();

    final weekday = date.weekday; // 1=Mon ... 7=Sun
    return schedule[weekday] ?? const <TimeRange>[];
  }

  bool _isAvailableFor(Mech mech, DateTime date, int? latestTimeMinutes) {
    final slots = _getSlotsForDate(mech, date);
    if (slots.isEmpty) return false;

    if (latestTimeMinutes == null) return true;

    for (final range in slots) {
      final start = _timeStringToMinutes(range.start);
      final end = _timeStringToMinutes(range.end);
      if (start <= latestTimeMinutes && latestTimeMinutes <= end) {
        return true;
      }
    }
    return false;
  }

  int _earliestAvailableStart(Mech mech, DateTime date) {
    final slots = _getSlotsForDate(mech, date);
    if (slots.isEmpty) return 24 * 60;
    return slots
        .map((r) => _timeStringToMinutes(r.start))
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;

    return MainLayout(
      bodyWidget: Scaffold(
        backgroundColor: kPaper,
        appBar: AppBar(
          title: const Text('Find a Mechanic'),
          backgroundColor: kPaper,
          elevation: 0,
          foregroundColor: kInk,
        ),
        body: Padding(
          padding: const EdgeInsets.all(gap),
          child: Column(
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildResultsPane()),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildMapPane()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Top search bar =====

  Widget _buildSearchBar(BuildContext context) {
    return SizedBox(
      height: 86,
      child: PencilPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        expanded: true,
        child: Row(
          children: [
            // Category
            Expanded(
              flex: 3,
              child: _searchSegment(
                label: 'Category',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Genre>(
                    isExpanded: true,
                    value: _selectedGenre,
                    hint: const Text('Select category'),
                    items:
                        widget.allGenres
                            .map(
                              (g) => DropdownMenuItem<Genre>(
                                value: g,
                                child: Text(g.name),
                              ),
                            )
                            .toList(),
                    onChanged: (g) {
                      setState(() {
                        _selectedGenre = g;
                        _selectedServiceType = null;
                        _selectedBrand = null;
                        _availableMechs = <Mech>[];
                        _otherMechs = <Mech>[];
                      });
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),
            const PencilVSeparator(height: 48),
            const SizedBox(width: 6),

            // Service type
            Expanded(
              flex: 3,
              child: _searchSegment(
                label: 'Service',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ServiceType>(
                    isExpanded: true,
                    value: _selectedServiceType,
                    hint: const Text('Add service'),
                    items:
                        _availableServiceTypes
                            .map(
                              (st) => DropdownMenuItem<ServiceType>(
                                value: st,
                                child: Text(st.name),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (_selectedGenre == null)
                            ? null
                            : (st) {
                              setState(() {
                                _selectedServiceType = st;
                                _selectedBrand = null;
                                _availableMechs = <Mech>[];
                                _otherMechs = <Mech>[];
                              });
                            },
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),
            const PencilVSeparator(height: 48),
            const SizedBox(width: 6),

            // Brand
            Expanded(
              flex: 3,
              child: _searchSegment(
                label: 'Brand',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _availableBrands.isEmpty ? 'N/A' : _selectedBrand,
                    hint: Text(_availableBrands.isEmpty ? 'N/A' : 'Add brand'),
                    items:
                        _availableBrands.isEmpty
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
                        (_selectedServiceType == null ||
                                _availableBrands.isEmpty)
                            ? null
                            : (b) {
                              setState(() {
                                _selectedBrand = b;
                                _availableMechs = <Mech>[];
                                _otherMechs = <Mech>[];
                              });
                            },
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),
            const PencilVSeparator(height: 48),
            const SizedBox(width: 6),

            // Date
            Expanded(
              flex: 2,
              child: _searchSegment(
                label: 'Date',
                child: InkWell(
                  onTap: () => _pickDate(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? 'Any day'
                                : _formatDate(_selectedDate!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),
            const PencilVSeparator(height: 48),
            const SizedBox(width: 6),

            // Time (typed)
            Expanded(
              flex: 2,
              child: _searchSegment(
                label: 'Time',
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Any time',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      final trimmed = value.trim();
                      _selectedTime = trimmed.isEmpty ? null : trimmed;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Search button (drawn)
            DrawnButton(
              size: const Size(110, 34),
              onClick: _isSearching ? null : () => _onSubmitBooking(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.search, size: 16),
                  SizedBox(width: 6),
                  Text('Search'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchSegment({required String label, required Widget child}) {
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
          DefaultTextStyle.merge(
            style: const TextStyle(color: kInk),
            child: child,
          ),
        ],
      ),
    );
  }

  // ===== Left pane: results / summary =====

  Widget _buildResultsPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search results',
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

        _selectionSummary(),
        const SizedBox(height: 12),

        Expanded(
          child:
              _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : (_availableMechs.isEmpty && _otherMechs.isEmpty)
                  ? Center(
                    child: Text(
                      'No mechanics found yet.\nSet your filters and tap Search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.65),
                      ),
                    ),
                  )
                  : ListView(
                    children: [
                      if (_availableMechs.isNotEmpty) ...[
                        const Text(
                          'Available at selected time',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: kInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._availableMechs.map((mech) {
                          final jobDesc = _buildJobDescription();
                          final availabilitySummary = _summarizeAvailability(
                            mech,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MechPreview(
                              mech: mech,
                              jobDescription: jobDesc,
                              availabilitySummary: availabilitySummary,
                              onTap: () {
                                // TODO: push to mechanic detail / booking flow
                              },
                            ),
                          );
                        }),
                      ],
                      if (_availableMechs.isNotEmpty && _otherMechs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder:
                                    (context, c) =>
                                        PencilHSeparator(width: c.maxWidth),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Other mechanics (not available at this time)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder:
                                    (context, c) =>
                                        PencilHSeparator(width: c.maxWidth),
                              ),
                            ],
                          ),
                        ),
                      if (_otherMechs.isNotEmpty) ...[
                        ..._otherMechs.map((mech) {
                          final jobDesc = _buildJobDescription();
                          final availabilitySummary = _summarizeAvailability(
                            mech,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MechPreview(
                              mech: mech,
                              jobDescription: jobDesc,
                              availabilitySummary: availabilitySummary,
                              onTap: () {
                                // TODO: push to mechanic detail / booking flow
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _selectionSummary() {
    final genre = _selectedGenre?.name ?? 'Not selected';
    final st = _selectedServiceType?.name ?? 'Not selected';
    final brand = !_brandRequired ? 'N/A' : (_selectedBrand ?? 'Not selected');
    final date =
        _selectedDate != null ? _formatDate(_selectedDate!) : 'Any day';
    final time = _selectedTime ?? 'Any time';

    return SizedBox(
      height: 140,
      child: PencilPanel(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Selection',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 8),
              _summaryRow(label: 'Category', value: genre),
              _summaryRow(label: 'Service', value: st),
              _summaryRow(label: 'Brand', value: brand),
              _summaryRow(label: 'Date', value: date),
              _summaryRow(label: 'Time', value: time),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow({required String label, required String value}) {
    final isMissing = value == 'Not selected';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isMissing ? Colors.black.withOpacity(0.55) : kInk,
                fontWeight: isMissing ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Right pane: map card =====

  Widget _buildMapPane() {
    return PencilPanel(
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.map_outlined,
              size: 88,
              color: Colors.black.withOpacity(0.25),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 30,
              child: PencilPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                drawBottom: false,
                drawLeft: false,
                drawRight: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.place, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Map preview (mechanic locations coming soon)',
                      style: TextStyle(fontSize: 11, color: kInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Helpers =====

  String _buildJobDescription() {
    if (_selectedGenre == null || _selectedServiceType == null) {
      return 'No service selected';
    }

    final base = '${_selectedGenre!.name} · ${_selectedServiceType!.name}';

    if (!_brandRequired) return '$base • Any brand';
    if (_selectedBrand == null) return base;
    return '$base • $_selectedBrand';
  }

  String _summarizeAvailability(Mech mech) {
    return 'Availability: ${mech.availability.getSchedule().title}';
      if (mech.availability.getSchedule().days.isNotEmpty) {
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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _onSubmitBooking(BuildContext context) async {
    if (_selectedGenre == null || _selectedServiceType == null) {
      _snack(context, 'Please choose a category and service type first.');
      return;
    }

    if (_brandRequired && _selectedBrand == null) {
      _snack(context, 'Please pick a brand for this service.');
      return;
    }

    setState(() {
      _isSearching = true;
      _availableMechs = <Mech>[];
      _otherMechs = <Mech>[];
    });

    try {
      final brandForQuery = _brandRequired ? _selectedBrand! : '';
      final jobRepo = JobRepository();

      final mechRefs = await jobRepo.queryIndiciesWithOptions(
        _selectedGenre!.name,
        _selectedServiceType!.name,
        brandForQuery,
      );
      final mechs = <Mech>[];
      for (final mechRef in mechRefs) {
        final snap = await mechRef.get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          final userRef = data['userRef'] as DocumentReference?;
          if (userRef == null) {
            throw 'Mechanic index missing userRef field';
          }

          mechs.add(Mech.fromMap(data, mechRef));
        }
      }

      final selectedTimeMinutes = _parseSelectedTimeToMinutes(_selectedTime);

      List<Mech> available = <Mech>[];
      List<Mech> other = <Mech>[];

      if (_selectedDate != null) {
        for (final mech in mechs) {
          if (_isAvailableFor(mech, _selectedDate!, selectedTimeMinutes)) {
            available.add(mech);
          } else {
            other.add(mech);
          }
        }

        available.sort(
          (a, b) => _earliestAvailableStart(
            a,
            _selectedDate!,
          ).compareTo(_earliestAvailableStart(b, _selectedDate!)),
        );

        other.sort((a, b) => a.name.compareTo(b.name));
      } else {
        available = mechs;
      }

      setState(() {
        _availableMechs = available;
        _otherMechs = other;
      });

      _snack(context, 'Found ${mechs.length} mechanics');
    } catch (e) {
      _snack(context, 'Error searching mechanics: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// Dummy genres for dev when Firestore genres not loaded yet.
final List<Genre> _devDummyGenres = <Genre>[
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

/// Reusable mechanic preview widget used across the app (hand-drawn style).
class MechPreview extends StatelessWidget {
  final Mech mech;
  final String? jobDescription;
  final String? availabilitySummary;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MechPreview({
    super.key,
    required this.mech,
    this.jobDescription,
    this.availabilitySummary,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: InkWell(
        onTap: onTap,
        child: PencilPanel(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 58,
                child: PencilPanel(
                  padding: const EdgeInsets.all(8),
                  child: const Center(
                    child: Icon(
                      Icons.pedal_bike,
                      size: 28,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mech.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: kInk,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          mech.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, color: kInk),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${mech.completedJobs} jobs)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (jobDescription != null &&
                        jobDescription!.isNotEmpty) ...[
                      Text(
                        jobDescription!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      mech.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withOpacity(0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (availabilitySummary != null &&
                        availabilitySummary!.isNotEmpty)
                      Text(
                        availabilitySummary!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.62),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
