import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'login_page.dart'; 
import 'main_navigation.dart'; 
import 'lapak_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cek Parameter URL (Untuk Pelanggan yang Scan QR Meja di Web)
  final uri = Uri.base;
  final nomorMejaFromUrl = uri.queryParameters['meja'];

  // 2. Ambil data login yang tersimpan di memori lokal HP/Laptop
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String token = prefs.getString('token') ?? '';
  String storeName = prefs.getString('storeName') ?? 'Embulan Boroq Anjani';

  runApp(BoroqAnjaniApp(
    isLoggedIn: isLoggedIn,
    token: token,
    storeName: storeName,
    nomorMejaFromUrl: nomorMejaFromUrl,
  ));
}

class BoroqAnjaniApp extends StatelessWidget {
  final bool isLoggedIn;
  final String token;
  final String storeName; 
  final String? nomorMejaFromUrl;

  const BoroqAnjaniApp({
    super.key, 
    required this.isLoggedIn, 
    required this.token, 
    required this.storeName, 
    this.nomorMejaFromUrl,
  });

  Widget _getHomeWidget() {
    // A. JIKA diakses via URL dengan parameter meja (Pelanggan Mandiri)
    if (nomorMejaFromUrl != null && nomorMejaFromUrl!.isNotEmpty) {
      return LapakListPage(nomorMeja: nomorMejaFromUrl!);
    }

    // B. JIKA sudah login (Kasir/Admin/Pemilik Lapak)
    if (isLoggedIn) {
      return MainNavigation(token: token, name: storeName);
    }

    // C. JIKA belum login dan buka biasa tanpa URL meja
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Embulan Boroq Anjani',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: false,
      ),
      home: _getHomeWidget(),
    );
  }
} 