import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

// PERBAIKAN: Mengubah nama class State menjadi standar Flutter (_RegisterPageState)
// agar sinkron dengan baris createState() di atas dan menghindari error struktural.
class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

final String baseUrl = "https://embulan-api.cleverapps.io/api";

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Map<String, String> registrationData = {
        "name": _nameController.text.trim(),
        "store_name": _storeNameController.text.trim(),
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      };

      // Di sini URL akan digabungkan menjadi sempurna: http://127.0.0.1:8000/api/register
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json", 
        },
        body: json.encode(registrationData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registrasi Berhasil! Silakan Login."), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context);
      } else {
        final data = json.decode(response.body);
        _showError(data['message'] ?? "Gagal mendaftar (Error ${response.statusCode})");
      }
    } catch (e) {
      _showError("Terjadi kesalahan koneksi: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Colors.orange, Colors.deepOrangeAccent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Icon(Icons.person_add, size: 80, color: Colors.white),
                          const Text(
                            "BUAT AKUN BARU", 
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController, 
                                  decoration: const InputDecoration(labelText: "Nama Lengkap", prefixIcon: Icon(Icons.person), border: OutlineInputBorder()), 
                                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _storeNameController, 
                                  decoration: const InputDecoration(labelText: "Nama Toko", prefixIcon: Icon(Icons.store), border: OutlineInputBorder()), 
                                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _emailController, 
                                  decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email), border: OutlineInputBorder()), 
                                  validator: (v) => v!.contains('@') ? null : 'Email tidak valid'
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: "Password",
                                    prefixIcon: const Icon(Icons.lock),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), 
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword)
                                    ),
                                  ),
                                  validator: (v) => v!.length < 6 ? 'Minimal 6 karakter' : null,
                                ),
                                const SizedBox(height: 25),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900),
                                    onPressed: _isLoading ? null : _register,
                                    child: _isLoading 
                                        ? const CircularProgressIndicator(color: Colors.white) 
                                        : const Text("DAFTAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}