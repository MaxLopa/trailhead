import 'package:app1/models/service_options.dart';
import 'package:app1/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:app1/repositories/service_dev_repository.dart';
import 'package:provider/provider.dart';

class DevServiceAdditionPage extends StatefulWidget {
  const DevServiceAdditionPage({super.key});

  @override
  State<DevServiceAdditionPage> createState() => _DevServiceAdditionPageState();
}

class _DevServiceAdditionPageState extends State<DevServiceAdditionPage> {
  // Controllers
  final TextEditingController brandController = TextEditingController();
  final TextEditingController genreController = TextEditingController();
  final TextEditingController serviceTypeController = TextEditingController();
  final FocusNode brandFocus = FocusNode();

  // State
  List<Genre> genresObj = [];
  String currGenre = '';
  Set<String> globalBrands = {}; // all brands added globally
  Set<String> currBrands = {}; // selected for current genre
  List<String> currServiceTypes = [];
  Map<String, Set<String>> serviceTypeBrands = {};

  bool unselectedCollapsed = false;

  @override
  void dispose() {
    brandController.dispose();
    genreController.dispose();
    serviceTypeController.dispose();
    brandFocus.dispose();
    super.dispose();
  }

  void _addBrand() {
    String b = brandController.text.trim();
    if (b.isEmpty) return;
    b = b[0].toUpperCase() + b.substring(1);
    if (!globalBrands.contains(b)) {
      setState(() {
        globalBrands.add(b);
        currBrands.add(b);
      });
    }
    brandController.clear();
    brandFocus.requestFocus();
  }

  void _deleteBrand(String b) {
    setState(() {
      globalBrands.remove(b);
      currBrands.remove(b);
      // Remove from currently creating service types
      serviceTypeBrands.forEach((key, set) => set.remove(b));

      // Remove from saved services on the right side
      for (var genre in genresObj) {
        final types = genre.serviceTypes;
        for (var st in types) {
          final brands = st.brands;
          brands.remove(b);
        }
      }
    });
  }

  void _toggleBrandSelection(String b) {
    setState(() {
      if (currBrands.contains(b)) {
        currBrands.remove(b);
        // Remove from service type selections
        serviceTypeBrands.forEach((key, set) => set.remove(b));
      } else {
        currBrands.add(b);
      }
    });
  }

  void _setGenre(ServiceDevRepository repo) async {
    String g = genreController.text.trim();
    if (g.isNotEmpty) {
      g = g[0].toUpperCase() + g.substring(1);
      final fetchedBrands = await repo.fetchBrands(g);
      currBrands.addAll(fetchedBrands ?? []);
      globalBrands.addAll(fetchedBrands ?? []);
      // print(fetchedBrands!);
      setState(() {
        currGenre = g;
      });
      genreController.clear();
    }
  }

  Future<List<String>?> getApplicableBrands(ServiceDevRepository repo) async {
    return await repo.fetchBrands(currGenre);
  }

  void _addServiceTypes() {
    String input = serviceTypeController.text.trim();
    if (input.isEmpty) return;
    input = input[0].toUpperCase() + input.substring(1);
    final parts =
        input
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    setState(() {
      for (final p in parts) {
        if (!currServiceTypes.contains(p)) {
          currServiceTypes.add(p);
          // Initialize with empty set → all unchecked
          serviceTypeBrands[p] = {};
        }
      }
    });
    serviceTypeController.clear();
  }

  void _deleteServiceTypeDuringCreation(String st) {
    setState(() {
      serviceTypeBrands.remove(st);
      currServiceTypes.remove(st);
    });
  }

  void _saveService() {
    if (currGenre.isEmpty || currServiceTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set genre and add at least one service type'),
        ),
      );
      return;
    }

    genresObj.add(
      Genre(
        currGenre,
        currServiceTypes.map((st) {
          return ServiceType(st, serviceTypeBrands[st]?.toList() ?? []);
        }).toList(),
        applicableBrands: currBrands.toList(),
      ),
    );

    setState(() {
      currGenre = '';
      currServiceTypes.clear();
      serviceTypeBrands.clear();
      currBrands.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Service saved locally')));
  }

  Future<void> _syncServices(ServiceDevRepository repo) async {
    await repo.seedGenresAndBrands();
    await repo.seedMechsFromMapList();
    if (genresObj.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No services to sync')));
      return;
    }

    await repo.syncBrands(globalBrands.toList());
    await repo.syncServices(genresObj);

    setState(() {
      genresObj.clear();
    });
  }

  void _deleteService(int index) {
    setState(() {
      genresObj.removeAt(index);
    });
  }

  void _deleteServiceTypeInSaved(int serviceIndex, int typeIndex) {
    setState(() {
      final types = genresObj[serviceIndex].serviceTypes;
      types.removeAt(typeIndex);
      if (types.isEmpty) {
        genresObj.removeAt(serviceIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Creation Page')),
      body: Consumer<ServiceDevRepository>(
        builder: (context, repo, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leftPanel(context, repo),
              const VerticalDivider(width: 1),
              _rightPanel(context, repo),
            ],
          );
        },
      ),
    );
  }

  Widget _leftPanel(context, ServiceDevRepository repo) {
    final unselectedBrands =
        globalBrands.where((b) => !currBrands.contains(b)).toList();

    return Expanded(
      flex: 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Creation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Brand input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: brandController,
                    focusNode: brandFocus,
                    decoration: const InputDecoration(
                      labelText: 'Enter Brand',
                      hintText: 'e.g. Shimano',
                    ),
                    onSubmitted: (_) => _addBrand(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addBrand),
              ],
            ),
            const SizedBox(height: 12),

            // Selected chips
            if (currBrands.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    currBrands.map((b) {
                      return InputChip(
                        label: Text(b),
                        selected: true,
                        onSelected: (_) => _toggleBrandSelection(b),
                        deleteIcon: const Icon(Icons.delete),
                        onDeleted: () => _deleteBrand(b),
                      );
                    }).toList(),
              ),

            // Deselect All Brands button
            if (currBrands.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      currBrands.clear();
                      serviceTypeBrands.forEach((key, set) => set.clear());
                    });
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Deselect All Brands'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Collapsible unselected brands
            if (unselectedBrands.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        unselectedCollapsed = !unselectedCollapsed;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          unselectedCollapsed
                              ? Icons.expand_more
                              : Icons.expand_less,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Unselected Brands',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (!unselectedCollapsed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            unselectedBrands.map((b) {
                              return InputChip(
                                label: Text(b),
                                selected: false,
                                onSelected: (_) => _toggleBrandSelection(b),
                                deleteIcon: const Icon(Icons.delete),
                                onDeleted: () => _deleteBrand(b),
                              );
                            }).toList(),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),

            // Genre input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: genreController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Genre (Service Name)',
                    ),
                    onSubmitted: (_) => _setGenre(repo),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => _setGenre(repo),
                ),
              ],
            ),
            if (currGenre.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected Genre: $currGenre',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 16),

            // Service type input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: serviceTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Service Types (comma separated)',
                    ),
                    onSubmitted: (_) => _addServiceTypes(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_box),
                  onPressed: _addServiceTypes,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Service type cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currServiceTypes.length,
              itemBuilder: (context, index) {
                final st = currServiceTypes[index];
                final brandsForType = serviceTypeBrands[st] ?? {};

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              st,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed:
                                  () => _deleteServiceTypeDuringCreation(st),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Select All button
                        if (currBrands.isNotEmpty) ...[
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    final brandsForType =
                                        serviceTypeBrands[st] ?? {};
                                    if (brandsForType.length ==
                                        currBrands.length) {
                                      serviceTypeBrands[st] = {};
                                    } else {
                                      serviceTypeBrands[st] = Set<String>.from(
                                        currBrands,
                                      );
                                    }
                                  });
                                },
                                child: const Text('Toggle All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Brand checkboxes
                        if (currBrands.isEmpty)
                          const Text(
                            'No applicable brands selected for this genre.',
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children:
                                currBrands.map((b) {
                                  return SizedBox(
                                    height: 36,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: brandsForType.contains(b),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                brandsForType.add(b);
                                              } else {
                                                brandsForType.remove(b);
                                              }
                                              serviceTypeBrands[st] =
                                                  brandsForType;
                                            });
                                          },
                                        ),
                                        Text(b),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveService,
              icon: const Icon(Icons.save),
              label: const Text('Save Service Locally'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rightPanel(context, ServiceDevRepository repo) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Created Services',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (genresObj.isNotEmpty) ...[
                  DrawnButton(
                    size: Size(150, 50),
                    child: Text('Sync Service data'),
                    onClick: () => _syncServices(repo),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  genresObj.isEmpty
                      ? const Center(child: Text('No services created yet.'))
                      : ListView.builder(
                        itemCount: genresObj.length,
                        itemBuilder: (context, serviceIndex) {
                          final service = genresObj[serviceIndex];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Genre: ${service.name}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed:
                                            () => _deleteService(serviceIndex),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(service.serviceTypes.length, (
                                    i,
                                  ) {
                                    final st = service.serviceTypes[i];
                                    final stName = st.name;
                                    final stBrands = st.brands;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 10,
                                        bottom: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Service Type: $stName'),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                ),
                                                onPressed:
                                                    () =>
                                                        _deleteServiceTypeInSaved(
                                                          serviceIndex,
                                                          i,
                                                        ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Brands: ${stBrands.join(', ')}',
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
