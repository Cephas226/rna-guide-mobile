import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../routes/app_pages.dart';
import '../../../core/theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _data = <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person)),
              onChanged: (v) => _data['firstName'] = v,
              validator: (v) => v!.isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person_outline)),
              onChanged: (v) => _data['lastName'] = v,
              validator: (v) => v!.isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone), hintText: '+22670123456'),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _data['phone'] = v),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Région', prefixIcon: Icon(Icons.location_on)),
              onChanged: (v) => _data['region'] = v),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Village', prefixIcon: Icon(Icons.home)),
              onChanged: (v) => _data['village'] = v),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock)),
              obscureText: true,
              onChanged: (v) => _data['password'] = v,
              validator: (v) => v!.length < 8 ? 'Min 8 caractères' : null),
            const SizedBox(height: 24),
            Obx(() => ElevatedButton(
              onPressed: AuthController.to.isLoading.value ? null : () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await AuthController.to.register(_data);
                if (ok) Get.offAllNamed(Routes.home);
              },
              child: AuthController.to.isLoading.value
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Créer mon compte'),
            )),
          ]),
        ),
      ),
    );
  }
}
