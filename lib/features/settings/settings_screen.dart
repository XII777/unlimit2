import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/tokens.dart';
import '../../data/permissions_providers.dart';
import '../../data/home_data_providers.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(allPermissionsProvider);
    final profile = ref.watch(profileProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Local profile · not synced', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),

          _SectionLabel('PROFILE'),
          const SizedBox(height: 8),
          _Card(
            children: [
              profile.when(
                data: (p) => _ProfileRow(
                  displayName: p?.displayName ?? 'You',
                  budgetMinutes: p?.dailyBudgetMinutes ?? 240,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Could not load profile'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('PERMISSIONS'),
          const SizedBox(height: 8),
          _Card(
            children: [
              for (final p in permissions)
                _PermissionRow(
                  label: _labelFor(p.kind),
                  granted: p.granted,
                  loading: p.loading,
                ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('DATA'),
          const SizedBox(height: 8),
          const _Card(
            children: [
              _NavRow(icon: Icons.save_alt_rounded, label: 'Backup to file'),
              _RowDivider(),
              _NavRow(icon: Icons.file_upload_rounded, label: 'Restore from file'),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel('ABOUT'),
          const SizedBox(height: 8),
          const _Card(
            children: [
              _NavRow(icon: Icons.star_rounded, label: 'Rate Ulimit'),
              _RowDivider(),
              _NavRow(icon: Icons.privacy_tip_rounded, label: 'Privacy policy'),
              _RowDivider(),
              _StaticRow(label: 'Version', value: '0.1.0'),
            ],
          ),
          const SizedBox(height: 20),

          Center(
            child: TextButton(
              onPressed: () => _confirmReset(context, ref),
              child: const Text('Reset all data',
                  style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
            'This will delete your focus history, app usage, and settings. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Wire to AppDatabase wipe
              Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  String _labelFor(PermissionKind kind) => switch (kind) {
        PermissionKind.accessibility => 'Accessibility',
        PermissionKind.vpn => 'VPN & network',
        PermissionKind.deviceAdmin => 'Device admin',
        PermissionKind.notificationListener => 'Notification access',
        PermissionKind.biometric => 'Biometrics',
      };
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.displayName, required this.budgetMinutes});
  final String displayName;
  final int budgetMinutes;

  @override
  Widget build(BuildContext context) {
    final hours = budgetMinutes ~/ 60;
    final minutes = budgetMinutes % 60;
    final budgetText = minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 16, color: AppColors.inkDim),
              const SizedBox(width: 12),
              Expanded(
                child: Text(displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => _editProfile(context),
                child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_rounded, size: 16, color: AppColors.inkDim),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Daily budget',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => _editBudget(context),
                child: Text(budgetText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _EditProfileDialog(),
    );
  }

  void _editBudget(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _EditBudgetDialog(),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog();

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Your name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () {
              final name = _controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(databaseProvider).setDisplayName(name);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _EditBudgetDialog extends StatefulWidget {
  const _EditBudgetDialog();

  @override
  State<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends State<_EditBudgetDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = 4;
    _minutes = 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily budget'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: DropdownButton<int>(
              value: _hours,
              items: [for (var h = 0; h <= 12; h++) DropdownMenuItem(value: h, child: Text('${h}h'))],
              onChanged: (v) => setState(() => _hours = v ?? 0),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: DropdownButton<int>(
              value: _minutes,
              items: [0, 15, 30, 45]
                  .map((m) => DropdownMenuItem(value: m, child: Text('${m}m')))
                  .toList(),
              onChanged: (v) => setState(() => _minutes = v ?? 0),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () {
              ref.read(databaseProvider).setDailyBudgetMinutes(_hours * 60 + _minutes);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.labelSmall);
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.stroke),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, color: AppColors.stroke);
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted, required this.loading});
  final String label;
  final bool granted;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13))),
          if (loading)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(
              granted ? 'Granted' : 'Pending',
              style: TextStyle(fontSize: 10.5, color: granted ? AppColors.accent : AppColors.alert),
            ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.inkDim),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13))),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _StaticRow extends StatelessWidget {
  const _StaticRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13))),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
