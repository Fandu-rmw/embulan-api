import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:google_sign_in/google_sign_in.dart'; 
import 'register_page.dart'; 
import 'main_navigation.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  final String baseUrl = "https://available-rectified-usual.ngrok-free.dev/api";

  // Inisialisasi Google Sign In
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '179787623484-9tvq4vvc31djkjfbkp07gklmqv0vobpd.apps.googleusercontent.com', 
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _prosesVerifikasiBackend(account);
      }
    });
  }

  Future<void> _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Email dan Password tidak boleh kosong!", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json", 
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        String token = '';
        if (data != null) {
          token = data['access_token'] ?? data['token'] ?? (data['data'] != null ? data['data']['token'] : '') ?? '';
        }

        String storeName = "Embulan Boroq Anjani"; 
        
        try {
          if (data != null) {
            if (data['user'] != null && data['user']['store_name'] != null) {
              storeName = data['user']['store_name'].toString();
            } else if (data['store_name'] != null) {
              storeName = data['store_name'].toString();
            }
          }
        } catch (_) {
          storeName = "Embulan Boroq Anjani";
        }

        if (token.isEmpty) {
          _showSnackBar("Login gagal: Token tidak ditemukan dalam respon server.", Colors.red);
          return;
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('token', token.trim());
        await prefs.setString('storeName', storeName.trim()); 

        if (!mounted) return;

        _showSnackBar("Login Berhasil! Selamat Datang.", Colors.green);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              token: token.trim(),
              name: storeName.trim(), 
            ), 
          ),
        );
      } else {
        _showSnackBar(data['message'] ?? "Email atau Password salah!", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Gagal terhubung ke server Laravel: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FUNGSI MEMPROSES AKUN GOOGLE KE LARAVEL
  Future<void> _prosesVerifikasiBackend(GoogleSignInAccount googleUser) async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final response = await http.post(
        Uri.parse("$baseUrl/google-login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "email": googleUser.email,
          "name": googleUser.displayName ?? '',
          "google_id": googleUser.id,
          "id_token": googleAuth.idToken ?? '',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String token = '';
        if (data != null) {
          token = data['access_token'] ?? data['token'] ?? (data['data'] != null ? data['data']['token'] : '') ?? '';
        }

        String storeName = googleUser.displayName ?? "Toko Batur";

        try {
          if (data != null) {
            if (data['user'] != null && data['user']['store_name'] != null) {
              storeName = data['user']['store_name'].toString();
            } else if (data['store_name'] != null) {
              storeName = data['store_name'].toString();
            }
          }
        } catch (_) {}

        if (token.isEmpty) {
          _showSnackBar("Login Google gagal: Token dari server tidak ditemukan.", Colors.red);
          return;
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('token', token.trim());
        await prefs.setString('storeName', storeName.trim());

        if (!mounted) return;

        _showSnackBar("Login Google Berhasil! Selamat Datang.", Colors.green);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              token: token.trim(),
              name: storeName.trim(),
            ),
          ),
        );
      } else {
        _showSnackBar(data['message'] ?? "Gagal verifikasi Google ke server.", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Gagal login dengan Google: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        _prosesVerifikasiBackend(googleUser);
      }
    } catch (e) {
      _showSnackBar("Gagal login dengan Google: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade800,
              Colors.orange.shade400,
              Colors.white,
            ],
            stops: const [0.0, 0.4, 0.8],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                    ],
                  ),
                  child: Icon(Icons.restaurant_menu, size: 60, color: Colors.orange.shade800),
                ),
                const SizedBox(height: 15),
                const Text(
                  "EMBULAN BOROQ ANJANI",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                ),
                const Text(
                  "Waiter & Management System",
                  style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Login Akun",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : const Text(
                                  "MASUK APLIKASI",
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // PEMBATAS
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text("ATAU", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // TOMBOL GOOGLE
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://api.iconify.design/flat-color-icons:google.svg',
                                height: 22,
                                width: 22,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.g_mobiledata_rounded, size: 30, color: Colors.red),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Masuk dengan Google",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterPage()),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "Belum punya akun? ",
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: "Registrasi di sini",
                                  style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                          ),
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
    );
  }
}