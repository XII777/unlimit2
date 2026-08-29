import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/native/blocklist_channel.dart';
import '../core/native/permissions_channel.dart';
import 'db/app_database.dart';
import 'db/tables.dart';

/// Single DB instance for the app's lifetime. `keepAlive` so switching
/// tabs doesn't tear down and reopen the SQLite connection — that
/// reopen cost is exactly the kind of jank a "don't make it lag"
/// requirement is about.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Today's total foreground time across all tracked apps, as a live
/// stream — Drift's .watch() pushes updates only when the underlying
/// rows change, so the ring on Home updates in real time without
/// polling.
final todayScreenTimeProvider = StreamProvider<Duration>((ref) {
  final db = ref.watch(databaseProvider);
  final startOfDay = _startOfDay(DateTime.now());

  final query = db.select(db.appUsage)..where((t) => t.day.equals(startOfDay));

  return query.watch().map(
        (rows) => Duration(seconds: rows.fold(0, (sum, r) => sum + r.foregroundSeconds)),
      );
});

/// Last 7 days of total foreground time, oldest first — feeds Home's
/// weekly trend chart. One GROUP-BY-shaped query instead of 7 separate
/// day lookups.
final weeklyScreenTimeProvider = StreamProvider<List<Duration>>((ref) {
  final db = ref.watch(databaseProvider);
  final today = _startOfDay(DateTime.now());
  final start = today.subtract(const Duration(days: 6));

  final query = db.select(db.appUsage)..where((t) => t.day.isBiggerOrEqualValue(start));

  return query.watch().map((rows) => _bucketByDay(rows.map((r) => (r.day, r.foregroundSeconds)), start));
});

/// The 7 days before [weeklyScreenTimeProvider]'s window — used only to
/// compute the "vs last week" delta shown next to the weekly chart, so
/// that delta is a real comparison rather than a made-up percentage.
final previousWeekScreenTimeAvgProvider = StreamProvider<Duration>((ref) {
  final db = ref.watch(databaseProvider);
  final today = _startOfDay(DateTime.now());
  final start = today.subtract(const Duration(days: 13));
  final end = today.subtract(const Duration(days: 6));

  final query = db.select(db.appUsage)
    ..where((t) => t.day.isBiggerOrEqualValue(start) & t.day.isSmallerThanValue(end));

  return query.watch().map((rows) {
    final total = rows.fold(0, (sum, r) => sum + r.foregroundSeconds);
    return Duration(seconds: total ~/ 7);
  });
});

/// Last 7 days of completed-focus-session time, oldest first. Falls
/// back to `plannedSeconds` for a session with no `endedAt` yet (in
/// progress) so an active session doesn't read as zero minutes.
final weeklyFocusTimeProvider = StreamProvider<List<Duration>>((ref) {
  final db = ref.watch(databaseProvider);
  final today = _startOfDay(DateTime.now());
  final start = today.subtract(const Duration(days: 6));

  final query = db.select(db.focusSessions)
    ..where((t) => t.completed.equals(true) & t.startedAt.isBiggerOrEqualValue(start));

  return query.watch().map((rows) {
    final entries = rows.map((r) {
      final seconds = r.endedAt != null ? r.endedAt!.difference(r.startedAt).inSeconds : r.plannedSeconds;
      return (r.startedAt, seconds);
    });
    return _bucketByDay(entries, start);
  });
});

/// Previous-week counterpart to [weeklyFocusTimeProvider], for its delta.
final previousWeekFocusTimeAvgProvider = StreamProvider<Duration>((ref) {
  final db = ref.watch(databaseProvider);
  final today = _startOfDay(DateTime.now());
  final start = today.subtract(const Duration(days: 13));
  final end = today.subtract(const Duration(days: 6));

  final query = db.select(db.focusSessions)
    ..where((t) =>
        t.completed.equals(true) & t.startedAt.isBiggerOrEqualValue(start) & t.startedAt.isSmallerThanValue(end));

  return query.watch().map((rows) {
    final total = rows.fold<int>(0, (sum, r) {
      final seconds = r.endedAt != null ? r.endedAt!.difference(r.startedAt).inSeconds : r.plannedSeconds;
      return sum + seconds;
    });
    return Duration(seconds: total ~/ 7);
  });
});

/// Count of focus sessions completed so far today — feeds both Home's
/// "N sessions" pill and Focus's "today's sessions" dot row.
final todaysCompletedSessionsProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final start = _startOfDay(DateTime.now());
  final end = start.add(const Duration(days: 1));

  final query = db.select(db.focusSessions)
    ..where((t) =>
        t.completed.equals(true) & t.startedAt.isBiggerOrEqualValue(start) & t.startedAt.isSmallerThanValue(end));

  return query.watch().map((rows) => rows.length);
});

/// Today's completed focus sessions as a live list — drives the Focus
/// screen's session dots from real data instead of a hardcoded count.
final todaysSessionsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  final start = _startOfDay(DateTime.now());
  final end = start.add(const Duration(days: 1));

  final query = db.select(db.focusSessions)
    ..where((t) =>
        t.completed.equals(true) & t.startedAt.isBiggerOrEqualValue(start) & t.startedAt.isSmallerThanValue(end))
    ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);

  return query.watch();
});

/// The currently-active (in-progress) focus session, if any — drives the
/// Focus screen's ring from a real DB row instead of local state.
final activeSessionProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.focusSessions)
    ..where((t) => t.completed.equals(false) & t.endedAt.isNull())
    ..limit(1);
  return query.watchSingleOrNull();
});

/// Auto-enables notification batching when a focus session is active.
/// Watches activeSessionProvider and pushes the batching state to the
/// native NotificationListenerService.
final notificationBatchingProvider = Provider((ref) {
  final active = ref.watch(activeSessionProvider).valueOrNull;
  final isActive = active != null;
  NativePermissions.setNotificationBatching(isActive, reason: 'focus');
  return isActive;
});

/// Focus session actions — start, complete, abandon. Each writes a real
/// row so history survives app restarts and feeds todaysSessionsProvider.
extension FocusSessionActions on AppDatabase {
  Future<void> startFocusSession({
    required String label,
    required int plannedSeconds,
    bool invincible = false,
  }) async {
    await into(focusSessions).insert(FocusSessionsCompanion.insert(
      label: label,
      startedAt: DateTime.now(),
      plannedSeconds: plannedSeconds,
      invincible: Value(invincible),
    ));
  }

  Future<void> completeActiveSession() async {
    final active = await (select(focusSessions)
          ..where((t) => t.completed.equals(false) & t.endedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (active == null) return;
    await (update(focusSessions)..where((t) => t.id.equals(active.id)))
        .write(FocusSessionsCompanion(
          endedAt: Value(DateTime.now()),
          completed: const Value(true),
        ));
  }

  Future<void> abandonActiveSession() async {
    final active = await (select(focusSessions)
          ..where((t) => t.completed.equals(false) & t.endedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (active == null) return;
    await (update(focusSessions)..where((t) => t.id.equals(active.id)))
        .write(FocusSessionsCompanion(
          endedAt: Value(DateTime.now()),
          completed: const Value(false),
        ));
  }
}

/// Restriction group + blocked apps management. These write real rows
/// that the enforcement layer (AccessibilityService overlay) reads from.
extension RestrictionActions on AppDatabase {
  Future<void> addRestrictionGroup({
    required String name,
    required int dailyLimitSeconds,
    bool invincible = false,
  }) async {
    await into(restrictionGroups).insert(RestrictionGroupsCompanion.insert(
      name: name,
      dailyLimitSeconds: dailyLimitSeconds,
      invincible: Value(invincible),
    ));
  }

  Future<void> updateRestrictionGroup(
    int id, {
    String? name,
    int? dailyLimitSeconds,
    bool? invincible,
  }) async {
    await (update(restrictionGroups)..where((t) => t.id.equals(id)))
        .write(RestrictionGroupsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      dailyLimitSeconds: dailyLimitSeconds != null ? Value(dailyLimitSeconds) : const Value.absent(),
      invincible: invincible != null ? Value(invincible) : const Value.absent(),
    ));
  }

  Future<void> deleteRestrictionGroup(int id) async {
    await (delete(restrictionGroupApps)..where((t) => t.groupId.equals(id))).go();
    await (delete(restrictionGroups)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addAppToGroup(int groupId, String packageName) async {
    await into(restrictionGroupApps).insert(
      RestrictionGroupAppsCompanion.insert(groupId: groupId, packageName: packageName),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeAppFromGroup(int groupId, String packageName) async {
    await (delete(restrictionGroupApps)
          ..where((t) => t.groupId.equals(groupId) & t.packageName.equals(packageName)))
        .go();
  }

  Future<void> addBlockedApp({
    required String packageName,
    String? scheduleStart,
    String? scheduleEnd,
  }) async {
    await into(blockedApps).insert(
      BlockedAppsCompanion.insert(
        packageName: packageName,
        scheduleStart: Value(scheduleStart),
        scheduleEnd: Value(scheduleEnd),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> setBlockedAppEnabled(String packageName, bool enabled) async {
    await (update(blockedApps)..where((t) => t.packageName.equals(packageName)))
        .write(BlockedAppsCompanion(enabled: Value(enabled)));
  }

  Future<void> removeBlockedApp(String packageName) async {
    await (delete(blockedApps)..where((t) => t.packageName.equals(packageName))).go();
  }
}

/// Turns a stream of (day, seconds) rows into a fixed 7-slot list
/// starting at [start], zero-filling any day with no rows. Shared by
/// both weekly providers above so "bucket into a 7-day window" is
/// implemented once.
List<Duration> _bucketByDay(Iterable<(DateTime, int)> entries, DateTime start) {
  final byDay = <DateTime, int>{for (var i = 0; i <= 6; i++) start.add(Duration(days: i)): 0};
  for (final (day, seconds) in entries) {
    final d = _startOfDay(day);
    byDay[d] = (byDay[d] ?? 0) + seconds;
  }
  final orderedDays = byDay.keys.toList()..sort();
  return [for (final d in orderedDays) Duration(seconds: byDay[d]!)];
}

/// One restriction group with today's live usage joined in. Replaces
/// the Limits screen's hardcoded group list — `packageNames` drives the
/// icon row, `usedSeconds`/`limitSeconds` drive the bar and its color.
class RestrictionGroupView {
  const RestrictionGroupView({
    required this.name,
    required this.usedSeconds,
    required this.limitSeconds,
    required this.invincible,
    required this.packageNames,
  });

  final String name;
  final int usedSeconds;
  final int limitSeconds;
  final bool invincible;
  final List<String> packageNames;
}

final restrictionGroupsProvider = StreamProvider<List<RestrictionGroupView>>((ref) {
  final db = ref.watch(databaseProvider);
  final today = _startOfDay(DateTime.now());

  // One joined query rather than combining separate group/usage streams
  // — keeps this a single reactive source instead of hand-rolled stream
  // combination.
  final query = db.customSelect(
    '''
    SELECT rg.id AS group_id, rg.name AS name, rg.daily_limit_seconds AS daily_limit_seconds,
           rg.invincible AS invincible, rga.package_name AS package_name,
           COALESCE(usage.foreground_seconds, 0) AS pkg_seconds
    FROM restriction_groups rg
    LEFT JOIN restriction_group_apps rga ON rga.group_id = rg.id
    LEFT JOIN app_usage usage ON usage.package_name = rga.package_name AND usage.day = ?
    ORDER BY rg.id
    ''',
    variables: [Variable.withDateTime(today)],
    readsFrom: {db.restrictionGroups, db.restrictionGroupApps, db.appUsage},
  );

  return query.watch().map((rows) {
    final byGroup = <int, _MutableGroup>{};
    final order = <int>[];

    for (final row in rows) {
      final id = row.read<int>('group_id');
      final group = byGroup.putIfAbsent(id, () {
        order.add(id);
        return _MutableGroup(
          name: row.read<String>('name'),
          limitSeconds: row.read<int>('daily_limit_seconds'),
          invincible: row.read<bool>('invincible'),
        );
      });

      final pkg = row.readNullable<String>('package_name');
      if (pkg != null) {
        group.packageNames.add(pkg);
        group.usedSeconds += row.read<int>('pkg_seconds');
      }
    }

    return [for (final id in order) byGroup[id]!.toView()];
  });
});

class _MutableGroup {
  _MutableGroup({required this.name, required this.limitSeconds, required this.invincible});
  final String name;
  final int limitSeconds;
  final bool invincible;
  int usedSeconds = 0;
  final List<String> packageNames = [];

  RestrictionGroupView toView() => RestrictionGroupView(
        name: name,
        usedSeconds: usedSeconds,
        limitSeconds: limitSeconds,
        invincible: invincible,
        packageNames: packageNames,
      );
}

/// Count of enabled entries in [BlockedApps] — feeds the "App Blocking"
/// control tile's subtitle on Home.
final blockedAppsCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.blockedApps)..where((t) => t.enabled.equals(true));
  return query.watch().map((rows) => rows.length);
});

/// Full list of all blocked apps (enabled or not) — drives the Blocked
/// Apps management UI.
final blockedAppsProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.blockedApps)..orderBy([(t) => OrderingTerm.asc(t.packageName)]);
  return query.watch();
});

/// Auto-syncs the blocked-apps list to the native AccessibilityService
/// whenever it changes. The service reads this cached set on every
/// foreground-app transition to decide whether to show the block overlay.
final blocklistSyncProvider = Provider((ref) {
  final apps = ref.watch(blockedAppsProvider);
  final data = apps.valueOrNull;
  if (data != null && data.isNotEmpty) {
    final enabled = data.where((a) => a.enabled).map((a) => a.packageName).toList();
    NativeBlocklist.syncBlocklist(enabled, data.any((a) => a.enabled));
  }
  return data;
});

/// Drains emergency unlocks from native and writes them to the DB. Polled
/// periodically while the app is in the foreground.
final emergencyUnlocksSyncProvider = Provider((ref) {
  Future.microtask(() async {
    final unlocks = await NativeBlocklist.drainEmergencyUnlocks();
    final db = ref.read(databaseProvider);
    for (final u in unlocks) {
      final pkg = u['package'] as String?;
      final ts = u['timestamp'] as int?;
      if (pkg == null || ts == null) continue;
      await db.into(db.emergencyUnlocks).insert(EmergencyUnlocksCompanion.insert(
        usedAt: DateTime.fromMillisecondsSinceEpoch(ts),
        packageName: pkg,
        grantedSeconds: 300, // 5-minute emergency window
      ));
    }
  });
  return null;
});

/// All installed apps that aren't already in a given restriction group —
/// drives the "add app to group" picker. Queried via PackageManager on
/// native side, passed back through MethodChannel.
final installedAppsProvider = FutureProvider<List<InstalledApp>>((ref) {
  return _fetchInstalledApps();
});

class InstalledApp {
  const InstalledApp({required this.packageName, required this.label});
  final String packageName;
  final String label;
}

Future<List<InstalledApp>> _fetchInstalledApps() async {
  // Placeholder — real implementation calls native PackageManager
  // via MethodChannel. Returns common social/media apps as defaults
  // so the picker has data even before native wiring lands.
  return const [
    InstalledApp(packageName: 'com.instagram.android', label: 'Instagram'),
    InstalledApp(packageName: 'com.zhiliaoapp.musically', label: 'TikTok'),
    InstalledApp(packageName: 'com.twitter.android', label: 'X (Twitter)'),
    InstalledApp(packageName: 'com.google.android.youtube', label: 'YouTube'),
    InstalledApp(packageName: 'com.netflix.mediaclient', label: 'Netflix'),
    InstalledApp(packageName: 'com.snapchat.android', label: 'Snapchat'),
    InstalledApp(packageName: 'com.facebook.katana', label: 'Facebook'),
    InstalledApp(packageName: 'com.discord', label: 'Discord'),
    InstalledApp(packageName: 'com.reddit.frontpage', label: 'Reddit'),
    InstalledApp(packageName: 'com.pinterest', label: 'Pinterest'),
  ];
}

/// The single [BedtimeSchedule] row (singleton, like [Profile]) — null
/// until the first toggle write creates it.
final bedtimeScheduleProvider = StreamProvider<BedtimeScheduleData?>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.bedtimeSchedule)..limit(1);
  return query.watch().map((rows) => rows.isEmpty ? null : rows.first);
});

extension BedtimeScheduleActions on AppDatabase {
  Future<void> _ensureBedtimeRow() async {
    final existing = await (select(bedtimeSchedule)..limit(1)).getSingleOrNull();
    if (existing == null) {
      await into(bedtimeSchedule).insert(
        BedtimeScheduleCompanion.insert(startTime: '22:30', endTime: '06:30'),
      );
    }
  }

  Future<void> setDndEnabled(bool value) async {
    await _ensureBedtimeRow();
    await update(bedtimeSchedule).write(BedtimeScheduleCompanion(dndEnabled: Value(value)));
  }

  Future<void> setPauseApps(bool value) async {
    await _ensureBedtimeRow();
    await update(bedtimeSchedule).write(BedtimeScheduleCompanion(pauseApps: Value(value)));
  }

  Future<void> setGrayscale(bool value) async {
    await _ensureBedtimeRow();
    await update(bedtimeSchedule).write(BedtimeScheduleCompanion(grayscale: Value(value)));
  }
}
