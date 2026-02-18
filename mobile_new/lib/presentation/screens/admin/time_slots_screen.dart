import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/extensions/context_extensions.dart';

/// Time Slots Screen
/// Manage weekly time slots for a service provider
class TimeSlotsScreen extends ConsumerStatefulWidget {
  final String spId;

  const TimeSlotsScreen({super.key, required this.spId});

  @override
  ConsumerState<TimeSlotsScreen> createState() => _TimeSlotsScreenState();
}

class _TimeSlotsScreenState extends ConsumerState<TimeSlotsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSubmitting = false;

  // Mock time slots data (in real app, this would come from API)
  final Map<int, List<_TimeSlot>> _timeSlots = {
    0: [_TimeSlot(id: 1, start: '09:00', end: '12:00', isEnabled: true)], // Sunday
    1: [
      _TimeSlot(id: 2, start: '09:00', end: '12:00', isEnabled: true),
      _TimeSlot(id: 3, start: '14:00', end: '17:00', isEnabled: true),
    ], // Monday
    2: [_TimeSlot(id: 4, start: '09:00', end: '12:00', isEnabled: true)], // Tuesday
    3: [_TimeSlot(id: 5, start: '09:00', end: '12:00', isEnabled: true)], // Wednesday
    4: [
      _TimeSlot(id: 6, start: '09:00', end: '12:00', isEnabled: true),
      _TimeSlot(id: 7, start: '14:00', end: '17:00', isEnabled: true),
    ], // Thursday
    5: [], // Friday
    6: [], // Saturday
  };

  final _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final _fullDayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSlot(int dayIndex, int slotIndex) {
    setState(() {
      _timeSlots[dayIndex]![slotIndex] = _timeSlots[dayIndex]![slotIndex].copyWith(
        isEnabled: !_timeSlots[dayIndex]![slotIndex].isEnabled,
      );
    });
  }

  void _addSlot(int dayIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddSlotSheet(
        onAdd: (start, end) {
          setState(() {
            final slots = _timeSlots[dayIndex] ?? [];
            _timeSlots[dayIndex] = [
              ...slots,
              _TimeSlot(
                id: DateTime.now().millisecondsSinceEpoch,
                start: start,
                end: end,
                isEnabled: true,
              ),
            ];
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeSlot(int dayIndex, int slotIndex) {
    setState(() {
      _timeSlots[dayIndex]!.removeAt(slotIndex);
    });
  }

  void _applyPreset(String preset) {
    setState(() {
      final morningSlot = _TimeSlot(
        id: DateTime.now().millisecondsSinceEpoch,
        start: '09:00',
        end: '12:00',
        isEnabled: true,
      );
      final afternoonSlot = _TimeSlot(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        start: '14:00',
        end: '17:00',
        isEnabled: true,
      );

      switch (preset) {
        case 'weekdays':
          for (int i = 0; i < 5; i++) {
            _timeSlots[i] = [morningSlot, afternoonSlot];
          }
          _timeSlots[5] = [];
          _timeSlots[6] = [];
          break;
        case 'weekend':
          for (int i = 0; i < 5; i++) {
            _timeSlots[i] = [];
          }
          _timeSlots[5] = [morningSlot];
          _timeSlots[6] = [morningSlot];
          break;
        case 'all':
          for (int i = 0; i < 7; i++) {
            _timeSlots[i] = [morningSlot, afternoonSlot];
          }
          break;
        case 'clear':
          for (int i = 0; i < 7; i++) {
            _timeSlots[i] = [];
          }
          break;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSubmitting = true);

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('time_slots.updated'.tr()),
          backgroundColor: context.colors.success,
        ),
      );

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('time_slots.title'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(7, (index) {
            final slotCount = _timeSlots[index]?.length ?? 0;
            return Tab(
              child: Builder(
                builder: (context) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_dayNames[index]),
                    if (slotCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$slotCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
      body: Column(
        children: [
          // Quick Setup
          Container(
            padding: AppSpacing.allMd,
            color: context.colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'time_slots.quick_setup'.tr(),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                AppSpacing.vGapSm,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PresetChip(
                        label: 'Weekdays',
                        icon: Icons.work_outline,
                        onTap: () => _applyPreset('weekdays'),
                      ),
                      AppSpacing.gapSm,
                      _PresetChip(
                        label: 'Weekend',
                        icon: Icons.weekend_outlined,
                        onTap: () => _applyPreset('weekend'),
                      ),
                      AppSpacing.gapSm,
                      _PresetChip(
                        label: 'All Week',
                        icon: Icons.calendar_month_outlined,
                        onTap: () => _applyPreset('all'),
                      ),
                      AppSpacing.gapSm,
                      Builder(
                        builder: (context) => _PresetChip(
                          label: 'Clear All',
                          icon: Icons.clear_all,
                          color: context.colors.error,
                          onTap: () => _applyPreset('clear'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(7, (dayIndex) {
                final slots = _timeSlots[dayIndex] ?? [];
                return _DaySlots(
                  dayName: _fullDayNames[dayIndex],
                  slots: slots,
                  onToggle: (index) => _toggleSlot(dayIndex, index),
                  onRemove: (index) => _removeSlot(dayIndex, index),
                  onAdd: () => _addSlot(dayIndex),
                );
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Builder(
        builder: (context) => Container(
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            color: context.colors.card,
            boxShadow: context.bottomNavShadow,
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _save,
                child: _isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(context.colors.onPrimary),
                        ),
                      )
                    : Text('time_slots.save'.tr()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Time slot model
class _TimeSlot {
  final int id;
  final String start;
  final String end;
  final bool isEnabled;

  const _TimeSlot({
    required this.id,
    required this.start,
    required this.end,
    required this.isEnabled,
  });

  _TimeSlot copyWith({
    int? id,
    String? start,
    String? end,
    bool? isEnabled,
  }) {
    return _TimeSlot(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  String get formattedRange => '$start - $end';
}

/// Preset chip widget
class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.colors.primary;
    return Material(
      color: chipColor.withOpacity(0.1),
      borderRadius: AppRadius.allFull,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: chipColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: chipColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day slots content
class _DaySlots extends StatelessWidget {
  final String dayName;
  final List<_TimeSlot> slots;
  final Function(int) onToggle;
  final Function(int) onRemove;
  final VoidCallback onAdd;

  const _DaySlots({
    required this.dayName,
    required this.slots,
    required this.onToggle,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.allLg,
      children: [
        Text(
          dayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.vGapMd,
        if (slots.isEmpty)
          Container(
            padding: AppSpacing.allXl,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: context.colors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.schedule,
                  size: 48,
                  color: context.colors.textTertiary,
                ),
                AppSpacing.vGapMd,
                Text(
                  'time_slots.no_slots'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  'time_slots.add_slots_hint'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          )
        else
          ...slots.asMap().entries.map((entry) {
            final index = entry.key;
            final slot = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _SlotCard(
                slot: slot,
                onToggle: () => onToggle(index),
                onRemove: () => onRemove(index),
              ),
            );
          }),
        AppSpacing.vGapMd,
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text('time_slots.add_slot'.tr()),
        ),
      ],
    );
  }
}

/// Slot card widget
class _SlotCard extends StatelessWidget {
  final _TimeSlot slot;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _SlotCard({
    required this.slot,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardRadius,
        boxShadow: context.cardShadow,
        border: Border.all(
          color: slot.isEnabled ? context.colors.success.withOpacity(0.3) : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: slot.isEnabled
                  ? context.colors.success.withOpacity(0.1)
                  : context.colors.surfaceVariant,
              borderRadius: AppRadius.allMd,
            ),
            child: Icon(
              Icons.access_time,
              color: slot.isEnabled ? context.colors.success : context.colors.textTertiary,
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.formattedRange,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  slot.isEnabled ? 'time_slots.available'.tr() : 'time_slots.disabled'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: slot.isEnabled ? context.colors.success : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: slot.isEnabled,
            onChanged: (_) => onToggle(),
            activeColor: context.colors.success,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            color: context.colors.error,
          ),
        ],
      ),
    );
  }
}

/// Add slot bottom sheet
class _AddSlotSheet extends StatefulWidget {
  final Function(String start, String end) onAdd;

  const _AddSlotSheet({required this.onAdd});

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'time_slots.add_slot'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.vGapXl,
          Row(
            children: [
              Expanded(
                child: _TimePickerButton(
                  label: 'Start Time',
                  time: _formatTime(_startTime),
                  onTap: _pickStartTime,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: _TimePickerButton(
                  label: 'End Time',
                  time: _formatTime(_endTime),
                  onTap: _pickEndTime,
                ),
              ),
            ],
          ),
          AppSpacing.vGapXl,
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                widget.onAdd(_formatTime(_startTime), _formatTime(_endTime));
              },
              child: Text('time_slots.add'.tr()),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Time picker button
class _TimePickerButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        AppSpacing.vGapSm,
        Material(
          color: context.colors.surfaceVariant,
          borderRadius: AppRadius.inputRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.inputRadius,
            child: Container(
              padding: AppSpacing.allMd,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    time,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.access_time, color: context.colors.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
