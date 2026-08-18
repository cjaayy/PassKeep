import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../providers/supabase_auth_providers.dart';

/// Modal bottom sheet allowing users to Sign In or Register a Supabase account
class SupabaseAuthSheet extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const SupabaseAuthSheet({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<SupabaseAuthSheet> createState() => _SupabaseAuthSheetState();
}

class _SupabaseAuthSheetState extends ConsumerState<SupabaseAuthSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Sign In controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  bool _signInObscurePassword = true;

  // Sign Up controllers
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  bool _signUpObscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    final success = await ref.read(supabaseUserProvider.notifier).signIn(
          email: email,
          password: password,
        );

    if (success && mounted) {
      final user = ref.read(supabaseUserProvider).user;
      if (user != null) {
        // Trigger local vault migration and sync
        await ref.read(syncNotifierProvider.notifier).migrateAndSync(user.id);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as $email. Vault synced.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;

    final success = await ref.read(supabaseUserProvider.notifier).signUp(
          email: email,
          password: password,
        );

    if (success && mounted) {
      final user = ref.read(supabaseUserProvider).user;
      if (user != null) {
        // Trigger local vault migration and sync
        await ref.read(syncNotifierProvider.notifier).migrateAndSync(user.id);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created for $email. Vault connected.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(supabaseUserProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: Color(0xFF10B981),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supabase Cloud Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sign in to sync your encrypted vault across devices',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Sign In'),
                      Tab(text: 'Register'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Error Banner
                if (userState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            userState.errorMessage!,
                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tab Views
                SizedBox(
                  height: 280,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Sign In Form
                      _buildSignInTab(userState.isLoading),
                      // Sign Up Form
                      _buildSignUpTab(userState.isLoading),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab(bool isLoading) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _signInEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF10B981)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _signInPasswordController,
            obscureText: _signInObscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Account password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981)),
              suffixIcon: IconButton(
                icon: Icon(
                  _signInObscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white60,
                ),
                onPressed: () => setState(() => _signInObscurePassword = !_signInObscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: isLoading ? null : _handleSignIn,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign In & Sync Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpTab(bool isLoading) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF10B981)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Email is required';
              if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signUpPasswordController,
            obscureText: _signUpObscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Password (min. 6 characters)',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981)),
              suffixIcon: IconButton(
                icon: Icon(
                  _signUpObscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white60,
                ),
                onPressed: () => setState(() => _signUpObscurePassword = !_signUpObscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signUpConfirmPasswordController,
            obscureText: _signUpObscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_reset_rounded, color: Color(0xFF10B981)),
            ),
            validator: (val) {
              if (val != _signUpPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: isLoading ? null : _handleSignUp,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Account & Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
