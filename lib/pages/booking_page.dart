import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app1/pages/home_page.dart';
import 'package:app1/models/service_options.dart';
import 'package:app1/provider/service_provider.dart';
import 'package:app1/repositories/job_repository.dart';
import 'package:app1/models/user_model.dart';
import 'package:app1/models/timeslot_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

    // Fallback to dev dummy genres if Firestore is empty or fails
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
  DateTime? _selectedDate; // null = "any day" for now
  String? _selectedTime; // null = "any time"

  // Search results
  List<Mech> _availableMechs = <Mech>[];
  List<Mech> _otherMechs = <Mech>[];
  bool _isSearching = false;

  List<ServiceType> get _availableServiceTypes =>
      _selectedGenre?.serviceTypes ?? const <ServiceType>[];

  // Use the generic genre's applicableBrands; service types are generic and don't hold brands.
  List<String> get _availableBrands =>
      _selectedGenre?.applicableBrands ?? const <String>[];

  // Brand is only required if the genre actually has applicable brands.
  bool get _brandRequired => _availableBrands.isNotEmpty;

  bool get _hasCompleteSelection =>
      _selectedGenre != null &&
      _selectedServiceType != null &&
      (!_brandRequired || _selectedBrand != null);

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
    final schedule = mech.defaultWeek;
    if (schedule == null) return const <TimeRange>[];

    final weekday = date.weekday; // 1=Mon ... 7=Sun
    return schedule.days[weekday] ?? const <TimeRange>[];
  }

  bool _isAvailableFor(Mech mech, DateTime date, int? latestTimeMinutes) {
    final slots = _getSlotsForDate(mech, date);
    if (slots.isEmpty) return false;

    // No time given -> any slot on that date works
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
    if (slots.isEmpty) return 24 * 60; // end of day
    return slots
        .map((r) => _timeStringToMinutes(r.start))
        .reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final gap = 16.0;

    return MainLayout(
      bodyWidget: Scaffold(
        appBar: AppBar(title: const Text('Find a Mechanic')),
        body: Padding(
          padding: EdgeInsets.all(gap),
          child: Column(
            children: [
              // Airbnb-style search bar
              _buildSearchBar(context),
              const SizedBox(height: 12),

              // Main split view: left results, right map
              Expanded(
                child: Row(
                  children: [
                    // Left: results list
                    Expanded(flex: 3, child: _buildResultsPane()),
                    const SizedBox(width: 12),
                    // Right: map / location card
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
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            _divider(),
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
            _divider(),
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
            _divider(),
            // Date
            Expanded(
              flex: 2,
              child: _searchSegment(
                label: 'Date',
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
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
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  _selectedDate == null
                                      ? Colors.grey.shade600
                                      : theme.textTheme.bodyMedium?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _divider(),
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
            const SizedBox(width: 8),
            // Search button
            FilledButton.icon(
              onPressed: _isSearching ? null : () => _onSubmitBooking(context),
              icon: const Icon(Icons.search),
              label: const Text('Search'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchSegment({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.grey.shade300);

  // ===== Left pane: results / summary =====

  Widget _buildResultsPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search results',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
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
                        color: Colors.grey.shade700,
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
                            fontWeight: FontWeight.bold,
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Other mechanics (not available at this time)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(child: Divider()),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Selection',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _summaryRow(label: 'Category', value: genre),
          _summaryRow(label: 'Service', value: st),
          _summaryRow(label: 'Brand', value: brand),
          _summaryRow(label: 'Date', value: date),
          _summaryRow(label: 'Time', value: time),
        ],
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isMissing ? Colors.grey.shade600 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Right pane: map card =====

  Widget _buildMapPane() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              color: Colors.blueGrey.shade100.withOpacity(0.5),
              alignment: Alignment.center,
              child: Icon(
                Icons.map_outlined,
                size: 80,
                color: Colors.blueGrey.shade400,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.place, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Map preview (mechanic locations coming soon)',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers =====

  String _buildJobDescription() {
    if (_selectedGenre == null || _selectedServiceType == null) {
      return 'No service selected';
    }

    final base = '${_selectedGenre!.name} · ${_selectedServiceType!.name}';

    if (!_brandRequired) {
      return '$base • Any brand';
    }
    if (_selectedBrand == null) {
      return base;
    }
    return '$base • ${_selectedBrand}';
  }

  String _summarizeAvailability(Mech mech) {
    if (mech.defaultWeek != null) {
      return 'Availability: ${mech.defaultWeek!.title}';
    }
    if (mech.availabilities.isNotEmpty) {
      return 'Availability: ${mech.availabilities.first.title}';
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
      });
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
      final hasSpecificDate = _selectedDate != null;

      final brandForQuery = _brandRequired ? _selectedBrand! : '';

      final jobRepo = JobRepository();

      // First-level query: service indices (genre, serviceType, brand).
      final mechRefs = await jobRepo.queryIndiciesWithOptions(
        _selectedGenre!.name,
        _selectedServiceType!.name,
        brandForQuery,
      );

      // Load full Mech docs from refs.
      final mechSnapshots = await Future.wait(mechRefs.map((ref) => ref.get()));

      final mechs =
          mechSnapshots.where((snap) => snap.exists).map((snap) {
            final data = snap.data() as Map<String, dynamic>;
            final userRef = data['userRef'] as DocumentReference?;
            return Mech.fromMap(data, userRef ?? snap.reference);
          }).toList();

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

        // sort available by earliest slot
        available.sort(
          (a, b) => _earliestAvailableStart(
            a,
            _selectedDate!,
          ).compareTo(_earliestAvailableStart(b, _selectedDate!)),
        );

        // sort others by name (or whatever)
        other.sort((a, b) => a.name.compareTo(b.name));
      } else {
        // No date → everyone goes into available list, no separator section
        available = mechs;
      }

      setState(() {
        _availableMechs = available;
        _otherMechs = other;
      });

      final brandText = _brandRequired ? _selectedBrand : 'N/A';
      final dateText =
          hasSpecificDate ? _formatDate(_selectedDate!) : 'Any day';
      final timeText = _selectedTime ?? 'Any time';

      final msg =
          'Found ${mechs.length} mechanics for:\n'
          '- ${_selectedGenre!.name} / ${_selectedServiceType!.name}\n'
          '- Brand: $brandText\n'
          '- Date: $dateText\n'
          '- Time: $timeText\n'
          'Showing available mechanics first.';

      _snack(context, msg);
    } catch (e) {
      _snack(context, 'Error searching mechanics: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
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

/// Reusable mechanic preview widget used across the app.
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left icon / image
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pedal_bike,
                  size: 32,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 10),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: name + rating/experience
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            mech.name,
                            // You can later override this with real name/shop.
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              mech.rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${mech.completedJobs} jobs)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Job description (searched job)
                    if (jobDescription != null &&
                        jobDescription!.isNotEmpty) ...[
                      Text(
                        jobDescription!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    // Qualifications / bio
                    Text(
                      mech.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Availability summary
                    if (availabilitySummary != null &&
                        availabilitySummary!.isNotEmpty)
                      Text(
                        availabilitySummary!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              // Optional trailing widget (e.g., price, button)
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
