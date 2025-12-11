import 'package:app1/models/user_model.dart';
import 'package:app1/pages/home_page.dart';
import 'package:app1/pages/mechanic_pages/mech_setup_pages/mech_availability_setup.dart';
import 'package:app1/pages/mechanic_pages/mech_setup_pages/mech_menu_setup.dart';
import 'package:app1/pages/mechanic_pages/mech_signup_pages/mech_explanation_page.dart';
import 'package:app1/pages/side_Pages.dart';
import 'package:app1/provider/main_app_provider.dart';
import 'package:app1/provider/mech_provider.dart';
import 'package:app1/repositories/mech_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MechDash extends StatelessWidget {
  static const double _gap = 16;

  const MechDash({super.key});

  static void enterMechPage(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final mechProvider = Provider.of<MechProvider>(context, listen: false);

    if (appState.loggedIn()) {
      if (appState.isMech()) {
        mechProvider.init(appState.mech!, appState.user!);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MechDash()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MechExplanationPage()),
        );
      }
    } else {
      LoginSignupPage.openLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      bodyWidget: LayoutBuilder(
        builder: (context, constraints) {
          final max = constraints.maxWidth;
          double col(int span) =>
              (max - _gap * 11) / 12 * span + _gap * (span - 1);

          return Consumer<AppState>(
            builder: (context, provider, child) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: col(5),
                          child: ProfileCard(mainProvider: provider),
                        ),
                        SizedBox(width: col(6), child: const WorkshopCard()),
                      ],
                    ),
                    SizedBox(width: col(16), child: const JobsOverviewCard()),
                    SizedBox(
                      width: col(16),
                      child: MechAvailabilityAndMenu(mainProvider: provider),
                    ),
                    SizedBox(width: col(16), child: const ReviewsCard()),
                    SizedBox(width: col(12), child: const ServicesMenuCard()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final AppState mainProvider;
  const ProfileCard({super.key, required this.mainProvider});

  @override
  Widget build(BuildContext context) {
    final user = mainProvider.user;
    final mech = mainProvider.mech;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            user == null
                ? const Center(child: Text('No user logged in.'))
                : Column(
                  children: [
                    _titleRow(),
                    const SizedBox(height: 12),
                    _avatar(user),
                    const SizedBox(height: 8),
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (mech != null) _ratingRow(mech.rating),
                    const SizedBox(height: 12),
                    Text(
                      mech?.bio ?? 'No bio provided.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
      ),
    );
  }

  Row _titleRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        'Profile Preview',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Edit'),
      ),
    ],
  );

  CircleAvatar _avatar(AppUser user) => CircleAvatar(
    radius: 28,
    backgroundColor: Colors.grey.shade200,
    backgroundImage: user.pfpUrl.isNotEmpty ? NetworkImage(user.pfpUrl) : null,
    child:
        user.pfpUrl.isEmpty
            ? const Icon(Icons.person_rounded, size: 32, color: Colors.grey)
            : null,
  );

  Row _ratingRow(double rating) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ...List.generate(
        5,
        (i) => const Icon(Icons.star, size: 16, color: Colors.amber),
      ),
      Text('  ${rating.toStringAsFixed(1)}'),
    ],
  );
}

class WorkshopCard extends StatelessWidget {
  const WorkshopCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workshop Highlights',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                _photoBox(context),
                Positioned(
                  left: 0,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Upload New Photos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoBox(BuildContext context) => Container(
    width: 560,
    height: 210,
    decoration: BoxDecoration(
      color: Colors.indigo.shade100.withOpacity(0.8),
      borderRadius: BorderRadius.circular(16),
    ),
    alignment: Alignment.center,
    child: const Text('Workshop Photo '),
  );
}

class JobsOverviewCard extends StatelessWidget {
  const JobsOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jobs Overview',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _jobsList('Current Jobs', const [])),
                const SizedBox(width: 12),
                Expanded(child: _jobsList('Upcoming Jobs', const [])),
                const SizedBox(width: 12),
                Expanded(child: _jobsList('Past Jobs', const [])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _jobsList(String title, List<String> items) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final j in items) Text(j, style: const TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );
}

class MechAvailabilityAndMenu extends StatefulWidget {
  final AppState mainProvider;
  const MechAvailabilityAndMenu({super.key, required this.mainProvider});

  @override
  State<MechAvailabilityAndMenu> createState() =>
      _MechAvailabilityAndMenuState();
}

class _MechAvailabilityAndMenuState extends State<MechAvailabilityAndMenu> {
  late DateTime _month;
  late int _year;
  late int _monthNum;
  late int _daysInMonth;
  late int _firstWeekday;
  final Set<int> _selectedDays = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _year = _month.year;
    _monthNum = _month.month;
    _daysInMonth = DateUtils.getDaysInMonth(_year, _monthNum);
    _firstWeekday = _month.weekday;
  }

  @override
  Widget build(BuildContext context) {
    final mech = widget.mainProvider.mech;
    final hasMenu = (mech?.servicesOffered.isNotEmpty ?? false);
    const gap = 12.0;

    return Consumer3<MechRepository, AppState, MechProvider>(
      builder: (context, mechRepo, appState, mechProvider, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _card(
                title: 'Set Your Availability',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _weekdayHeader(context),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: _monthGrid(context),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          height: 34,
                          child: OutlinedButton.icon(
                            onPressed: _clearSelection,
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 34,
                          child: ElevatedButton.icon(
                            onPressed:
                                () => MechAvailabilitySetupPage.open(
                                  context,
                                  appState,
                                  mechRepo,
                                ),
                            icon: const Icon(Icons.schedule, size: 16),
                            label: const Text('Edit Availability'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _card(
                title: 'Current Menu',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _compressedMenuPreview(mech, hasMenu),
                    const SizedBox(height: 8),
                    Center(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => MechanicMenuSetupPage.open(
                                context,
                                repo: mechRepo,
                                appState: appState,
                                mechProvider: mechProvider,
                              ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Services/Menu'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card({required String title, required Widget body}) => Card(
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          body,
        ],
      ),
    ),
  );

  Widget _weekdayHeader(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        for (final lbl in labels)
          Expanded(
            child: Center(
              child: Text(
                lbl,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _monthGrid(BuildContext context) {
    final leading = (_firstWeekday + 6) % 7;
    final totalCells = ((leading + _daysInMonth) <= 35) ? 35 : 42;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNum = index - leading + 1;
        final inMonth = dayNum >= 1 && dayNum <= _daysInMonth;
        if (!inMonth) {
          return _dayCell(
            context,
            label: '',
            enabled: false,
            selected: false,
            onTap: null,
          );
        }
        final selected = _selectedDays.contains(dayNum);
        return _dayCell(
          context,
          label: '$dayNum',
          enabled: true,
          selected: selected,
          onTap: () => _toggleDay(dayNum),
        );
      },
    );
  }

  Widget _dayCell(
    BuildContext context, {
    required String label,
    required bool enabled,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final bg =
        selected
            ? theme.colorScheme.primary.withOpacity(0.14)
            : Colors.transparent;
    final border = selected ? theme.colorScheme.primary : theme.dividerColor;
    final txt =
        selected
            ? theme.colorScheme.primary
            : theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: txt,
          ),
        ),
      ),
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedDays.clear());

  Widget _compressedMenuPreview(Mech? mech, bool hasMenu) {
    if (!hasMenu) {
      return const Text(
        'No services currently listed.',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      );
    }

    final Map<String, Map<String, Set<String>>> selections = {};
    for (final g in mech!.servicesOffered) {
      final stMap = selections.putIfAbsent(g.name, () => {});
      for (final st in g.serviceTypes) {
        final set = stMap.putIfAbsent(st.name, () => <String>{});
        final dynamic brands =
            (st as dynamic).brands ??
            (st as dynamic).applicableBrands ??
            const [];
        if (brands is List) {
          for (final b in brands) {
            set.add(_brandName(b));
          }
        }
      }
    }

    final controller = ScrollController();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: ListView(
          controller: controller,
          children: [
            for (final genreEntry in selections.entries) ...[
              Text(
                genreEntry.key,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final stEntry in genreEntry.value.entries) ...[
                      const SizedBox(height: 2),
                      Text(
                        '  - ${stEntry.key}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (stEntry.value.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 2,
                            bottom: 6,
                          ),
                          child: Text(
                            (stEntry.value.toList()..sort()).join(', '),
                            style: const TextStyle(fontSize: 12),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(left: 16, bottom: 6),
                          child: Text(
                            'No brands selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  static String _brandName(dynamic b) {
    try {
      final n = (b as dynamic).name;
      if (n is String) return n;
    } catch (_) {}
    return b.toString();
  }
}

class ReviewsCard extends StatelessWidget {
  const ReviewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recent Reviews',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            // Reviews list was empty in your original code; leaving as-is.
          ],
        ),
      ),
    );
  }
}

class ServicesMenuCard extends StatelessWidget {
  const ServicesMenuCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Edit Service Menu',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            // Original body commented out; left unchanged.
          ],
        ),
      ),
    );
  }
}
