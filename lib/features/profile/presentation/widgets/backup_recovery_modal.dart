import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
import 'package:follow_my_life/core/storage/supabase_backup_service.dart';
import 'package:follow_my_life/core/widgets/app_feedback.dart';
import 'package:follow_my_life/features/finance/application/providers/finance_providers.dart';

class BackupRecoveryModal extends ConsumerStatefulWidget {
  const BackupRecoveryModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BackupRecoveryModal(),
    );
  }

  @override
  ConsumerState<BackupRecoveryModal> createState() => _BackupRecoveryModalState();
}

class _BackupRecoveryModalState extends ConsumerState<BackupRecoveryModal> {
  bool _isLoading = false;
  String? _statusMessage;
  String? _syncKey;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final supabaseService = ref.read(supabaseBackupServiceProvider);
    final backupService = ref.read(backupServiceProvider);

    final key = await supabaseService.getSyncKey();
    final lastTime = await backupService.getLastBackupTimestamp();

    if (mounted) {
      setState(() {
        _syncKey = key;
        _lastBackupTime = lastTime;
      });
    }
  }

  void _invalidateAllProviders() {
    ref.invalidate(profileProvider);
    ref.invalidate(activeSourcesProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(activePurchasesProvider);
    ref.invalidate(activeBudgetsProvider);
    ref.invalidate(activeRecurringProvider);
    ref.invalidate(activeDebtsProvider);
    ref.invalidate(activeVirtualSplitsProvider);
    ref.invalidate(financialSnapshotProvider);
    ref.invalidate(financialSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backupService = ref.watch(backupServiceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(LucideIcons.cloud, color: primaryColor, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      context.tr('cloud_backup_recovery'),
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _statusMessage ?? context.tr('syncing'),
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ─── Section 1: Supabase Cloud Backup & Recovery ───
                    _buildSectionHeader(
                      context.tr('supabase_cloud_sync'),
                      LucideIcons.database,
                      primaryColor,
                      isDark,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.tr('supabase_cloud_desc'),
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Cloud Online Switch Tile
                    FutureBuilder<bool>(
                      future: backupService.isOnlineBackupEnabled(),
                      builder: (ctx, snapshot) {
                        final isEnabled = snapshot.data ?? false;
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: SwitchListTile(
                              title: Text(
                                context.tr('online_backup'),
                                style: AppTypography.bodyMedium(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                isEnabled
                                    ? context.tr('online_backup_enabled')
                                    : context.tr('online_backup_disabled'),
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                              ),
                              value: isEnabled,
                              onChanged: (val) async {
                                await backupService.setOnlineBackupEnabled(val);
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Connected Cloud Sync Key Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_syncKey != null && _syncKey!.isNotEmpty)
                                          ? AppColors.success
                                          : AppColors.darkTextTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    (_syncKey != null && _syncKey!.isNotEmpty)
                                        ? context.tr('connected_account')
                                        : context.tr('not_connected'),
                                    style: AppTypography.labelMedium(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: primaryColor,
                                ),
                                icon: const Icon(LucideIcons.edit3, size: 14),
                                label: Text(context.tr('change_sync_key')),
                                onPressed: () => _showSyncKeyDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Monospace Key Box with Copy
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.grey.shade100).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.keyRound, size: 18, color: primaryColor),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: SelectableText(
                                    _syncKey ?? '...',
                                    style: AppTypography.bodyMedium(
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ).copyWith(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.copy, size: 18),
                                  tooltip: context.tr('copy_sync_key'),
                                  onPressed: () {
                                    if (_syncKey != null && _syncKey!.isNotEmpty) {
                                      Clipboard.setData(ClipboardData(text: _syncKey!));
                                      AppFeedback.showSuccess(context, context.tr('sync_key_copied'));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            context.tr('sync_key_help'),
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${context.tr('last_backup')}: ${_lastBackupTime != null ? _formatDate(_lastBackupTime!) : context.tr('never_backed_up')}',
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Cloud Actions Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(LucideIcons.uploadCloud, size: 16),
                                  label: Text(context.tr('backup_now_cloud')),
                                  onPressed: _isLoading ? null : () => _handleCloudUpload(context),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(LucideIcons.downloadCloud, size: 16),
                                  label: Text(context.tr('restore_from_cloud')),
                                  onPressed: _isLoading ? null : () => _handleCloudRestore(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Quick switch / connect another device key
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(LucideIcons.smartphone, size: 16),
                        label: Text(context.tr('enter_sync_key')),
                        onPressed: () => _showSyncKeyDialog(context),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ─── Section 2: Local File Backup & Recovery ───────
                    _buildSectionHeader(
                      context.tr('export_backup'),
                      LucideIcons.hardDrive,
                      AppColors.info,
                      isDark,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.tr('backup_json_desc'),
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                  icon: const Icon(LucideIcons.share2, size: 16),
                                  label: Text(context.tr('export_file_on_phone')),
                                  onPressed: () => _handleExportToFile(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(LucideIcons.fileInput, size: 16),
                                  label: Text(context.tr('import_file_from_phone')),
                                  onPressed: () => _handleImportFromFile(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.headlineSmall(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─── Cloud Sync Actions ──────────────────────────────────────────

  Future<void> _handleCloudUpload(BuildContext context) async {
    final supabaseService = ref.read(supabaseBackupServiceProvider);
    final key = _syncKey ?? await supabaseService.getSyncKey();
    if (!context.mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Uploading snapshot to Supabase...';
    });

    final result = await supabaseService.uploadBackupToCloud(syncKey: key);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = null;
    });

    result.when(
      success: (summary) {
        _loadState();
        AppFeedback.showSuccess(
          context,
          '${context.tr('cloud_backup_success')} (${summary.totalRecords} records synced)',
        );
      },
      failure: (err) {
        AppFeedback.showError(context, err.message);
      },
    );
  }

  Future<void> _handleCloudRestore(BuildContext context) async {
    final supabaseService = ref.read(supabaseBackupServiceProvider);
    final key = _syncKey ?? await supabaseService.getSyncKey();
    if (!context.mounted) return;

    // Confirmation dialog before overwriting local data
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('cloud_restore_confirm')),
        content: Text(context.tr('cloud_restore_confirm_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.tr('restore_from_cloud')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching and validating cloud snapshot...';
    });

    final result = await supabaseService.restoreLatestBackupFromCloud(syncKey: key);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = null;
    });

    result.when(
      success: (_) {
        _invalidateAllProviders();
        _loadState();
        AppFeedback.showSuccess(context, context.tr('cloud_restore_success'));
      },
      failure: (err) {
        AppFeedback.showError(context, err.message);
      },
    );
  }

  // ─── Local File Actions ──────────────────────────────────────────

  Future<void> _handleExportToFile(BuildContext context) async {
    final backupService = ref.read(backupServiceProvider);
    final exportResult = await backupService.exportBackupToFile();

    if (!context.mounted) return;

    exportResult.when(
      success: (path) async {
        AppFeedback.showSuccess(
          context,
          '${context.tr('backup_export_saved')}\n${context.tr('file_saved_at')}$path',
        );
        try {
          await Share.shareXFiles(
            [XFile(path, mimeType: 'application/json', name: 'follow_my_life_backup.json')],
            text: 'Follow My Life Database Backup',
          );
        } catch (_) {}
      },
      failure: (err) {
        AppFeedback.showError(context, err.message);
      },
    );
  }

  Future<void> _handleImportFromFile(BuildContext context) async {
    final backupService = ref.read(backupServiceProvider);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'fml'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonContent = await file.readAsString();
        final restoreResult = await backupService.restoreBackup(jsonContent);

        if (!context.mounted) return;

        restoreResult.when(
          success: (_) {
            _invalidateAllProviders();
            AppFeedback.showSuccess(context, context.tr('backup_imported'));
          },
          failure: (err) {
            AppFeedback.showError(context, err.message);
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'Failed to read backup file: ${e.toString()}');
      }
    }
  }

  // ─── Modals ──────────────────────────────────────────────────────

  void _showSyncKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _SyncKeyDialog(
          currentKey: _syncKey ?? '',
          onSaved: (newKey) async {
            await _loadState();
          },
        );
      },
    );
  }
}

// ─── Sync Key Dialog (Enter or Generate Key) ───────────────────────

class _SyncKeyDialog extends ConsumerStatefulWidget {
  final String currentKey;
  final ValueChanged<String> onSaved;

  const _SyncKeyDialog({required this.currentKey, required this.onSaved});

  @override
  ConsumerState<_SyncKeyDialog> createState() => _SyncKeyDialogState();
}

class _SyncKeyDialogState extends ConsumerState<_SyncKeyDialog> {
  late final TextEditingController _keyController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.currentKey);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = ref.read(supabaseBackupServiceProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.keyRound, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(context.tr('cloud_sync_key')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('sync_key_help'),
              style: AppTypography.bodySmall(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: context.tr('cloud_sync_key'),
                hintText: 'e.g. fml-a3b8cd or your custom key',
                prefixIcon: const Icon(LucideIcons.key),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  tooltip: context.tr('generate_random_key'),
                  onPressed: () {
                    final newKey = SupabaseBackupService.generateRandomSyncKey();
                    _keyController.text = newKey;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () async {
            final text = _keyController.text.trim();
            if (text.isEmpty) {
              AppFeedback.showError(context, 'Key cannot be empty');
              return;
            }
            await supabaseService.setSyncKey(text);
            widget.onSaved(text);
            if (context.mounted) {
              Navigator.of(context).pop();
              AppFeedback.showSuccess(context, 'Sync Key updated successfully!');
            }
          },
          child: Text(context.tr('connect_key')),
        ),
      ],
    );
  }
}

