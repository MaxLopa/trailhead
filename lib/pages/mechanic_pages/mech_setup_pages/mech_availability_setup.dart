import 'package:app1/models/timeslot_model.dart';
import 'package:app1/pages/home_page.dart';
import 'package:app1/provider/main_app_provider.dart';
import 'package:app1/provider/mech_provider.dart';
import 'package:app1/repositories/mech_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Implement a snackmessage/popup for when the user clicks save but doens't have a default selected

class _RangeField {
  final TextEditingController start;
  final TextEditingController end;
  _RangeField(this.start, this.end);
}

class MechAvailabilitySetupPage extends StatefulWidget {
  const MechAvailabilitySetupPage({super.key});

  // Open only if logged in / mech loaded
  static Future<void> open(
    BuildContext context,
    AppState appState,
    MechRepository repo,
  ) async {
    // TODO: make so also checks for mechanic existence
    if (!appState.loggedIn()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be logged in as a mechanic to edit availability.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MechAvailabilitySetupPage()),
    );
  }

  @override
  State<MechAvailabilitySetupPage> createState() =>
      _MechAvailabilitySetupPageState();
}

class _MechAvailabilitySetupPageState extends State<MechAvailabilitySetupPage> {
  final ScrollController _leftPaneCtl = ScrollController();
  final ScrollController _rightPaneCtl = ScrollController();

  final TextEditingController _templateNameCtl = TextEditingController();
  final TextEditingController _startCtl = TextEditingController(text: '');
  final TextEditingController _endCtl = TextEditingController(text: '');
  final List<_RangeField> _extraRangeFields = [];

  late Map<int, List<TimeRange>> _draftDays;
  final List<WeeklyAvailability> _savedWeeks = [];
  final List<WkOverride> _overrides = [];
  int? _defaultWeekIndex;
  int? _selectedWeekday;
  bool _initialized = false;

  bool _initializedFromProvider = false;

  // Calendar State
  DateTime _viewDate = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  int? _selectedOverrideScheduleIndex;

  final List<Color> _overrideColors = [
    Colors.orange.shade300,
    Colors.teal.shade300,
    Colors.purple.shade300,
    Colors.pink.shade300,
    Colors.amber.shade300,
  ];

  @override
  void initState() {
    super.initState();
    _draftDays = {for (var i = 1; i <= 7; i++) i: <TimeRange>[]};
    _templateNameCtl.text = 'Week Template 1';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromProvider) return;

    final mechProvider = context.read<MechProvider>();
    final existing = mechProvider.getAvailabilities();
    final defaultWeek = mechProvider.getDefaultWeek();

    setState(() {
      _savedWeeks.clear();
      _savedWeeks.addAll(existing);

      // Auto-select the default template if we have one and at least one saved week
      if (defaultWeek != null && existing.isNotEmpty) {
        for (var i = 0; i < existing.length; i++) {
          if (_areWeeksEqual(existing[i], defaultWeek)) {
            _defaultWeekIndex = i;
            break;
          }
        }
      }
    });

    _initializedFromProvider = true;
  }

  @override
  void dispose() {
    _leftPaneCtl.dispose();
    _rightPaneCtl.dispose();
    _templateNameCtl.dispose();
    _startCtl.dispose();
    _endCtl.dispose();
    for (final f in _extraRangeFields) {
      f.start.dispose();
      f.end.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gap = 16.0;
    final w = MediaQuery.of(context).size.width;
    final half = (w - gap * 3) / 2;

    return MainLayout(
      bodyWidget: Scaffold(
        appBar: AppBar(title: const Text('Mechanic Availability Setup')),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: half, child: _buildLeftPane(gap)),
                  SizedBox(width: gap),
                  SizedBox(width: half, child: _buildRightPane(gap)),
                ],
              ),
            ),
            // _buildCalendarOverrideSection(gap),
          ],
        ),
      ),
    );
  }

  // ===== Left (editor) =====
  Widget _buildLeftPane(double gap) {
    final editingLabel =
        _selectedWeekday == null ? 'None' : _weekdayName(_selectedWeekday!);

    return Card(
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: Scrollbar(
          controller: _leftPaneCtl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _leftPaneCtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _templateNameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Availability name',
                    hintText: 'e.g. Winter Hours',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _sectionTitle('Days of week'),
                const SizedBox(height: 6),
                _weekdayCardRow(),
                const SizedBox(height: 12),
                Text(
                  'Editing: $editingLabel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Hours for this day: '),
                    Text(
                      _durationLabel() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _handleAddTimeslotPressed,
                      icon: const Icon(Icons.add),
                      tooltip: 'Add another range row',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _rangeRowsEditor(),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _applyToSelectedDay,
                    child: const Text('Apply'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _finishWeekTemplate,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Finish week template'),
                  ),
                ),
                const SizedBox(height: 24),

                // ===== Presets section =====
                _sectionTitle('Start from preset'),
                const SizedBox(height: 8),
                if (WeeklyAvailability.presets.isEmpty)
                  const Text(
                    'No presets configured.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(WeeklyAvailability.presets.length, (
                      i,
                    ) {
                      final preset = WeeklyAvailability.presets[i];
                      final title =
                          preset.title.isEmpty
                              ? 'Preset ${i + 1}'
                              : preset.title;
                      return OutlinedButton(
                        onPressed: () => _loadPresetIntoEditor(preset),
                        child: Text(title),
                      );
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weekdayCardRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (index) {
          final weekday = index + 1;
          final selected = _selectedWeekday == weekday;
          final ranges = _draftDays[weekday] ?? [];
          final label = _weekdayShort(weekday);
          final subtitle =
              ranges.isEmpty
                  ? 'Off'
                  : ranges.map((r) => '${r.start}–${r.end}').join(', ');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (!selected) {
                    _selectedWeekday = weekday;
                    _loadDayIntoEditor(weekday);
                  } else {
                    _selectedWeekday = null;
                    _clearEditorFields();
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? Colors.blue.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _rangeRowsEditor() {
    return Column(
      children: [
        _rangeRow(_startCtl, _endCtl),
        ..._extraRangeFields.map(
          (f) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _rangeRow(f.start, f.end),
          ),
        ),
      ],
    );
  }

  Widget _rangeRow(
    TextEditingController startCtl,
    TextEditingController endCtl,
  ) {
    return Row(
      children: [
        Expanded(child: _hhmmField(label: 'Start (24h)', controller: startCtl)),
        const SizedBox(width: 8),
        const Icon(Icons.schedule, size: 18),
        const SizedBox(width: 8),
        Expanded(child: _hhmmField(label: 'End (24h)', controller: endCtl)),
      ],
    );
  }

  Widget _hhmmField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:mm',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      keyboardType: TextInputType.datetime,
    );
  }

  void _handleAddTimeslotPressed() {
    setState(() {
      _extraRangeFields.add(
        _RangeField(TextEditingController(), TextEditingController()),
      );
    });
  }

  void _loadDayIntoEditor(int weekday) {
    final ranges = _draftDays[weekday] ?? [];

    _clearEditorFields(keepSelection: true);

    if (ranges.isEmpty) return;

    _startCtl.text = ranges.first.start;
    _endCtl.text = ranges.first.end;

    for (final r in ranges.skip(1)) {
      _extraRangeFields.add(
        _RangeField(
          TextEditingController(text: r.start),
          TextEditingController(text: r.end),
        ),
      );
    }
  }

  void _applyToSelectedDay() {
    if (_selectedWeekday == null) {
      _snack('Select a day to edit.');
      return;
    }

    final ranges = _buildRangesFromFields(strict: true);
    if (ranges == null) {
      _snack('Enter valid non-empty ranges in HH:mm (24h).');
      return;
    }
    if (ranges.isEmpty) {
      _snack('Add at least one time range.');
      return;
    }

    setState(() {
      _draftDays[_selectedWeekday!] = List<TimeRange>.from(ranges);
      _resetEditorPanel();
    });

    _snack('Applied to ${_weekdayName(_selectedWeekday!)}.');
  }

  void _finishWeekTemplate() {
    final hasAny = _draftDays.values.any((list) => list.isNotEmpty);
    if (!hasAny) {
      _snack('Set availability for at least one day.');
      return;
    }

    final name =
        _templateNameCtl.text.trim().isEmpty
            ? 'Week Template ${_savedWeeks.length + 1}'
            : _templateNameCtl.text.trim();

    final nonEmptyDays = <int, List<TimeRange>>{};
    _draftDays.forEach((k, v) {
      if (v.isNotEmpty) nonEmptyDays[k] = List<TimeRange>.from(v);
    });

    final week = WeeklyAvailability(nonEmptyDays, title: name);

    setState(() {
      _savedWeeks.add(week);
      _draftDays = {for (var i = 1; i <= 7; i++) i: <TimeRange>[]};
      _templateNameCtl.text = 'Week Template ${_savedWeeks.length + 1}';
      _resetEditorPanel();
    });

    _snack('Saved "$name".');
  }

  void _clearEditorFields({bool keepSelection = false}) {
    _startCtl.clear();
    _endCtl.clear();
    for (final f in _extraRangeFields) {
      f.start.dispose();
      f.end.dispose();
    }
    _extraRangeFields.clear();
    if (!keepSelection) {
      _selectedWeekday = null;
    }
  }

  void _resetEditorPanel() {
    _clearEditorFields(keepSelection: false);
  }

  // Load a preset into the current draft so user can tweak + save as their own.
  void _loadPresetIntoEditor(WeeklyAvailability preset) {
    final cloned = <int, List<TimeRange>>{};
    for (var day = 1; day <= 7; day++) {
      final ranges = preset.days[day] ?? const <TimeRange>[];
      cloned[day] = List<TimeRange>.from(ranges);
    }

    setState(() {
      _draftDays = cloned;
      _templateNameCtl.text =
          preset.title.isEmpty ? 'Preset Template' : preset.title;
      _resetEditorPanel();
    });

    _snack(
      'Loaded preset "${preset.title.isEmpty ? 'Preset' : preset.title}". '
      'Click a day to edit its hours.',
    );
  }

  // ===== Right (display) =====
  Widget _buildRightPane(double gap) {
    return Consumer2<MechProvider, MechRepository>(
      builder: (context, provider, repo, _) {
        return Card(
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _paneHeader(
                  title: 'Saved Week Templates',
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _confirmResetAll,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Reset All'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _onSavePressed(provider, repo),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Scrollbar(
                    controller: _rightPaneCtl,
                    thumbVisibility: true,
                    child:
                        _savedWeeks.isEmpty
                            ? SingleChildScrollView(
                              controller: _rightPaneCtl,
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Text(
                                    'No templates yet. Create one on the left.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ),
                            )
                            : ListView.builder(
                              controller: _rightPaneCtl,
                              itemCount: _savedWeeks.length,
                              itemBuilder: (context, i) {
                                final week = _savedWeeks[i];
                                final groups = _groupWeekByRanges(week);

                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _onTemplateTap(week),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Radio<int>(
                                              value: i,
                                              groupValue: _defaultWeekIndex,
                                              onChanged: (val) {
                                                setState(() {
                                                  _defaultWeekIndex = val;
                                                });
                                              },
                                            ),
                                            Expanded(
                                              child: Text(
                                                week.title.isEmpty
                                                    ? 'Week Template ${i + 1}'
                                                    : week.title,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                              ),
                                              tooltip: 'Delete this template',
                                              onPressed:
                                                  () =>
                                                      _confirmDeleteTemplate(i),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children:
                                                groups.map((g) {
                                                  final startDay = g.$1;
                                                  final endDay = g.$2;
                                                  final ranges = g.$3;
                                                  final label =
                                                      startDay == endDay
                                                          ? _weekdayShort(
                                                            startDay,
                                                          )
                                                          : '${_weekdayShort(startDay)}–${_weekdayShort(endDay)}';

                                                  return Container(
                                                    width: 180,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.black12,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          label,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        if (ranges.isEmpty)
                                                          const Text(
                                                            'Off',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors
                                                                      .black54,
                                                            ),
                                                          )
                                                        else
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children:
                                                                ranges.map((r) {
                                                                  return Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          bottom:
                                                                              4,
                                                                        ),
                                                                    child: _pill(
                                                                      '${r.start} → ${r.end}',
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
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
            ),
          ),
        );
      },
    );
  }

  void _onSavePressed(MechProvider provider, MechRepository repo) {
    if ((_defaultWeekIndex! < 0 || _defaultWeekIndex! >= _savedWeeks.length) &&
        _savedWeeks.isNotEmpty) {
      _snack('Select a default schedule before saving.');
      return;
    }

    final defaultWeek = _savedWeeks[_defaultWeekIndex!];

    provider.updateAvailability(_savedWeeks, defaultWeek, repo);

    _snack('Saved week templates');
    Navigator.of(context).pop();
  }

  void _onTemplateTap(WeeklyAvailability week) {
    // Only allow editing if we're not in the middle of editing another draft
    if (_hasDraftChanges()) {
      _snack('Finish or clear the current template before editing another.');
      return;
    }

    final cloned = <int, List<TimeRange>>{};
    for (var day = 1; day <= 7; day++) {
      final ranges = week.days[day] ?? const <TimeRange>[];
      cloned[day] = List<TimeRange>.from(ranges);
    }

    setState(() {
      _clearEditorFields(keepSelection: false);
      _draftDays = cloned;
      _templateNameCtl.text = week.title.isEmpty ? 'Week Template' : week.title;
    });

    _snack('Loaded template into editor on the left.');
  }

  bool _hasDraftChanges() {
    final anyDraftDays = _draftDays.values.any((list) => list.isNotEmpty);
    final anyTextFields =
        _startCtl.text.trim().isNotEmpty ||
        _endCtl.text.trim().isNotEmpty ||
        _extraRangeFields.any(
          (f) => f.start.text.trim().isNotEmpty || f.end.text.trim().isNotEmpty,
        );
    final hasSelection = _selectedWeekday != null;

    return anyDraftDays || anyTextFields || hasSelection;
  }

  void _confirmResetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset all week templates?'),
            content: const Text(
              'This will remove all saved week templates and clear the editor.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, reset'),
              ),
            ],
          ),
    );
    if (ok == true) {
      setState(() {
        _savedWeeks.clear();
        _draftDays = {for (var i = 1; i <= 7; i++) i: <TimeRange>[]};
        _templateNameCtl.text = 'Week Template 1';
        _defaultWeekIndex = null;
        _resetEditorPanel();
      });
      _snack('All templates cleared.');
    }
  }

  // Compare two lists of time ranges (same length, same start/end)
  bool _sameRanges(List<TimeRange> a, List<TimeRange> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
    }
    return true;
  }

  // Compare two WeeklyAvailability objects structurally (by 7-day schedule)
  bool _areWeeksEqual(WeeklyAvailability a, WeeklyAvailability b) {
    for (var day = 1; day <= 7; day++) {
      final ra = a.days[day] ?? const <TimeRange>[];
      final rb = b.days[day] ?? const <TimeRange>[];
      if (!_sameRanges(ra, rb)) return false;
    }
    return true;
  }

  List<(int, int, List<TimeRange>)> _groupWeekByRanges(
    WeeklyAvailability week,
  ) {
    final List<(int, int, List<TimeRange>)> out = [];
    List<TimeRange> rangesFor(int day) => week.days[day] ?? const <TimeRange>[];

    int? currentStart;
    List<TimeRange>? currentRanges;

    for (var day = 1; day <= 7; day++) {
      final r = rangesFor(day);
      if (currentStart == null) {
        currentStart = day;
        currentRanges = r;
      } else {
        if (!_sameRanges(currentRanges!, r)) {
          out.add((currentStart, day - 1, currentRanges));
          currentStart = day;
          currentRanges = r;
        }
      }
    }

    if (currentStart != null && currentRanges != null) {
      out.add((currentStart, 7, currentRanges));
    }

    return out;
  }

  List<TimeRange>? _buildRangesFromFields({bool strict = true}) {
    final raw = <TimeRange>[];
    var anyInvalid = false;

    void parseRow(TextEditingController sCtl, TextEditingController eCtl) {
      final sText = sCtl.text.trim();
      final eText = eCtl.text.trim();
      if (sText.isEmpty && eText.isEmpty) return;
      final s = _parseHHmm(sText);
      final e = _parseHHmm(eText);
      if (s == null || e == null || !_isValidRange(s, e)) {
        anyInvalid = true;
        return;
      }
      raw.add(TimeRange(start: _fmt24(s), end: _fmt24(e)));
    }

    parseRow(_startCtl, _endCtl);
    for (final f in _extraRangeFields) {
      parseRow(f.start, f.end);
    }

    if (strict && anyInvalid) return null;
    if (!strict && anyInvalid && raw.isEmpty) return null;
    if (raw.isEmpty) return [];

    return _mergeRanges(raw);
  }

  List<TimeRange> _mergeRanges(List<TimeRange> ranges) {
    if (ranges.isEmpty) return [];
    final sorted = List<TimeRange>.from(ranges)
      ..sort((a, b) => _toMinutes(a.start).compareTo(_toMinutes(b.start)));

    final out = <TimeRange>[];
    var curStart = _toMinutes(sorted.first.start);
    var curEnd = _toMinutes(sorted.first.end);

    for (var i = 1; i < sorted.length; i++) {
      final s = _toMinutes(sorted[i].start);
      final e = _toMinutes(sorted[i].end);
      if (s <= curEnd) {
        if (e > curEnd) curEnd = e;
      } else {
        out.add(TimeRange(start: _fmtHHmm(curStart), end: _fmtHHmm(curEnd)));
        curStart = s;
        curEnd = e;
      }
    }

    out.add(TimeRange(start: _fmtHHmm(curStart), end: _fmtHHmm(curEnd)));
    return out;
  }

  String? _durationLabel() {
    final ranges = _buildRangesFromFields(strict: false);
    if (ranges == null || ranges.isEmpty) return '';
    final mins = ranges.fold<int>(
      0,
      (sum, r) => sum + (_toMinutes(r.end) - _toMinutes(r.start)),
    );
    if (mins <= 0) return '';
    return _fmtHours(mins);
  }

  // ===== small utils =====
  int _toMinutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String _fmtHHmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseHHmm(String s) {
    final parts = s.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  int _diffMinutes(TimeOfDay a, TimeOfDay b) {
    final am = a.hour * 60 + a.minute;
    final bm = b.hour * 60 + b.minute;
    return (bm - am).clamp(0, 24 * 60);
  }

  bool _isValidRange(TimeOfDay a, TimeOfDay b) => _diffMinutes(a, b) > 0;

  String _fmtHours(int minutes) {
    final h = (minutes / 60).floor();
    final m = minutes % 60;
    if (m == 0) return '$h hours';
    return '${h}h ${m}m';
  }

  String _weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  Widget _paneHeader({required String title, required Widget trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }

  Widget _sectionTitle(String s) =>
      Text(s, style: const TextStyle(fontWeight: FontWeight.w600));

  Widget _chipsContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: child,
    );
  }

  void _confirmDeleteTemplate(int index) async {
    final week = _savedWeeks[index];
    final name = week.title.isEmpty ? 'Week Template ${index + 1}' : week.title;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete template?'),
            content: Text('Delete "$name"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (ok == true) {
      setState(() {
        _savedWeeks.removeAt(index);

        if (_defaultWeekIndex != null) {
          if (_defaultWeekIndex == index) {
            _defaultWeekIndex = null;
          } else if (_defaultWeekIndex! > index) {
            _defaultWeekIndex = _defaultWeekIndex! - 1;
          }
        }
      });
      _snack('Deleted "$name".');
    }
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===== CALENDAR SECTION =====
  Widget _buildCalendarOverrideSection(double gap) {
    if (_defaultWeekIndex == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              "Select a Default Template to enable calendar overrides",
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: Column(
          children: [
            _buildCalendarHeader(),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildCalendarGrid()),
                SizedBox(width: gap),
                Expanded(flex: 1, child: _buildOverrideControls()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_viewDate.year, _viewDate.month + 1, 0).day;
    final firstWeekday = DateTime(_viewDate.year, _viewDate.month, 1).weekday;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.1,
      ),
      itemCount: daysInMonth + (firstWeekday - 1),
      itemBuilder: (context, index) {
        if (index < firstWeekday - 1) return const SizedBox.shrink();
        final day = index - (firstWeekday - 2);
        final date = DateTime(_viewDate.year, _viewDate.month, day);

        final isSelected =
            _rangeStart != null &&
            _rangeEnd != null &&
            (date.isAfter(_rangeStart!.subtract(const Duration(seconds: 1))) &&
                date.isBefore(_rangeEnd!.add(const Duration(days: 1))));

        WkOverride? activeOverride;
        for (var o in _overrides) {
          if ((date.isAfter(o.startException) ||
                  date.isAtSameMomentAs(o.startException)) &&
              (date.isBefore(o.endException) ||
                  date.isAtSameMomentAs(o.endException))) {
            activeOverride = o;
            break;
          }
        }

        return InkWell(
          onTap: () => _onCalendarDayTap(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Colors.blue.withOpacity(0.3)
                      : (activeOverride != null
                          ? Color(activeOverride.colorValue).withOpacity(0.2)
                          : Colors.white),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  "$day",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildDaySummary(date, activeOverride),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDaySummary(DateTime date, WkOverride? override) {
    final sched = override?.overrideSchedule ?? _savedWeeks[_defaultWeekIndex!];
    final ranges = sched[date.weekday];
    if (ranges.isEmpty)
      return const Text(
        "Off",
        style: TextStyle(fontSize: 8, color: Colors.grey),
      );
    return Text("${ranges.length} slots", style: const TextStyle(fontSize: 8));
  }

  void _onCalendarDayTap(DateTime date) {
    setState(() {
      if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
        _rangeStart = date;
        _rangeEnd = null;
      } else {
        if (date.isBefore(_rangeStart!)) {
          _rangeEnd = _rangeStart;
          _rangeStart = date;
        } else {
          _rangeEnd = date;
        }
      }
    });
  }

  void _addOverride() {
    if (_rangeStart == null || _selectedOverrideScheduleIndex == null) return;
    final end = _rangeEnd ?? _rangeStart!;
    final color =
        _overrideColors[_overrides.length % _overrideColors.length].value;

    setState(() {
      _overrides.add(
        WkOverride(
          _savedWeeks[_selectedOverrideScheduleIndex!],
          _rangeStart!,
          end,
          colorValue: color,
        ),
      );
      _rangeStart = null;
      _rangeEnd = null;
    });
  }

  // UI Components
  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed:
              () => setState(() {
                _viewDate = DateTime(_viewDate.year, _viewDate.month - 1);
                _initCalendarData();
              }),
        ),
        Text(
          "${_viewDate.year} - ${_viewDate.month}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed:
              () => setState(() {
                _viewDate = DateTime(_viewDate.year, _viewDate.month + 1);
                _initCalendarData();
              }),
        ),
      ],
    );
  }

  Widget _buildOverrideControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Override", style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          _rangeStart == null
              ? "Select days..."
              : "${_rangeStart!.day} to ${_rangeEnd?.day ?? '...'}",
        ),
        DropdownButton<int>(
          isExpanded: true,
          value: _selectedOverrideScheduleIndex,
          hint: const Text("Template"),
          items: List.generate(
            _savedWeeks.length,
            (i) =>
                DropdownMenuItem(value: i, child: Text(_savedWeeks[i].title)),
          ),
          onChanged: (v) => setState(() => _selectedOverrideScheduleIndex = v),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _addOverride,
            child: const Text("Apply"),
          ),
        ),
      ],
    );
  }

  void _initCalendarData() {
    final mech = context.read<MechProvider>().mech;
    // Fix: Ensure widget is still active before running logic that triggers builds
    if (mounted && mech != null && _defaultWeekIndex != null) {
      mech.availability.initMonth(_viewDate);
    }
  }
}
