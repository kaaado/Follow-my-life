import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:follow_my_life/app/theme/app_colors.dart';
import 'package:follow_my_life/app/theme/app_spacing.dart';
import 'package:follow_my_life/app/theme/app_typography.dart';
import 'package:follow_my_life/core/localization/app_localizations.dart';
import 'package:follow_my_life/core/providers/core_providers.dart';
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
  String? _connectedIdentifier;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final supabaseService = ref.read(supabaseBackupServiceProvider);
    final backupService = ref.read(backupServiceProvider);

    final id = await supabaseService.getCurrentIdentifier();
    final lastTime = await backupService.getLastBackupTimestamp();

    if (mounted) {
      setState(() {
        _connectedIdentifier = id;
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
    final supabaseService = ref.watch(supabaseBackupServiceProvider);

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
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Connected Cloud Account Card
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
                                      color: _connectedIdentifier != null ? AppColors.success : AppColors.darkTextTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    _connectedIdentifier != null
                                        ? context.tr('connected_account')
                                        : context.tr('not_connected'),
                                    style: AppTypography.labelMedium(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (_connectedIdentifier != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: AppColors.error,
                                  ),
                                  icon: const Icon(LucideIcons.logOut, size: 14),
                                  label: Text(context.tr('sign_out')),
                                  onPressed: () async {
                                    await supabaseService.signOut();
                                    await _loadState();
                                    if (context.mounted) {
                                      AppFeedback.showSuccess(context, 'Signed out of cloud account.');
                                    }
                                  },
                                )
                              else
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: primaryColor,
                                  ),
                                  icon: const Icon(LucideIcons.userPlus, size: 14),
                                  label: Text(context.tr('sign_in_to_cloud')),
                                  onPressed: () => _showAuthDialog(context),
                                ),
                            ],
                          ),
                          if (_connectedIdentifier != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _connectedIdentifier!,
                              style: AppTypography.bodyLarge(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
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

                    const SizedBox(height: AppSpacing.xl),

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

                    const SizedBox(height: AppSpacing.xl),

                    // ─── Connection Info Footer ────────────────────────
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(LucideIcons.info, size: 14),
                        label: const Text('Supabase Direct Config & Setup'),
                        onPressed: () => _showSupabaseConfigDialog(context),
                      ),
                    ),
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
    if (_connectedIdentifier == null || _connectedIdentifier!.isEmpty) {
      _showAuthDialog(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Uploading encrypted snapshot to Supabase...';
    });

    final supabaseService = ref.read(supabaseBackupServiceProvider);
    final result = await supabaseService.uploadBackupToCloud();

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
    if (_connectedIdentifier == null || _connectedIdentifier!.isEmpty) {
      _showAuthDialog(context);
      return;
    }

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

    final supabaseService = ref.read(supabaseBackupServiceProvider);
    final result = await supabaseService.restoreLatestBackupFromCloud();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = null;
    });

    result.when(
      success: (_) {
        _invalidateAllProviders();
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

  // ─── Authentication & Identifier Dialog ──────────────────────────

  void _showAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _SupabaseAuthDialog(
          onSuccess: (identifier) async {
            await _loadState();
          },
        );
      },
    );
  }

  void _showSupabaseConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supabase Cloud Connection'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Ref: yyjhsexdlqpdbojpfngh', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('API URL: https://yyjhsexdlqpdbojpfngh.supabase.co'),
            SizedBox(height: 4),
            Text('Direct DB Host: db.yyjhsexdlqpdbojpfngh.supabase.co'),
            SizedBox(height: 4),
            Text('Port: 5432 | User: postgres | DB: postgres'),
            SizedBox(height: 12),
            Text(
              'Backups are securely synchronized to table: public.user_backups with SHA-256 integrity and Row Level Security.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SupabaseAuthDialog extends ConsumerStatefulWidget {
  final ValueChanged<String> onSuccess;

  const _SupabaseAuthDialog({required this.onSuccess});

  @override
  ConsumerState<_SupabaseAuthDialog> createState() => _SupabaseAuthDialogState();
}

class _SupabaseAuthDialogState extends ConsumerState<_SupabaseAuthDialog> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int _selectedTab = 0; // 0: Phone OTP, 1: Email/Password, 2: Direct Phone ID
  bool _otpSent = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final supabaseService = ref.read(supabaseBackupServiceProvider);

    return AlertDialog(
      title: Text(context.tr('sign_in_to_cloud')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tabs
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(context.tr('phone_otp_login'))),
                ButtonSegment(value: 1, label: Text(context.tr('sso_email_login'))),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedTab = set.first;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Tab 0: Phone + OTP
            if (_selectedTab == 0) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.tr('phone_number'),
                  hintText: '+213...',
                  prefixIcon: const Icon(LucideIcons.phone),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: context.tr('enter_otp'),
                    prefixIcon: const Icon(LucideIcons.key),
                  ),
                ),
              ],
            ],

            // Tab 1: Email / SSO
            if (_selectedTab == 1) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(LucideIcons.mail),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),

        // Submit action
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    if (_selectedTab == 0) {
                      final phone = _phoneController.text.trim();
                      if (phone.isEmpty) {
                        AppFeedback.showError(context, 'Please enter a valid phone number.');
                        return;
                      }

                      if (!_otpSent) {
                        final res = await supabaseService.signInWithPhoneOtp(phone);
                        if (res.isSuccess) {
                          setState(() => _otpSent = true);
                          if (context.mounted) {
                            AppFeedback.showSuccess(context, 'OTP code sent to $phone.');
                          }
                        } else {
                          // If SMS gateway not configured, offer direct phone backup identity
                          await supabaseService.setPhoneIdentifier(phone);
                          widget.onSuccess(phone);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AppFeedback.showSuccess(context, 'Phone identity $phone saved for cloud backup.');
                          }
                        }
                      } else {
                        final code = _otpController.text.trim();
                        final verifyRes = await supabaseService.verifyPhoneOtp(
                          phoneNumber: phone,
                          token: code,
                        );
                        if (verifyRes.isSuccess) {
                          widget.onSuccess(phone);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AppFeedback.showSuccess(context, 'Verified successfully!');
                          }
                        } else {
                          if (context.mounted) {
                            AppFeedback.showError(context, verifyRes.failure.message);
                          }
                        }
                      }
                    } else if (_selectedTab == 1) {
                      final email = _emailController.text.trim();
                      final password = _passwordController.text;

                      final res = await supabaseService.signInWithEmailPassword(
                        email: email,
                        password: password,
                      );

                      if (res.isSuccess) {
                        widget.onSuccess(email);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          AppFeedback.showSuccess(context, 'Signed in successfully!');
                        }
                      } else {
                        // Try sign up if sign in failed
                        final signUpRes = await supabaseService.signUpWithEmail(
                          email: email,
                          password: password,
                        );
                        if (signUpRes.isSuccess) {
                          widget.onSuccess(email);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AppFeedback.showSuccess(context, 'Account created and connected!');
                          }
                        } else {
                          if (context.mounted) {
                            AppFeedback.showError(context, res.failure.message);
                          }
                        }
                      }
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: Text(
            _selectedTab == 0
                ? (_otpSent ? context.tr('verify_otp') : context.tr('send_otp'))
                : context.tr('verify_otp'),
          ),
        ),
      ],
    );
  }
}
