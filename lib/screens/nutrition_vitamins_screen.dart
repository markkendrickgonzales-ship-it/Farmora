import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/farmora_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/screen_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../services/vitamin_service.dart';

/// Monitoring › Nutrition › Vitamins & additives.
///
/// An open daily log: quick-add chips (seeded from `vitamin_catalog`), an
/// entry form, and today's logged doses with tap-to-edit + swipe-to-delete.
/// Everything reads/writes through [VitaminService], which notifies listeners
/// so the pill and list refresh live.
class NutritionVitaminsScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const NutritionVitaminsScreen({super.key, required this.go});

  @override
  State<NutritionVitaminsScreen> createState() =>
      _NutritionVitaminsScreenState();
}

class _NutritionVitaminsScreenState extends State<NutritionVitaminsScreen> {
  final _svc = VitaminService.instance;

  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _unit = VitaminService.units.first;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _selectedCatalogId; // null => custom typed name
  String? _editingId; // non-null => updating an existing entry
  bool _saving = false;

  // Which chip is visually active.
  String? _activeChipLabel;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onServiceChange);
    _svc.ensureLoaded();
  }

  @override
  void dispose() {
    _svc.removeListener(_onServiceChange);
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  // ── Form helpers ────────────────────────────────────────────────────────

  void _resetForm() {
    setState(() {
      _nameCtrl.clear();
      _dosageCtrl.clear();
      _notesCtrl.clear();
      _unit = VitaminService.units.first;
      _date = DateTime.now();
      _time = TimeOfDay.now();
      _selectedCatalogId = null;
      _editingId = null;
      _activeChipLabel = null;
    });
  }

  void _selectCatalogChip(VitaminCatalogItem item) {
    setState(() {
      _editingId = null;
      _selectedCatalogId = item.id;
      _activeChipLabel = item.name;
      _nameCtrl.text = item.name;
      _dosageCtrl.text = item.defaultDosage == null
          ? ''
          : _formatDosage(item.defaultDosage!);
      if (item.defaultUnit != null &&
          VitaminService.units.contains(item.defaultUnit)) {
        _unit = item.defaultUnit!;
      }
    });
  }

  void _selectCustomChip() {
    setState(() {
      _editingId = null;
      _selectedCatalogId = null;
      _activeChipLabel = '__custom__';
      _nameCtrl.clear();
      _dosageCtrl.clear();
    });
  }

  void _loadEntryIntoForm(VitaminLogEntry e) {
    setState(() {
      _editingId = e.id;
      _selectedCatalogId = e.vitaminId;
      _activeChipLabel = e.vitaminId ?? '__custom__';
      _nameCtrl.text = e.displayName;
      _dosageCtrl.text = _formatDosage(e.dosage);
      _unit = VitaminService.units.contains(e.unit)
          ? e.unit
          : VitaminService.units.first;
      _date = e.logDate;
      _time = e.timeGiven;
      _notesCtrl.text = e.notes ?? '';
    });
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  String _formatDosage(double d) =>
      d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final dosage = double.tryParse(_dosageCtrl.text.trim());
    if (name.isEmpty) {
      _toast('Enter a vitamin / additive name', isError: true);
      return;
    }
    if (dosage == null || dosage <= 0) {
      _toast('Enter a dosage greater than 0', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editingId != null) {
        await _svc.updateLog(
          _editingId!,
          vitaminId: _selectedCatalogId,
          customName: _selectedCatalogId == null ? name : null,
          dosage: dosage,
          unit: _unit,
          date: _date,
          time: _time,
          notes: _notesCtrl.text,
        );
        _toast(_isToday ? 'Entry updated' : 'Entry updated for $_dateLabel');
      } else {
        await _svc.insertLog(
          vitaminId: _selectedCatalogId,
          customName: _selectedCatalogId == null ? name : null,
          dosage: dosage,
          unit: _unit,
          date: _date,
          time: _time,
          notes: _notesCtrl.text,
        );
        _toast(_isToday ? 'Saved to today\'s log' : 'Saved · $_dateLabel');
      }
      _resetForm();
    } catch (e) {
      _toast('Save failed: ${_clean(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(VitaminLogEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FarmoraColors.surface,
        title: Text('Delete entry?',
            style: TextStyle(color: FarmoraColors.ink)),
        content: Text('Remove "${e.displayName}" (${e.dosageLabel})?',
            style: TextStyle(color: FarmoraColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: FarmoraColors.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: FarmoraColors.crit)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteLog(e.id);
      _toast('Entry deleted');
    } catch (err) {
      _toast('Delete failed: ${_clean(err)}', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year && _date.month == now.month && _date.day == now.day;
  }

  String get _dateLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[_date.month - 1]} ${_date.day}, ${_date.year}';
  }

  String get _timeLabel {
    final h = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final m = _time.minute.toString().padLeft(2, '0');
    final ap = _time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final logged = _svc.loggedTodayCount;

    return Column(
      children: [
        ScreenHeader(
          title: 'Vitamins & additives',
          subtitle: 'Log daily doses given to the flock',
          onBack: () => widget.go('nutrition'),
          right: StatusBadge(
            level: logged > 0 ? 'good' : 'warn',
            child: Text(logged > 0 ? '$logged logged today' : 'None logged today'),
          ),
        ),
        Expanded(
          child: _svc.loading && _svc.catalog.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _chipsSection(),
                    const SizedBox(height: 16),
                    _formCard(),
                    const SizedBox(height: 22),
                    _logHeader(),
                    const SizedBox(height: 10),
                    _todayLogSection(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _chipsSection() {
    final chips = <Widget>[];
    for (final item in _svc.catalog) {
      chips.add(_chip(
        label: item.name,
        selected: _activeChipLabel == item.name,
        onTap: () => _selectCatalogChip(item),
      ));
    }
    chips.add(_chip(
      label: '+ Custom',
      selected: _activeChipLabel == '__custom__',
      onTap: _selectCustomChip,
      isCustom: true,
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Quick add'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips),
        ),
        if (_svc.catalog.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Catalog not loaded yet — use "+ Custom" to log any additive.',
            style: TextStyle(fontSize: 11, color: FarmoraColors.inkFaint),
          ),
        ],
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool isCustom = false,
  }) {
    final activeBg = isCustom ? FarmoraColors.brandSoft : FarmoraColors.brandSoft;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeBg : FarmoraColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? FarmoraColors.brand : FarmoraColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? FarmoraColors.brand : FarmoraColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard() {
    return FarmoraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionLabel(_editingId != null
                    ? 'Edit entry'
                    : 'New entry'),
              ),
              if (_editingId != null)
                TextButton(
                  onPressed: () => _resetForm(),
                  child: Text('Cancel edit',
                      style: TextStyle(
                          fontSize: 12, color: FarmoraColors.inkSoft)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _fieldLabel('Vitamin / additive name'),
          CustomTextField(
            placeholder: 'e.g. Vitamin AD3E',
            controller: _nameCtrl,
            onChanged: (_) {
              if (_selectedCatalogId != null &&
                  _activeChipLabel != '__custom__') {
                setState(() {
                  _selectedCatalogId = null;
                  _activeChipLabel = '__custom__';
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _fieldLabel('Dosage'),
          CustomTextField(
            placeholder: '0.0',
            controller: _dosageCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Unit'),
          _dropdown(),
          const SizedBox(height: 12),
          _fieldLabel('Date'),
          _pickerRow(
            icon: Icons.calendar_today_outlined,
            label: _dateLabel,
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          _fieldLabel('Time given'),
          _pickerRow(
            icon: Icons.access_time_outlined,
            label: _timeLabel,
            onTap: _pickTime,
          ),
          const SizedBox(height: 12),
          _fieldLabel('Notes (optional)'),
          Container(
            decoration: BoxDecoration(
              color: FarmoraColors.surfaceSunken,
              border: Border.all(color: FarmoraColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
              decoration: InputDecoration(
                hintText: 'e.g. after heat stress, mixed with morning water',
                hintStyle: TextStyle(color: FarmoraColors.inkFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: _saving
                ? 'Saving…'
                : (_editingId != null ? 'Update entry' : 'Save entry'),
            disabled: _saving,
            onClick: _saving ? () {} : _save,
          ),
        ],
      ),
    );
  }

  Widget _dropdown() {
    // Ensure the current unit is always a valid option (e.g. legacy values).
    final items = [
      ...VitaminService.units,
      if (!VitaminService.units.contains(_unit)) _unit,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FarmoraColors.surfaceSunken,
        border: Border.all(color: FarmoraColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _unit,
          isExpanded: true,
          style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink),
          onChanged: (val) {
            if (val != null) setState(() => _unit = val);
          },
          items: items.map((u) {
            return DropdownMenuItem(value: u, child: Text(u));
          }).toList(),
        ),
      ),
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: FarmoraColors.surfaceSunken,
          border: Border.all(color: FarmoraColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: FarmoraColors.inkFaint),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontSize: 13.5, color: FarmoraColors.ink)),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 16, color: FarmoraColors.inkFaint),
          ],
        ),
      ),
    );
  }

  Widget _logHeader() {
    final count = _svc.loggedTodayCount;
    return Row(
      children: [
        Expanded(
          child: _sectionLabel("Today's log"),
        ),
        Text(
          count == 0 ? '—' : '$count entr${count == 1 ? 'y' : 'ies'}',
          style: TextStyle(fontSize: 11.5, color: FarmoraColors.inkSoft),
        ),
      ],
    );
  }

  Widget _todayLogSection() {
    final logs = _svc.todayLogs;
    if (logs.isEmpty) {
      return FarmoraCard(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 34, color: FarmoraColors.inkFaint),
            const SizedBox(height: 10),
            Text(
              'No vitamins logged yet today',
              style: TextStyle(fontSize: 13, color: FarmoraColors.inkSoft),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final e in logs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: FarmoraColors.critSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline, color: FarmoraColors.crit),
              ),
              confirmDismiss: (_) async {
                await _confirmDelete(e);
                return false; // list refreshes via the service instead
              },
              child: FarmoraCard(
                padding: const EdgeInsets.all(14),
                onTap: () => _loadEntryIntoForm(e),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: FarmoraColors.brandSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.medication_liquid_outlined,
                          size: 19, color: FarmoraColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.displayName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: FarmoraColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.dosageLabel,
                            style: TextStyle(
                                fontSize: 12, color: FarmoraColors.inkSoft),
                          ),
                          if (e.notes != null && e.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              e.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: FarmoraColors.inkSoft,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          e.timeLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: FarmoraColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(Icons.edit_outlined,
                            size: 14, color: FarmoraColors.inkFaint),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: FarmoraColors.inkSoft,
          ),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: FarmoraColors.ink,
        ),
      );
}
