import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../common/widgets/app_bottom_nav.dart';
import '../../../common/widgets/app_card.dart';
import '../../../common/widgets/app_global_header.dart';
import '../../../common/widgets/app_sheet.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/prayer_times_service.dart';
import '../controllers/prayer_controller.dart';
import '../models/prayer_schedule.dart';

class PrayerScreen extends GetView<PrayerController> {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppGlobalHeader(showBottomDivider: true),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ReminderEditor.open(context),
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Reminder'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            controller.refreshTimes();
            await controller.syncNotifications();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              96,
            ),
            children: [
              _Hero(controller: controller),
              const SizedBox(height: AppSpacing.md),
              _HealthCard(controller: controller),
              _TodayCard(controller: controller),
              const SizedBox(height: AppSpacing.lg),
              _CustomSection(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      controller.nowMs.value;
      final next = controller.nextPrayer;
      final left = controller.untilNext;
      final timeFmt = DateFormat.jm();
      final muted = controller.muteAllReminders.value;

      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.prayerDawnTop, AppColors.prayerDawnBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque_rounded, color: AppColors.prayerGlow),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next == null ? 'Prayer times' : 'Next prayer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: muted ? 'Unmute reminders' : 'Mute all reminders',
                  onPressed: () => controller.setMuteAll(!muted),
                  icon: Icon(
                    muted
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_active_rounded,
                    color: muted ? Colors.white54 : AppColors.prayerGlow,
                  ),
                ),
                IconButton(
                  tooltip: 'Prayer settings',
                  onPressed: () => _PrayerSettingsSheet.open(context),
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                ),
              ],
            ),
            if (next != null) ...[
              Text(
                next.name,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${timeFmt.format(next.time)}  •  in ${_countdown(left)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.prayerMoon,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: controller.progressToNext,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.prayerAccent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    controller.locationLabel.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (controller.usingDefaultLocation.value)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.prayerGlow,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _useLocation(context),
                    child: const Text('Use my location'),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _useLocation(BuildContext context) async {
    final access = await controller.useMyLocation();
    switch (access) {
      case LocationAccess.granted || LocationAccess.off:
        Get.snackbar('Location updated', 'Prayer times now match where you are.');
      case LocationAccess.serviceDisabled:
        Get.snackbar('Location is off', 'Turn on location services and retry.');
      case LocationAccess.denied:
        Get.snackbar('Permission needed', 'Allow location to calculate exact times.');
      case LocationAccess.deniedForever:
        await LocationService.openSettings();
    }
  }

  static String _countdown(Duration? d) {
    if (d == null) return '-';
    final minutes = d.inMinutes;
    if (minutes < 1) return 'under a minute';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return '${h}h ${m}m';
  }
}

// ── Alerts health ─────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final problems = <Widget>[];

      if (!controller.notificationsAllowed.value) {
        problems.add(
          _Problem(
            icon: Icons.notifications_off_rounded,
            text: 'Notifications are blocked, so no reminder can reach you.',
            action: 'Allow',
            onTap: controller.requestNotificationPermission,
          ),
        );
      }
      if (controller.notificationsAllowed.value &&
          !controller.exactAlarmsAllowed.value) {
        problems.add(
          _Problem(
            icon: Icons.alarm_off_rounded,
            text:
                'Allow "Alarms & reminders" so prayer alerts fire exactly on time.',
            action: 'Fix',
            onTap: controller.requestExactAlarms,
          ),
        );
      }
      if (problems.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reminders need attention',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              ...problems,
            ],
          ),
        ),
      );
    });
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.icon,
    required this.text,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          FilledButton.tonal(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

// ── Today ─────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat.jm();

    return Obx(() {
      controller.nowMs.value;
      final times = controller.todayTimes;
      final next = controller.nextPrayer;
      final auto = controller.autoEnabled.value;

      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Today',
              trailing: Text(
                DateFormat('EEE, d MMM').format(DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!auto)
              Text(
                'Calculated prayer times are off. Turn them on in prayer settings.',
                style: theme.textTheme.bodySmall,
              )
            else
              for (final p in times)
                _PrayerRow(
                  controller: controller,
                  entry: p,
                  isNext: next != null &&
                      next.key == p.key &&
                      next.time.day == p.time.day,
                  clock: timeFmt.format(p.time),
                ),
          ],
        ),
      );
    });
  }
}

IconData _iconFor(PrayerKey key) {
  switch (key) {
    case PrayerKey.fajr:
      return Icons.wb_twilight_rounded;
    case PrayerKey.sunrise:
      return Icons.wb_sunny_outlined;
    case PrayerKey.dhuhr:
      return Icons.wb_sunny_rounded;
    case PrayerKey.asr:
      return Icons.wb_cloudy_rounded;
    case PrayerKey.maghrib:
      return Icons.nights_stay_outlined;
    case PrayerKey.isha:
      return Icons.dark_mode_rounded;
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.controller,
    required this.entry,
    required this.isNext,
    required this.clock,
  });

  final PrayerController controller;
  final PrayerTimeEntry entry;
  final bool isNext;
  final String clock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = controller.isPast(entry);
    final isPrayer = entry.key.isPrayer;
    final primary = theme.colorScheme.primary;
    final dim = passed && !isNext;
    final remind = controller.remindFor(entry.key);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isNext ? primary.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isNext ? Border.all(color: primary.withValues(alpha: 0.5)) : null,
      ),
      child: Opacity(
        opacity: dim ? 0.5 : 1,
        child: Row(
          children: [
            Icon(
              _iconFor(entry.key),
              color: isNext ? primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (controller.offsetFor(entry.key) != 0)
                    Text(
                      '${controller.offsetFor(entry.key) > 0 ? '+' : ''}${controller.offsetFor(entry.key)} min adjusted',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              clock,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isNext ? primary : null,
              ),
            ),
            if (isPrayer)
              IconButton(
                tooltip: remind ? 'Reminder on' : 'Reminder off',
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.setRemind(entry.key, !remind),
                icon: Icon(
                  remind
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: remind ? primary : theme.colorScheme.outline,
                ),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}

// ── Custom reminders ──────────────────────────────────────────

class _CustomSection extends StatelessWidget {
  const _CustomSection({required this.controller});

  final PrayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      controller.nowMs.value;
      final list = controller.customPrayers;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('My reminders'),
          if (list.isEmpty)
            AppCard(
              child: Row(
                children: [
                  Icon(
                    Icons.alarm_add_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Add your own reminders: masjid jamaat time, Tahajjud, '
                      'Quran reading, Jumu\'ah and more.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final prayer in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CustomTile(controller: controller, prayer: prayer),
              ),
        ],
      );
    });
  }
}

class _CustomTile extends StatelessWidget {
  const _CustomTile({required this.controller, required this.prayer});

  final PrayerController controller;
  final PrayerSchedule prayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = controller.nextOccurrence(prayer);
    final clock = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(prayer.prayerTime);

    String nextText = 'No upcoming time';
    if (next != null) {
      final today = DateTime.now();
      final diff = DateTime(next.year, next.month, next.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      nextText = diff == 0
          ? 'Today'
          : (diff == 1 ? 'Tomorrow' : DateFormat('EEE, d MMM').format(next));
    }

    return Dismissible(
      key: ValueKey('reminder-${prayer.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: theme.colorScheme.errorContainer,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete reminder?'),
            content: Text('"${prayer.name}" will stop alerting you.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return ok == true;
      },
      onDismissed: (_) => controller.deleteCustom(prayer),
      child: AppCard(
        onTap: () => _ReminderEditor.open(context, existing: prayer),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.alarm_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$clock  •  ${_recurrenceLabel(prayer)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    prayer.isEnabled
                        ? '${controller.reminderLabel(prayer.reminderMinutesBefore)}  •  Next: $nextText'
                        : 'Off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: prayer.isEnabled,
              onChanged: (v) => controller.toggleCustom(prayer, v),
            ),
          ],
        ),
      ),
    );
  }
}

String _recurrenceLabel(PrayerSchedule prayer) {
  switch (prayer.recurrence) {
    case PrayerRecurrence.once:
      final ms = prayer.onceDateMs;
      if (ms == null || ms <= 0) return 'Once';
      return DateFormat(
        'd MMM yyyy',
      ).format(DateTime.fromMillisecondsSinceEpoch(ms));
    case PrayerRecurrence.daily:
      return 'Every day';
    case PrayerRecurrence.weekly:
    case PrayerRecurrence.custom:
      final days = (prayer.repeatWeekdays.toList()..sort());
      if (days.length == 7) return 'Every day';
      return days.map(_weekdayShort).join(', ');
    case PrayerRecurrence.monthly:
      final ms = prayer.onceDateMs ?? prayer.createdAtMs;
      final day = DateTime.fromMillisecondsSinceEpoch(ms).day;
      return 'Monthly on day $day';
  }
}

String _weekdayShort(int weekday) =>
    const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday];

// ── Prayer settings sheet ─────────────────────────────────────

class _PrayerSettingsSheet extends GetView<PrayerController> {
  const _PrayerSettingsSheet();

  static Future<void> open(BuildContext context) {
    return showAppSheet<void>(
      context,
      title: 'Prayer settings',
      builder: (_) => const _PrayerSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Calculated prayer times'),
            subtitle: const Text('Works offline, based on your location'),
            value: controller.autoEnabled.value,
            onChanged: controller.setAuto,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: controller.methodId.value,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Calculation method'),
            items: [
              for (final m in PrayerTimesService.methods)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(m.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) controller.setMethod(v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Asr calculation', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('Hanafi')),
              ButtonSegment(value: false, label: Text('Shafi\'i / others')),
            ],
            selected: {controller.hanafi.value},
            onSelectionChanged: (s) => controller.setHanafi(s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<int>(
            initialValue: controller.leadMinutes.value,
            decoration: const InputDecoration(labelText: 'Remind me before'),
            items: [
              for (final m in PrayerTimesService.leadOptions)
                DropdownMenuItem(
                  value: m,
                  child: Text(m == 0 ? 'No early reminder' : '$m minutes'),
                ),
            ],
            onChanged: (v) {
              if (v != null) controller.setLead(v);
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alert at prayer time'),
            value: controller.notifyAtTime.value,
            onChanged: controller.setNotifyAtTime,
          ),
          const Divider(height: AppSpacing.xl),
          Text(
            'Adjust to your masjid',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'Shift a time by a few minutes, for example to follow the jamaat.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final key in PrayerKey.values)
            _OffsetRow(controller: controller, prayerKey: key),
          const Divider(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: controller.sendTestNotification,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Send a test notification'),
          ),
          const SizedBox(height: 6),
          Obx(
            () => Text(
              '${controller.scheduledCount.value} alerts are scheduled.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _OffsetRow extends StatelessWidget {
  const _OffsetRow({required this.controller, required this.prayerKey});

  final PrayerController controller;
  final PrayerKey prayerKey;

  @override
  Widget build(BuildContext context) {
    final offset = controller.offsetFor(prayerKey);
    // Reading the observable list makes the row rebuild after a change.
    controller.todayTimes.length;
    return Row(
      children: [
        Expanded(child: Text(prayerKey.label())),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => controller.setOffset(prayerKey, offset - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 64,
          child: Text(
            offset == 0 ? '0 min' : '${offset > 0 ? '+' : ''}$offset min',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => controller.setOffset(prayerKey, offset + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

// ── Reminder editor ───────────────────────────────────────────

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({this.existing});

  final PrayerSchedule? existing;

  static Future<void> open(BuildContext context, {PrayerSchedule? existing}) {
    return showAppSheet<void>(
      context,
      title: existing == null ? 'New reminder' : 'Edit reminder',
      builder: (_) => _ReminderEditor(existing: existing),
    );
  }

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  static const _presets = [
    'Fajr jamaat',
    'Dhuhr jamaat',
    'Asr jamaat',
    'Maghrib jamaat',
    'Isha jamaat',
    'Jumu\'ah',
    'Tahajjud',
    'Duha',
    'Quran',
  ];

  final _name = TextEditingController();
  final _note = TextEditingController();
  late TimeOfDay _time;
  late int _lead;
  late bool _enabled;
  late PrayerRecurrence _recurrence;
  late DateTime _date;
  final Set<int> _days = {};
  bool _saving = false;

  PrayerController get _controller => Get.find<PrayerController>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name.text = e?.name ?? '';
    _note.text = e?.note ?? '';
    _time = e?.prayerTime ?? const TimeOfDay(hour: 5, minute: 0);
    _lead = e?.reminderMinutesBefore ?? 10;
    _enabled = e?.isEnabled ?? true;
    _recurrence = e?.recurrence ?? PrayerRecurrence.daily;
    _date = e?.onceDateMs != null && e!.onceDateMs! > 0
        ? DateTime.fromMillisecondsSinceEpoch(e.onceDateMs!)
        : DateTime.now();
    _days.addAll(e?.repeatWeekdays ?? const []);
    if (_days.isEmpty && _recurrence != PrayerRecurrence.daily) {
      _days.add(DateTime.now().weekday);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      Get.snackbar('Check this', 'Give the reminder a name.');
      return;
    }
    if ((_recurrence == PrayerRecurrence.weekly ||
            _recurrence == PrayerRecurrence.custom) &&
        _days.isEmpty) {
      Get.snackbar('Check this', 'Pick at least one day.');
      return;
    }
    setState(() => _saving = true);
    await _controller.saveCustom(
      existing: widget.existing,
      name: _name.text,
      time: _time,
      reminderMinutesBefore: _lead,
      isEnabled: _enabled,
      recurrence: _recurrence,
      repeatWeekdays: _days.toList()..sort(),
      onceDateMs: DateTime(_date.year, _date.month, _date.day)
          .millisecondsSinceEpoch,
      note: _note.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsDate =
        _recurrence == PrayerRecurrence.once ||
        _recurrence == PrayerRecurrence.monthly;
    final needsDays =
        _recurrence == PrayerRecurrence.weekly ||
        _recurrence == PrayerRecurrence.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: [
            for (final p in _presets)
              ActionChip(
                label: Text(p),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _name.text = p),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _time,
            );
            if (picked != null) setState(() => _time = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Time',
              suffixIcon: Icon(Icons.access_time_rounded),
            ),
            child: Text(_time.format(context)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int>(
          initialValue: PrayerController.reminderOptions.contains(_lead)
              ? _lead
              : 10,
          decoration: const InputDecoration(labelText: 'Alert me'),
          items: [
            for (final m in PrayerController.reminderOptions)
              DropdownMenuItem(
                value: m,
                child: Text(_controller.reminderLabel(m)),
              ),
          ],
          onChanged: (v) => setState(() => _lead = v ?? _lead),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<PrayerRecurrence>(
          initialValue: _recurrence,
          decoration: const InputDecoration(labelText: 'Repeat'),
          items: const [
            DropdownMenuItem(
              value: PrayerRecurrence.daily,
              child: Text('Every day'),
            ),
            DropdownMenuItem(
              value: PrayerRecurrence.weekly,
              child: Text('Once a week'),
            ),
            DropdownMenuItem(
              value: PrayerRecurrence.custom,
              child: Text('Selected days'),
            ),
            DropdownMenuItem(
              value: PrayerRecurrence.monthly,
              child: Text('Every month'),
            ),
            DropdownMenuItem(
              value: PrayerRecurrence.once,
              child: Text('Only once'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _recurrence = v;
              if (v == PrayerRecurrence.weekly && _days.length != 1) {
                _days
                  ..clear()
                  ..add(DateTime.now().weekday);
              }
              if (v == PrayerRecurrence.custom && _days.isEmpty) {
                _days.add(DateTime.now().weekday);
              }
            });
          },
        ),
        if (needsDate) ...[
          const SizedBox(height: AppSpacing.md),
          DateField(
            label: _recurrence == PrayerRecurrence.monthly
                ? 'Day of month (from this date)'
                : 'Date',
            value: _date,
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
            onChanged: (d) => setState(() => _date = d),
          ),
        ],
        if (needsDays) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            children: [
              for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                FilterChip(
                  label: Text(_weekdayShort(d)),
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() {
                    if (_recurrence == PrayerRecurrence.weekly) {
                      _days
                        ..clear()
                        ..add(d);
                    } else if (v) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminder on'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save reminder'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Alerts are checked and re-planned every time you open DayLee.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
