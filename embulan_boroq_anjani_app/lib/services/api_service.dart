import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // URL Clever Cloud untuk koneksi Flutter Web dan Mobile
  static const String baseUrl = 'https://embulan-api.cleverapps.io/api'; 

  // Header standar untuk komunikasi ke Laravel
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
  };

  // 1. Mengambil Daftar Seluruh Lapak yang Buka
  static Future<List<dynamic>> getDaftarLapak() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lapak'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('data')) {
          return data['data'];
        }
        return [];
      } else {
        throw Exception('Gagal memuat daftar lapak (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. Mengambil Menu Khusus Lapak Tertentu
  static Future<List<dynamic>> getMenuByLapak(int lapakId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lapak/$lapakId/menus'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('data')) {
          return data['data'];
        }
        return [];
      } else {
        throw Exception('Gagal memuat menu lapak (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 3. Mengirim Transaksi Pesanan Pelanggan ke Lapak
  static Future<Map<String, dynamic>> buatPesanan({
    required int lapakId,
    required String nomorMeja,
    required String namaPelanggan,
    required List<Map<String, dynamic>> items,
    String? catatan,
    String metodePembayaran = 'qris',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transaksi/pesan'),
        headers: _headers,
        body: jsonEncode({
          'user_id': lapakId,
          'nomor_meja': nomorMeja,
          'nama_pelanggan': namaPelanggan,
          'metode_pembayaran': metodePembayaran,
          'catatan': catatan ?? '',
          'items': items,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Gagal membuat pesanan (${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }
}