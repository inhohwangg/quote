import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_provider.dart';
import '../providers/purchase_provider.dart';
import '../services/drive_backup_service.dart';

// Screen-scoped provider so each Settings instance has its own Drive client.
final _driveProvider = Provider.autoDispose<DriveBackupService>(
  (_) => DriveBackupService(),
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _backupBusy = false;
  bool _restoreBusy = false;

  DriveBackupService get _drive => ref.read(_driveProvider);

  String? get _signedInEmail =>
      _drive.currentUser?.email;

  // ---------- Google Drive actions ----------

  Future<void> _signIn() async {
    await _drive.signIn();
    setState(() {});
  }

  Future<void> _signOut() async {
    await _drive.signOut();
    setState(() {});
  }

  Future<void> _backup() async {
    setState(() => _backupBusy = true);
    try {
      final notes = ref.read(notesProvider);
      await _drive.backup(notes);
      _toast('✓ 백업 완료', success: true);
    } catch (e) {
      _toast('백업 실패: $e');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await _confirmDialog(
      title: '복원 확인',
      message: '현재 기기의 메모가 백업 데이터로 덮어씌워집니다.\n계속할까요?',
      destructive: true,
      action: '복원',
    );
    if (!confirmed) return;

    setState(() => _restoreBusy = true);
    try {
      final notes = await _drive.restore();
      await ref.read(notesProvider.notifier).restoreFromBackup(notes);
      _toast('✓ 복원 완료 (${notes.length}개)', success: true);
    } catch (e) {
      _toast('복원 실패: $e');
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  // ---------- Premium purchase ----------

  Future<void> _buyPremium() async {
    try {
      await ref.read(isPremiumProvider.notifier).buy();
    } catch (e) {
      _toast('구매 실패: $e');
    }
  }

  // ---------- Helpers ----------

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green.shade700 : null,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(
                color: destructive ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final cs = Theme.of(context).colorScheme;
    final email = _signedInEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Google Drive ─────────────────────────────────────────
          _Section('Google Drive 백업'),

          if (email != null) ...[
            // Signed-in state
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  email[0].toUpperCase(),
                  style: TextStyle(color: cs.primary),
                ),
              ),
              title: Text(
                email,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('연동됨'),
              trailing: TextButton(
                onPressed: _signOut,
                child: const Text('연결 해제'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: '지금 백업',
                    icon: Icons.cloud_upload_outlined,
                    loading: _backupBusy,
                    onPressed: _backup,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: '복원',
                    icon: Icons.cloud_download_outlined,
                    loading: _restoreBusy,
                    onPressed: _restore,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Signed-out state
            OutlinedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Google 계정으로 로그인'),
              onPressed: _signIn,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                '메모를 Google Drive의 앱 전용 공간에 안전하게 저장합니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── 프리미엄 ─────────────────────────────────────────────
          _Section('프리미엄'),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPremium
                            ? Icons.workspace_premium
                            : Icons.workspace_premium_outlined,
                        color: isPremium ? Colors.amber.shade600 : cs.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPremium ? '프리미엄 이용 중' : '광고 없는 메모 경험',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPremium
                        ? '광고 없이 깔끔하게 메모를 사용하고 있습니다.'
                        : '단 한 번의 결제로 모든 광고를 영구 제거합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                  if (!isPremium) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('광고 제거 구매'),
                        onPressed: _buyPremium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── 앱 정보 ──────────────────────────────────────────────
          _Section('앱 정보'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('버전'),
            trailing: const Text('2.0.0', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      onPressed: loading ? null : onPressed,
    );
  }
}
