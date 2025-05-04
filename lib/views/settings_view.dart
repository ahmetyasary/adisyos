import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  String _selectedLanguage = 'tr';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyNameController.text = prefs.getString('companyName') ?? '';
      _discountController.text = prefs.getString('discountRate') ?? '';
      _selectedLanguage =
          prefs.getString('language') ?? (Get.locale?.languageCode ?? 'tr');
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('companyName', _companyNameController.text);
    await prefs.setString('discountRate', _discountController.text);
    await prefs.setString('language', _selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Şirket Adı', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Şirket adınızı girin',
              ),
            ),
            const SizedBox(height: 24),
            Text('İskonto Oranı (%)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Örn: 10',
              ),
            ),
            const SizedBox(height: 24),
            Text('Dil', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              items: const [
                DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                DropdownMenuItem(value: 'en', child: Text('İngilizce')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  if (value == 'tr') {
                    Get.updateLocale(const Locale('tr', 'TR'));
                  } else {
                    Get.updateLocale(const Locale('en', 'US'));
                  }
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _saveSettings();
                  Get.back();
                },
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
