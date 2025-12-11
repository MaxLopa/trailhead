import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app1/pages/home_page.dart';
import 'package:app1/pages/side_Pages.dart';
import 'package:app1/provider/main_app_provider.dart';
import 'package:app1/repositories/mech_repository.dart';

import 'package:app1/provider/mech_provider.dart';

class MechanicMenuSetupPage extends StatelessWidget {
  const MechanicMenuSetupPage({super.key});

  static Future<void> open(
    BuildContext context, {
    required MechRepository repo,
    required AppState appState,
    required MechProvider mechProvider,
  }) async {
    if (appState.loggedIn() && appState.isMech()) {
      final genres = await repo.fetchGenericGenres();
      final mechProvider = Provider.of<MechProvider>(context, listen: false);
      mechProvider.initGenres(
        genres: genres,
        mech: appState.mech,
        appUser: appState.user,
      );
      mechProvider.init(appState.mech!, appState.user!);

      // ignore: use_build_context_synchronously
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MechanicMenuSetupPage()));
    } else {
      LoginSignupPage.openLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    final w = MediaQuery.of(context).size.width;
    final colWidth = (w - (gap * 4)) / 3; // 3 columns + outer padding
    final height = MediaQuery.of(context).size.height * 0.65;

    return MainLayout(
      bodyWidget: Scaffold(
        appBar: AppBar(title: const Text('Mechanic Service-Menu Setup')),
        body: Consumer2<MechProvider, MechRepository>(
          builder: (context, vm, repo, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: colWidth,
                    child: _allOptionsCard(context, vm, height),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: colWidth,
                    child: _brandsCard(context, vm, height),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: colWidth,
                    child: _previewCard(context, vm, repo, height),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- LEFT: Genres → ServiceTypes ----------
  Widget _allOptionsCard(BuildContext context, MechProvider vm, double height) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('All Options (Genres → Service Types)'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final genre in vm.allGenres) ...[
                      CheckboxListTile(
                        value: vm.isGenreChecked(genre.name),
                        onChanged: (_) => vm.toggleGenre(genre.name),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          genre.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (vm.isGenreChecked(genre.name))
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Column(
                            children: [
                              for (final st in vm.serviceTypesForGenre(
                                genre,
                              )) ...[
                                CheckboxListTile(
                                  value: vm.isServiceTypeChecked(
                                    genre.name,
                                    st.name,
                                  ),
                                  onChanged:
                                      (_) => vm.toggleServiceType(
                                        genre.name,
                                        st.name,
                                      ),
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(st.name),
                                  secondary: IconButton(
                                    tooltip: 'Configure brands for ${st.name}',
                                    icon: const Icon(Icons.tune, size: 18),
                                    onPressed:
                                        () => vm.setActiveServiceType(st.name),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),

              OutlinedButton.icon(
                onPressed: vm.clearAll,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- MIDDLE: Brands for active ST ----------
  Widget _brandsCard(BuildContext context, MechProvider vm, double height) {
    final stName = vm.activeServiceTypeName;
    final brands =
        stName == null ? const [] : vm.brandsForServiceTypeName(stName);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Brands${stName != null ? ' for $stName' : ''}'),
              const SizedBox(height: 12),
              if (stName == null)
                const Text(
                  'Select a service type to configure brands.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (brands.isEmpty)
                        const Text(
                          'No brands available for this service type.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      for (final b in brands)
                        CheckboxListTile(
                          value: vm.isBrandChecked(stName, _brandName(b)),
                          onChanged:
                              (_) => vm.toggleBrand(stName, _brandName(b)),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(_brandName(b)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- RIGHT: Preview ----------
  Widget _previewCard(
    BuildContext context,
    MechProvider vm,
    MechRepository repo,
    double height,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Menu Preview'),
              const SizedBox(height: 12),
              Expanded(
                child:
                    vm.selections.isEmpty
                        ? const Text(
                          'No selections yet.',
                          style: TextStyle(color: Colors.black54),
                        )
                        : ListView(
                          children: [
                            for (final genreEntry in vm.selections.entries) ...[
                              Text(
                                genreEntry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final stEntry
                                        in genreEntry.value.entries) ...[
                                      Text(
                                        '  - ${stEntry.key}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (stEntry.value.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 16,
                                            top: 2,
                                            bottom: 6,
                                          ),
                                          child: Text(
                                            (stEntry.value.toList()..sort())
                                                .join(', '),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            left: 16,
                                            bottom: 6,
                                          ),
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
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await vm.saveMenu(repo);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Menu saved.')),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _brandName(dynamic b) {
    try {
      final n = (b as dynamic).name;
      if (n is String) return n;
    } catch (_) {}
    return b.toString();
  }

  Widget _title(String title) => Text(
    title,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}
