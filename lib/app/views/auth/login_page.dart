// ============================================================
// RNA Guide - Page de Connexion
// Adaptée terrain: login par téléphone ou email
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../routes/app_pages.dart';
import '../../../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _usePhone = true; // défaut: login par téléphone (terrain)

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final identifier = _identifierCtrl.text.trim();
    final success = await AuthController.to.login(
      phone: _usePhone ? identifier : null,
      email: _usePhone ? null : identifier,
      password: _passwordCtrl.text,
    );
    if (success) Get.offAllNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // ── Logo & Titre ──
              Center(
                child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.forest, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text('RNA Guide', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primary, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 4),
                  Text('Régénération Naturelle Assistée',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              const SizedBox(height: 48),

              // ── Formulaire ──
              Form(
                key: _formKey,
                child: Column(children: [
                  // Toggle phone / email
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _usePhone = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(
                              color: _usePhone ? AppTheme.primary : Colors.transparent,
                              width: 2,
                            )),
                          ),
                          child: Text('Téléphone', textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _usePhone ? AppTheme.primary : AppTheme.textSecondary,
                              fontWeight: _usePhone ? FontWeight.w600 : FontWeight.normal,
                            )),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _usePhone = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(
                              color: !_usePhone ? AppTheme.primary : Colors.transparent,
                              width: 2,
                            )),
                          ),
                          child: Text('Email', textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_usePhone ? AppTheme.primary : AppTheme.textSecondary,
                              fontWeight: !_usePhone ? FontWeight.w600 : FontWeight.normal,
                            )),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Identifier field
                  TextFormField(
                    controller: _identifierCtrl,
                    keyboardType: _usePhone ? TextInputType.phone : TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _usePhone ? 'Numéro de téléphone' : 'Adresse email',
                      prefixIcon: Icon(_usePhone ? Icons.phone : Icons.email_outlined),
                      hintText: _usePhone ? '+22670123456' : 'nom@example.com',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Champ requis';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mot de passe requis';
                      if (v.length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Error message
                  Obx(() {
                    final err = AuthController.to.error.value;
                    if (err.isEmpty) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(err, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                      ]),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Submit button
                  Obx(() => ElevatedButton(
                    onPressed: AuthController.to.isLoading.value ? null : _submit,
                    child: AuthController.to.isLoading.value
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Se connecter'),
                  )),
                ]),
              ),

              // ── Offline notice ──
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.offline_bolt, color: AppTheme.info, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Connexion internet requise pour la première connexion. Ensuite, l\'application fonctionne hors ligne.',
                    style: TextStyle(fontSize: 12, color: AppTheme.info),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
