import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:uuid/uuid.dart';

enum _FormSection { name, prn, route, dilution, dose, time, repeat, save }

class AddMedicationScreen extends StatefulWidget {
  final Patient patient;
  final MedType initialType;
  final Medication? medication;
  final bool isDiluentMode;

  const AddMedicationScreen({
    super.key,
    required this.patient,
    this.initialType = MedType.medication,
    this.medication,
    this.isDiluentMode = false,
  });

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _doseController;
  late final TextEditingController _repeatController;
  late final TextEditingController _diluentVolumeController;
  late final AnimationController _dilutionAnimationController;
  late final Animation<double> _dilutionAnimation;
  late final AnimationController _repeatAnimationController;
  late final Animation<double> _repeatAnimation;

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<_FormSection> _sections = [];

  late bool _isRepeat;
  late bool _isMinutes;
  late MedType _type;
  String? _selectedRoute;
  late bool _isDiluted;
  late bool _isPrn;
  bool _saveForFuture = false;
  String? _selectedDiluent;
  late DateTime _selectedDateTime;
  List<String> _supportedRoutes = [];
  List<Map<String, dynamic>> _diluentOptions = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _type = widget.medication?.type ?? (widget.isDiluentMode ? MedType.ivFluid : widget.initialType);
    _nameController = TextEditingController(
      text:
          widget.medication?.name ??
          (_type == MedType.vitalCheck ? 'Vital Signs Check' : ''),
    );
    _doseController = TextEditingController(
      text: widget.medication?.dose ?? '',
    );
    _repeatController = TextEditingController(
      text: widget.medication?.repeatValue?.toString() ?? '',
    );
    _diluentVolumeController = TextEditingController(
      text: widget.medication?.diluentVolume ?? '',
    );

    _isDiluted = widget.medication?.isDiluted ?? false;
    _isPrn = widget.medication?.isPrn ?? false;
    _isRepeat = widget.medication?.repeatValue != null;
    _isMinutes = widget.medication?.isRepeatInMinutes ?? false;

    _dilutionAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    );
    _dilutionAnimation = CurvedAnimation(
      parent: _dilutionAnimationController,
      curve: Curves.easeInOut,
    );

    _repeatAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.normal
    );
    _repeatAnimation = CurvedAnimation(
      parent: _repeatAnimationController,
      curve: Curves.easeInOut,
    );

    if (_isDiluted) {
      _dilutionAnimationController.value = 1.0;
    }
    if (_isRepeat) {
      _repeatAnimationController.value = 1.0;
    }

    _selectedDateTime = widget.medication?.timeDue ?? DateTime.now();
    _selectedRoute = widget.medication?.route;
    _selectedDiluent = widget.medication?.diluent;

    _loadDiluents();
    _loadSupportedRoutes();

    // Trigger initial staggered entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSections();
    });
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  List<_FormSection> _getDesiredSections() {
    List<_FormSection> sections = [_FormSection.name];
    if (_type == MedType.medication) {
      sections.add(_FormSection.prn);
    }
    if (_type == MedType.medication || _type == MedType.ivFluid) {
      if (_supportedRoutes.isNotEmpty) {
        sections.add(_FormSection.route);
      }
      if (_selectedRoute == 'IV' || _type == MedType.ivFluid) {
        sections.add(_FormSection.dilution);
      }
      sections.add(_FormSection.dose);
    }
    sections.add(_FormSection.time);
    sections.add(_FormSection.repeat);
    sections.add(_FormSection.save);
    return sections;
  }

  bool _isUpdating = false;

  Future<void> _updateSections() async {
    if (_listKey.currentState == null) return;
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final desired = _getDesiredSections();

      // 1. Remove items that shouldn't be there
      for (int i = _sections.length - 1; i >= 0; i--) {
        if (!desired.contains(_sections[i])) {
          final removedItem = _sections[i];
          setState(() {
            _sections.removeAt(i);
          });
          _listKey.currentState?.removeItem(
            i,
            (context, animation) => _buildSection(removedItem, animation),
            duration: AppDurations.normal,
          );
          await Future.delayed(const Duration(milliseconds: 50)); // Increased for visibility
        }
      }

      // 2. Insert items that are missing
      for (int i = 0; i < desired.length; i++) {
        if (!_sections.contains(desired[i])) {
          setState(() {
            _sections.insert(i, desired[i]);
          });
          _listKey.currentState?.insertItem(
            i,
            duration:AppDurations.normal,
          );
          await Future.delayed(AppDurations.fast); // Staggered delay
        }
      }
    } finally {
      _isUpdating = false;
    }

    // Check if desired changed again during animation
    final currentDesired = _getDesiredSections();
    bool mismatch = currentDesired.length != _sections.length;
    if (!mismatch) {
      for (int i = 0; i < currentDesired.length; i++) {
        if (currentDesired[i] != _sections[i]) {
          mismatch = true;
          break;
        }
      }
    }

    if (mismatch) {
      _updateSections();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _repeatController.dispose();
    _diluentVolumeController.dispose();
    _dilutionAnimationController.dispose();
    _repeatAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadDiluents() async {
    try {
      final String response = await rootBundle.loadString(
        'lib/assets/diluents.json',
      );
      final List<dynamic> data = json.decode(response);
      List<Map<String, dynamic>> flatList = [];

      for (var item in data) {
        if (item.containsKey('others')) {
          for (var other in item['others']) {
            flatList.add(Map<String, dynamic>.from(other));
          }
        } else if (item.containsKey('generic')) {
          flatList.add(Map<String, dynamic>.from(item));
        }
      }
      setState(() => _diluentOptions = flatList);
    } catch (e) {
      debugPrint('Error loading diluents: $e');
    }
  }

  Future<void> _loadSupportedRoutes() async {
    if (_type != MedType.medication) return;
    try {
      final catalogBox = Hive.box('med_catalog');
      final currentName = widget.medication?.name ?? _nameController.text;
      if (currentName.isEmpty) return;

      final medRaw = catalogBox.get(currentName);

      if (medRaw != null) {
        final med = Map<String, dynamic>.from(medRaw as Map);
        setState(() {
          _supportedRoutes = List<String>.from(med['routes'] ?? []);
          if (_selectedRoute == null && _supportedRoutes.isNotEmpty) {
            _selectedRoute =
                _supportedRoutes.contains('IV') ? 'IV' : _supportedRoutes.first;
          }
        });
        _updateSections();
      } else if (widget.medication?.route != null) {
        setState(() => _supportedRoutes = [widget.medication!.route!]);
        _updateSections();
      }
    } catch (e) {
      debugPrint('Error loading supported routes from Hive: $e');
      if (widget.medication?.route != null) {
        setState(() => _supportedRoutes = [widget.medication!.route!]);
        _updateSections();
      }
    }
  }

  Future<void> _pickDateTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: use24HourFormatNotifier,
          builder: (context, use24h, _) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
              child: child!,
            );
          }
        );
      },
    );

    if (time != null) {
      final now = DateTime.now();
      DateTime scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      setState(() {
        _selectedDateTime = scheduled;
      });
    }
  }

  Future<void> _showMedSearch() async {
    final theme = Theme.of(context);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder:
                  (context, scrollController) => MedSearchWidget(
                    scrollController: scrollController,
                    theme: theme,
                    isDiluentOnly: widget.isDiluentMode,
                    isTaskOnly: _type == MedType.vitalCheck,
                  ),
            ),
          ),
    );

    if (result != null) {
      if (result['is_custom'] == true) {
        if (_type == MedType.vitalCheck) {
          setState(() {
            _nameController.text = result['name'];
          });
          _updateSections();
        } else {
          _showCustomMedDialog(result['generic']);
        }
        return;
      }
      setState(() {
        _nameController.text = result['generic'] ?? result['name'];
        _supportedRoutes = List<String>.from(result['routes'] ?? []);
        if (widget.isDiluentMode) {
          _selectedRoute = 'IV';
          _isDiluted = true;
          _dilutionAnimationController.forward();
        } else if (_supportedRoutes.isNotEmpty) {
          _selectedRoute =
              _supportedRoutes.contains('IV') ? 'IV' : _supportedRoutes.first;
        }
      });
      _updateSections();
    }
  }

  void _showCustomMedDialog(String initialName) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final nameController = TextEditingController(text: initialName);
    final brandController = TextEditingController();
    List<String> selectedRoutes = [];
    final allRoutes = [
      'PO',
      'IV',
      'IM',
      'SC',
      'PR',
      'SL',
      'INH',
      'TD',
      'TOP',
      'IN',
    ];

    final routeExplanations = {
      'PO': 'Oral (by mouth)',
      'IV': 'Intravenous (into a vein)',
      'IM': 'Intramuscular (into a muscle)',
      'SC': 'Subcutaneous (under the skin)',
      'PR': 'Rectal',
      'SL': 'Sublingual (under the tongue)',
      'INH': 'Inhalation',
      'TD': 'Transdermal (patch)',
      'TOP': 'Topical (on skin)',
      'IN': 'Intranasal',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder:
                  (context, setModalState) => DraggableScrollableSheet(
                    initialChildSize: 0.6,
                    maxChildSize: 0.9,
                    minChildSize: 0.4,
                    expand: false,
                    builder:
                        (context, scrollController) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: ListView(
                            controller: scrollController,
                            children: [
                            Text(
                              'Create Custom Medication',
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            Text('Generic Name', style: textTheme.labelLarge),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(30),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Brand Names (Optional, comma separated)',
                              style: textTheme.labelLarge,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: brandController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(30),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'e.g. Panadol, Tylenol',
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Text(
                                  'Supported Routes',
                                  style: textTheme.labelLarge,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: const Text('Route Explanations'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children:
                                                  routeExplanations.entries
                                                      .map(
                                                        (e) => Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 4,
                                                              ),
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              SizedBox(
                                                                width: 40,
                                                                child: Text(
                                                                  e.key,
                                                                  style:
                                                                      const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                      ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  e.value,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                    ),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                  ),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  allRoutes.map((route) {
                                    final isSelected = selectedRoutes.contains(
                                      route,
                                    );
                                    return FilterChip(
                                      label: Text(route),
                                      selected: isSelected,
                                      onSelected: (val) {
                                        setModalState(() {
                                          if (val) {
                                            selectedRoutes.add(route);
                                          } else {
                                            selectedRoutes.remove(route);
                                          }
                                        });
                                      },
                                      selectedColor: colorScheme.primary,
                                      checkmarkColor: colorScheme.onPrimary,
                                      labelStyle: TextStyle(
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurface,
                                      ),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 40),
                            PrimaryButton(
                              label: 'Add Medication',
                              onTap: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;

                                final newMed = {
                                  'generic': name,
                                  'brands':
                                      brandController.text
                                          .split(',')
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty)
                                          .toList(),
                                  'routes':
                                      selectedRoutes.isEmpty
                                          ? ['PO']
                                          : selectedRoutes,
                                };

                                // Save to Hive catalog
                                final catalogBox = Hive.box('med_catalog');
                                await catalogBox.put(name, newMed);

                                if (!context.mounted) return;
                                Navigator.pop(context);

                                setState(() {
                                  _nameController.text = name;
                                  _supportedRoutes = List<String>.from(
                                    newMed['routes'] as List,
                                  );
                                  if (_supportedRoutes.isNotEmpty) {
                                    _selectedRoute =
                                        _supportedRoutes.contains('IV')
                                            ? 'IV'
                                            : _supportedRoutes.first;
                                  }
                                });
                                _updateSections();
                              },
                            ),
                          ],
                        ),
                      ),
                ),
            ),
          ),
    );
  }

  void _showDiluentPicker(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Select Diluent',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(
                  height: 2,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _diluentOptions.length,
                    itemBuilder: (context, index) {
                      final d = _diluentOptions[index];
                      final String name = d['generic'] as String;
                      final brand = (d['brands'] as List).first;
                      final isSelected = _selectedDiluent == name;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        title: Text(name),
                        subtitle: Text(brand),
                        trailing: isSelected
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          setState(() => _selectedDiluent = name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveMedication() async {
    final name = _nameController.text.trim();
    final dose = _doseController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }

    if (_type == MedType.vitalCheck && _saveForFuture) {
      final taskCatalogBox = Hive.box('task_catalog');
      if (!taskCatalogBox.containsKey(name)) {
        await taskCatalogBox.put(name, {
          'name': name,
          'category': 'Custom',
        });
      }
    }

    final timeDue = _selectedDateTime;

    try {
      if (widget.medication != null) {
        widget.medication!.name = name;
        widget.medication!.dose = _type == MedType.vitalCheck && dose.isEmpty
            ? 'Scheduled Check'
            : dose;
        widget.medication!.timeDue = timeDue;
        widget.medication!.repeatValue =
            _isRepeat ? int.tryParse(_repeatController.text) : null;
        widget.medication!.isRepeatInMinutes = _isMinutes;
        widget.medication!.route = _selectedRoute;
        widget.medication!.isDiluted = _isDiluted;
        widget.medication!.diluent = _isDiluted ? _selectedDiluent : null;
        widget.medication!.diluentVolume =
            _isDiluted ? _diluentVolumeController.text : null;
        widget.medication!.isPrn = _isPrn;
        await widget.medication!.save();
        
        AuditService.log(AuditAction.medicationUpdated, {
          'patient': widget.patient.name,
          'medication': name,
          'dose': dose,
        }, outcome: true);

        // Reschedule notification
        if (!_isPrn) {
          await NotificationService().scheduleNotification(widget.medication!, widget.patient.name);
        }
      } else {
        final medication = Medication(
          id: _uuid.v4(),
          name: name,
          dose: _type == MedType.vitalCheck && dose.isEmpty
              ? 'Scheduled Check'
              : dose,
          timeDue: timeDue,
          type: _type,
          repeatValue: _isRepeat ? int.tryParse(_repeatController.text) : null,
          isRepeatInMinutes: _isMinutes,
          route: _selectedRoute,
          isDiluted: _isDiluted,
          diluent: _isDiluted ? _selectedDiluent : null,
          diluentVolume: _isDiluted ? _diluentVolumeController.text : null,
          isPrn: _isPrn,
        );

        final medBox = Hive.box<Medication>('medications');
        await medBox.add(medication);

        var meds = widget.patient.medications;
        if (meds == null) {
          meds = HiveList(medBox);
          widget.patient.medications = meds;
        }
        meds.add(medication);
        await widget.patient.save();
        
        AuditService.log(AuditAction.medicationAdded, {
          'patient': widget.patient.name,
          'medication': name,
          'dose': dose,
        }, outcome: true);

        // Schedule notification
        if (!_isPrn) {
          await NotificationService().scheduleNotification(medication, widget.patient.name);
        }
      }

      if (mounted) {
        Future.delayed(Duration.zero, () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      AuditService.log(
        widget.medication != null ? AuditAction.medicationUpdated : AuditAction.medicationAdded,
        {
          'patient': widget.patient.name,
          'medication': name,
          'error': e.toString(),
        },
        outcome: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving medication: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.medication != null
              ? 'Edit ${_type == MedType.medication ? 'Medication' : 'Check'}'
              : (_type == MedType.medication
                  ? 'Add Medication'
                  : 'Schedule Check'),
        ),
      ),
      body: AnimatedList(
        key: _listKey,
        padding: const EdgeInsets.all(24.0),
        initialItemCount: _sections.length,
        itemBuilder: (context, index, animation) {
          return _buildSection(_sections[index], animation);
        },
      ),
    );
  }

  Widget _buildSection(_FormSection section, Animation<double> animation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Widget child;

    switch (section) {
      case _FormSection.name:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _type == MedType.medication ? 'Medication Name' : 'Check Name',
              style: textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              onTap: _showMedSearch,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              controller: _nameController,
              autofocus: false,
              readOnly: true,
              style: textTheme.bodyLarge,
              decoration: InputDecoration(
                // only show label when medication isnt selected
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide.none,
                ),
                hintText:
                    _type == MedType.vitalCheck
                        ? 'Search tasks...'
                        : 'e.g. Paracetamol',
                suffixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
        break;

      case _FormSection.prn:
        child = Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              tileColor: Colors.transparent,
              title: Text('PRN / As Needed', style: textTheme.titleMedium),
              subtitle: Text(
                'Medication is given when required',
                style: textTheme.bodySmall,
              ),
              trailing: Switch(
                value: _isPrn,
                onChanged: (val) {
                  setState(() => _isPrn = val);
                  _updateSections();
                },
              ),
            ),
          ],
        );
        break;

      case _FormSection.dose:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('Dose'),
            TextField(
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              controller: _doseController,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  borderSide: BorderSide.none,
                ),
                hintText: 'e.g. 500mg',
              ),
            ),
          ],
        );
        break;

      case _FormSection.route:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('Route'),
            DefaultTabController(
              length: _supportedRoutes.length,
              initialIndex:
                  _selectedRoute != null
                      ? _supportedRoutes.indexOf(_selectedRoute!)
                      : 0,
              key: ValueKey(
                '${_nameController.text}_routes_${_supportedRoutes.length}',
              ),
              child: Container(
                height: 50,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  isScrollable: _supportedRoutes.length > 4,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: colorScheme.primary,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  labelStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  onTap: (index) {
                    setState(() {
                      _selectedRoute = _supportedRoutes[index];
                    });
                    _updateSections();
                  },
                  tabs: _supportedRoutes.map((r) => Tab(text: r)).toList(),
                ),
              ),
            ),
          ],
        );
        break;

      case _FormSection.dilution:
        child = Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              tileColor: Colors.transparent,
              title: Text('Dilution', style: textTheme.titleMedium),
              subtitle: Text(
                'Dilute medication in fluid',
                style: textTheme.bodySmall,
              ),
              trailing: Switch(
                value: _isDiluted,
                onChanged: (val) {
                  setState(() => _isDiluted = val);
                  if (val) {
                    _dilutionAnimationController.forward();
                  } else {
                    _dilutionAnimationController.reverse();
                  }
                },
              ),
            ),
            SizeTransition(
              sizeFactor: _dilutionAnimation,
              child: FadeTransition(
                opacity: _dilutionAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showDiluentPicker(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          hintStyle: TextStyle(color: Colors.grey),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _selectedDiluent != null
                              ? '$_selectedDiluent (${(_diluentOptions.firstWhere((d) => d['generic'] == _selectedDiluent)['brands'] as List).first})'
                              : 'Select diluent',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Diluent Volume (ml)', style: textTheme.labelLarge),
                    const SizedBox(height: 12),
                    TextField(
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      controller: _diluentVolumeController,
                      keyboardType: TextInputType.number,
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'e.g. 100',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: AppDurations.normal).slideY(begin: 0.2, end: 0);
        break;

      case _FormSection.time:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_type == MedType.vitalCheck &&
                _nameController.text.isNotEmpty &&
                !Hive.box('task_catalog').containsKey(_nameController.text))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => setState(() => _saveForFuture = !_saveForFuture),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _saveForFuture,
                            onChanged:
                                (val) => setState(
                                  () => _saveForFuture = val ?? false,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Save task for future reference',
                          style: textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _buildFieldLabel('Time Due'),
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        ValueListenableBuilder<bool>(
                          valueListenable: use24HourFormatNotifier,
                          builder: (context, use24h, _) {
                            String timeString;
                            if (use24h) {
                              timeString = '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}';
                            } else {
                              final hour = _selectedDateTime.hour == 0 ? 12 : (_selectedDateTime.hour > 12 ? _selectedDateTime.hour - 12 : _selectedDateTime.hour);
                              final amPm = _selectedDateTime.hour >= 12 ? 'PM' : 'AM';
                              timeString = '$hour:${_selectedDateTime.minute.toString().padLeft(2, '0')} $amPm';
                            }
                            return Text(
                              timeString,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            );
                          }
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedDateTime.day == DateTime.now().day ? 'Today' : 'Tomorrow',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: use24HourFormatNotifier,
                        builder: (context, use24h, _) {
                          final now = DateTime.now();
                          final diff = _selectedDateTime.difference(now);
                          String timeText = '';
                          
                          if (diff.isNegative) {
                            timeText = 'Just now';
                          } else {
                            final hours = diff.inHours;
                            final minutes = diff.inMinutes % 60;
                            
                            if (hours > 0) {
                              timeText = 'due in $hours ${hours == 1 ? 'hour' : 'hours'}${minutes > 0 ? ' and $minutes ${minutes == 1 ? 'minute' : 'minutes'}' : ''}';
                            } else {
                              timeText = 'due in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
                            }
                          }

                          String formattedTime;
                          if (use24h) {
                            formattedTime = '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}';
                          } else {
                            final hour = _selectedDateTime.hour == 0 ? 12 : (_selectedDateTime.hour > 12 ? _selectedDateTime.hour - 12 : _selectedDateTime.hour);
                            final amPm = _selectedDateTime.hour >= 12 ? 'PM' : 'AM';
                            formattedTime = '$hour:${_selectedDateTime.minute.toString().padLeft(2, '0')} $amPm';
                          }

                          return Text(
                            'Safe-Check: $formattedTime • $timeText',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        break;

      case _FormSection.repeat:
        child = Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              tileColor: Colors.transparent,
              title: Text('Repeat', style: textTheme.titleMedium),
              subtitle: Text(
                'Schedule recurring checks',
                style: textTheme.bodySmall,
              ),
              trailing: Switch(
                value: _isRepeat,
                onChanged: (val) {
                  setState(() => _isRepeat = val);
                  if (val) {
                    _repeatAnimationController.forward();
                  } else {
                    _repeatAnimationController.reverse();
                  }
                },
              ),
            ),
            SizeTransition(
              sizeFactor: _repeatAnimation,
              child: FadeTransition(
                opacity: _repeatAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Frequency', style: textTheme.labelLarge),
                            const SizedBox(height: 12),
                            TextField(
                              onTapOutside:
                                  (_) => FocusScope.of(context).unfocus(),
                              controller: _repeatController,
                              keyboardType: TextInputType.number,
                              style: textTheme.bodyLarge,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(30)),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 0),
                        child: Container(
                          width: 140,
                          height: 54,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: DefaultTabController(
                            length: 2,
                            initialIndex: _isMinutes ? 1 : 0,
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: colorScheme.primary,
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: colorScheme.onPrimary,
                              unselectedLabelColor: colorScheme.onSurfaceVariant,
                              labelStyle: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              onTap:
                                  (index) =>
                                      setState(() => _isMinutes = index == 1),
                              tabs: const [Tab(text: 'Hrs'), Tab(text: 'Mins')],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        break;

      case _FormSection.save:
        child = Center(
          child: PrimaryButton(
            onTap: _saveMedication,
            label: _type == MedType.medication
                ? 'Save Medication'
                : _type == MedType.ivFluid
                    ? 'Save Infusion'
                    : 'Save Check',
          ),
        );
        break;
    }

    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: section == _FormSection.save ? 48.0 : 24.0,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class MedSearchWidget extends StatefulWidget {
  final ScrollController scrollController;
  final ThemeData theme;
  final bool isDiluentOnly;
  final bool isTaskOnly;

  const MedSearchWidget({
    super.key,
    required this.scrollController,
    required this.theme,
    this.isDiluentOnly = false,
    this.isTaskOnly = false,
  });

  @override
  State<MedSearchWidget> createState() => _MedSearchWidgetState();
}

class _MedSearchWidgetState extends State<MedSearchWidget> {
  final _searchController = TextEditingController();
  List<dynamic> _allMeds = [];
  List<dynamic> _allDiluents = [];
  List<dynamic> _allTasks = [];
  List<dynamic> _resultsMeds = [];
  List<dynamic> _resultsDiluents = [];
  List<dynamic> _resultsTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    try {
      final catalogBox = Hive.box('med_catalog');
      final taskCatalogBox = Hive.box('task_catalog');
      final diluentsCatalogBox = Hive.box('diluents_catalog');

      final medData = catalogBox.values.toList();
      final taskData = taskCatalogBox.values.toList();
      final diluentData = diluentsCatalogBox.values.toList();

      setState(() {
        _allMeds = medData;
        _allDiluents = diluentData;
        _allTasks = taskData;
        _resultsMeds = _allMeds;
        _resultsDiluents = _allDiluents;
        _resultsTasks = _allTasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading lists in search: $e');
      setState(() => _isLoading = false);
    }
  }

  void _searchMed(String query) {
    if (query.isEmpty) {
      setState(() {
        _resultsMeds = _allMeds;
        _resultsDiluents = _allDiluents;
        _resultsTasks = _allTasks;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();

    final filteredTasks = _allTasks.where((task) {
      final name = task['name'].toString().toLowerCase();
      final category = task['category'].toString().toLowerCase();
      return name.contains(lowercaseQuery) || category.contains(lowercaseQuery);
    }).toList();

    final filteredMeds = _allMeds.where((med) {
      final generic = med['generic'].toString().toLowerCase();
      final brands = (med['brands'] as List)
          .map((e) => e.toString().toLowerCase())
          .toList();
      return generic.contains(lowercaseQuery) ||
          brands.any((b) => b.contains(lowercaseQuery));
    }).toList();

    final filteredDiluents = _allDiluents.where((inf) {
      final generic = inf['generic'].toString().toLowerCase();
      final brands = (inf['brands'] as List)
          .map((e) => e.toString().toLowerCase())
          .toList();
      return generic.contains(lowercaseQuery) ||
          brands.any((b) => b.contains(lowercaseQuery));
    }).toList();

    setState(() {
      _resultsMeds = filteredMeds;
      _resultsDiluents = filteredDiluents;
      _resultsTasks = filteredTasks;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTaskOnly) {
      return Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onTap: () {
                // Ensure keyboard comes back if it was dismissed
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _isLoading
                        ? Transform.scale(
                          scale: 0.5,
                          child: const CircularProgressIndicator(),
                        )
                        : null,
              ),
              onChanged: _searchMed,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildMedList([], isTaskTab: true)),
        ],
      );
    }

    if (widget.isDiluentOnly) {
      return Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onTap: () {
                // Ensure keyboard comes back if it was dismissed
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              decoration: InputDecoration(
                hintText: 'Search diluents...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _isLoading
                        ? Transform.scale(
                          scale: 0.5,
                          child: const CircularProgressIndicator(),
                        )
                        : null,
              ),
              onChanged: _searchMed,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildMedList(['IV'], isDiluentTab: true)),
        ],
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onTap: () {
                // Ensure keyboard comes back if it was dismissed
                SystemChannels.textInput.invokeMethod('TextInput.show');
              },
              decoration: InputDecoration(
                hintText: 'Search medication...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _isLoading
                        ? Transform.scale(
                          scale: 0.5,
                          child: const CircularProgressIndicator(),
                        )
                        : null,
              ),
              onChanged: _searchMed,
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            labelStyle: widget.theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: 'Injections'),
              Tab(text: 'Oral'),
              Tab(text: 'Others'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMedList(['IV', 'IM', 'SC']),
                _buildMedList(['PO', 'SL']),
                _buildMedList(['PR', 'INH', 'TD', 'TOP', 'IN'], isOther: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedList(
    List<String> routes, {
    bool isOther = false,
    bool isDiluentTab = false,
    bool isTaskTab = false,
  }) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final source =
        isTaskTab
            ? _resultsTasks
            : isDiluentTab
            ? _resultsDiluents
            : _resultsMeds;

    final filteredResults =
        source.where((med) {
          if (isDiluentTab || isTaskTab) return true;
          final m = Map<String, dynamic>.from(med as Map);
          final medRoutes = List<String>.from(m['routes'] ?? []);
          return medRoutes.any((r) => routes.contains(r));
        }).toList();

    // Find relevant meds that aren't in the current tab's results
    final relevantResults =
        (isDiluentTab || isTaskTab)
            ? []
            : _resultsMeds.where((med) {
              final m = Map<String, dynamic>.from(med as Map);
              final medRoutes = List<String>.from(m['routes'] ?? []);
              final isInCategory = medRoutes.any((r) => routes.contains(r));
              return !isInCategory;
            }).toList();

    if (filteredResults.isEmpty && relevantResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isTaskTab ? 'No tasks found' : 'No medications found',
              style: widget.theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Add "${_searchController.text}"',
              onTap: () {
                Navigator.pop(context, {
                  'is_custom': true,
                  'name': _searchController.text,
                  'generic': _searchController.text,
                });
              },
            ),
          ],
        ),
      ).animate().fadeIn(duration: AppDurations.normal);
    }

    final totalItems =
        filteredResults.length +
        (relevantResults.isNotEmpty ? relevantResults.length + 1 : 0);

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: totalItems,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        if (index < filteredResults.length) {
          if (isTaskTab) {
            final task = Map<String, dynamic>.from(filteredResults[index] as Map);
            return _buildTaskTile(task);
          }
          final med = Map<String, dynamic>.from(filteredResults[index] as Map);
          return _buildMedTile(med);
        } else if (relevantResults.isNotEmpty) {
          final relevantIndex = index - filteredResults.length;
          if (relevantIndex == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'Relevant',
                style: widget.theme.textTheme.labelLarge?.copyWith(
                  color: widget.theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          final med = Map<String, dynamic>.from(relevantResults[relevantIndex - 1] as Map);
          return _buildMedTile(med, isRelevant: true);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMedTile(Map<String, dynamic> med, {bool isRelevant = false}) {
    final brands = (med['brands'] as List).join(', ');
    final routes = List<String>.from(med['routes'] ?? []);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Row(
        children: [
          Expanded(
            child: Text(
              med['generic'],
              style: widget.theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isRelevant)
            Row(
              children:
                  routes
                      .map(
                        (r) => Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            r,
                            style: widget.theme.textTheme.labelSmall?.copyWith(
                              color: widget.theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
      subtitle: Text(
        brands,
        style: widget.theme.textTheme.bodyMedium?.copyWith(
          color: widget.theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () {
        Future.delayed(Duration.zero, () {
          if (context.mounted) Navigator.pop(context, med);
        });
      },
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        task['name'],
        style: widget.theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        task['category'] ?? '',
        style: widget.theme.textTheme.bodyMedium?.copyWith(
          color: widget.theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () {
        Future.delayed(Duration.zero, () {
          if (context.mounted) Navigator.pop(context, task);
        });
      },
    );
  }
}
