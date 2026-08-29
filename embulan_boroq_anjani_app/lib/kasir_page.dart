import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KasirPage extends StatefulWidget {
  final String token;

  const KasirPage({super.key, required this.token});

  @override
  _KasirPageState createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  List _pesananMasuk = [];
  bool _isLoading = true;
  bool _isTokoBuka = true;
  bool _isUpdatingStatus = false;
  String? _qrisImage; // Variabel untuk menyimpan path/url QRIS toko[cite: 6]
  Timer? _timer;

  final String baseUrl = "https://available-rectified-usual.ngrok-free.dev/api";

  @override
  void initState() {
    super.initState();
    ambilStatusToko();
    ambilPesanan();
    
    // Polling antrean pesanan setiap 5 detik[cite: 6]
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => ambilPesanan(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Helper untuk membentuk URL Gambar QRIS yang valid & aman dari spasi[cite: 6]
  String _getImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    String cleanPath = path.trim();
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return Uri.encodeFull(cleanPath);
    }
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    if (!cleanPath.startsWith('storage/')) {
      cleanPath = 'storage/$cleanPath';
    }
    final String base = baseUrl.replaceAll('/api', '');
    final String fullUrl = '$base/$cleanPath';
    return Uri.encodeFull(fullUrl);
  }

  // Mengambil status toko & QRIS saat pertama kali dibuka[cite: 6]
  Future<void> ambilStatusToko() async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final response = await http.get(
        Uri.parse("$baseUrl/lapak/my-status?t=$timestamp"),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          if (widget.token.isNotEmpty) 'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _isTokoBuka = (data['status'] ?? 'buka').toString().toLowerCase() == 'buka';
            _qrisImage = data['qris_image']; // Menyimpan data gambar QRIS dari backend[cite: 6]
          });
        }
      } else {
        debugPrint("Gagal mengambil status, code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Gagal mengambil status toko: $e");
    }
  }

  // Mengubah status toko saat saklar digeser[cite: 6]
  Future<void> ubahStatusToko(bool statusBuka) async {
    setState(() {
      _isUpdatingStatus = true;
      _isTokoBuka = statusBuka;
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/lapak/toggle-status"),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          if (widget.token.isNotEmpty) 'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'status': statusBuka ? 'buka' : 'tutup',
        }),
      );

      debugPrint("Toggle Response: ${response.statusCode} - ${response.body}");

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                statusBuka ? "Lapak sekarang BUKA!" : "Lapak sekarang TUTUP!",
              ),
              backgroundColor: statusBuka ? Colors.green[700] : Colors.red[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Gagal mengubah status toko: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  String formatRupiah(dynamic harga) {
    if (harga == null) return "0";
    String hargaStr = harga.toString().split('.')[0];
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return hargaStr.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  Future<void> ambilPesanan() async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, String> headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

      if (widget.token.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.token}';
      }

      final response = await http.get(
        Uri.parse("$baseUrl/transaksi?t=$timestamp"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        try {
          final dataAmbil = json.decode(response.body);

          List rawList = [];
          if (dataAmbil is List) {
            rawList = dataAmbil;
          } else if (dataAmbil is Map && dataAmbil['data'] is List) {
            rawList = dataAmbil['data'];
          }

          List filteredList = rawList.where((item) {
            String status = (item['status'] ?? '').toString().toLowerCase();
            return status != 'lunas' && status != 'selesai' && status != 'dibatalkan';
          }).toList();

          setState(() {
            _pesananMasuk = filteredList;
          });
        } catch (jsonErr) {
          debugPrint("Server merespons bukan format JSON: ${response.body}");
        }
      } else {
        debugPrint("Gagal mengambil data kasir: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Gagal mengambil data kasir: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> prosesPembayaran(dynamic id, String metode) async {
    setState(() {
      _pesananMasuk.removeWhere((item) => item['id'] == id);
    });

    try {
      final response = await http.put(
        Uri.parse("$baseUrl/transaksi/$id/update-status"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'status': 'lunas'}),
      );

      if (response.statusCode == 200) {
        ambilPesanan();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pembayaran via $metode Berhasil Dikonfirmasi!"),
            backgroundColor: metode == 'CASH' ? Colors.green[700] : Colors.blue[700],
          ),
        );
      } else {
        ambilPesanan();
      }
    } catch (e) {
      debugPrint("Gagal memproses pembayaran: $e");
      ambilPesanan();
    }
  }

  Future<void> batalkanPesanan(dynamic id, String namaPelanggan) async {
    setState(() {
      _pesananMasuk.removeWhere((item) => item['id'] == id);
    });

    try {
      final response = await http.put(
        Uri.parse("$baseUrl/transaksi/$id/update-status"),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({'status': 'dibatalkan'}),
      );

      if (response.statusCode == 200) {
        ambilPesanan();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pesanan atas nama '$namaPelanggan' telah dibatalkan!"),
            backgroundColor: Colors.red[700],
          ),
        );
      } else {
        ambilPesanan();
      }
    } catch (e) {
      debugPrint("Gagal membatalkan pesanan: $e");
      ambilPesanan();
    }
  }

  void tampilkanDialogBatal(dynamic id, String namaPelanggan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Batalkan Pesanan?"),
          content: Text(
            "Apakah Anda yakin ingin membatalkan pesanan dari '$namaPelanggan'?",
          ),
          actions: [
            TextButton(
              child: const Text("Kembali"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              child: const Text(
                "Ya, Batalkan",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                batalkanPesanan(id, namaPelanggan);
              },
            ),
          ],
        );
      },
    );
  }

  void tampilkanPopupQRIS(
    dynamic id,
    String totalBayar,
    String nomorMeja,
    String namaToko,
  ) {
    final bool hasCustomQris = (_qrisImage != null && _qrisImage!.trim().isNotEmpty);
    final String qrisDisplayUrl = hasCustomQris
        ? _getImageUrl(_qrisImage)
        : "https://quickchart.io/qr?text=${Uri.encodeComponent("PEMBAYARAN TOKO: $namaToko\nMEJA: $nomorMeja\nTOTAL: Rp ${formatRupiah(totalBayar)}")}&size=250&ecLevel=H";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                "SCAN QRIS - $namaToko",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Total Tagihan: Rp ${formatRupiah(totalBayar)}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(
                  qrisDisplayUrl,
                  fit: BoxFit.contain,
                  headers: const {"ngrok-skip-browser-warning": "true"},
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      "Gagal memuat gambar QRIS",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    prosesPembayaran(id, 'QRIS');
                  },
                  child: const Text(
                    "SUDAH SCAN QRIS (LUNAS)",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> resetTransaksiToko() async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/transaksi/clear-all"),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _pesananMasuk.clear();
        });
        ambilPesanan();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Seluruh riwayat transaksi berhasil direset!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal mereset transaksi: $e");
    }
  }

  void tampilkanDialogReset() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Konfirmasi Reset"),
          content: const Text(
            "Apakah Anda yakin ingin mengosongkan seluruh antrean pesanan?",
          ),
          actions: [
            TextButton(
              child: const Text("Batal"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                "Ya, Hapus Semua",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                resetTransaksiToko();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Menu Kasir & Pesanan",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        backgroundColor: Colors.orange[800],
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _isTokoBuka ? Colors.green[800] : Colors.red[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isTokoBuka ? "BUKA" : "TUTUP",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: _isTokoBuka,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.greenAccent[400],
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.red[400],
                    onChanged: _isUpdatingStatus ? null : (val) => ubahStatusToko(val),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: tampilkanDialogReset,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pesananMasuk.isEmpty
              ? const Center(
                  child: Text(
                    "Belum ada pesanan masuk dari pelanggan.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ListView.builder(
                    itemCount: _pesananMasuk.length,
                    itemBuilder: (context, index) {
                      final pesanan = _pesananMasuk[index];

                      String nomorMejaSaja = (pesanan['nomor_meja'] ?? '-')
                          .toString()
                          .replaceAll('[BELUM BAYAR]', '')
                          .trim();

                      String namaToko =
                          pesanan['store_name'] ?? pesanan['umkm_name'] ?? 'Toko';

                      String namaPelanggan =
                          pesanan['nama_pelanggan'] ?? 'Pelanggan';

                      String catatan = pesanan['catatan'] ?? '';

                      List items = pesanan['items'] ?? [];

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.orange[50],
                                child: Icon(
                                  Icons.store,
                                  color: Colors.orange[800],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      namaToko,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Pemesan: $namaPelanggan",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.orange[900],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (catatan.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        "Catatan: $catatan",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    if (items.isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: items.map<Widget>((item) {
                                          String namaMenu =
                                              item['nama_menu'] ?? 'Menu';
                                          int jumlah = item['jumlah'] ?? 1;
                                          return Text(
                                            "• $namaMenu ($jumlah x)",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[800],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Total: Rp ${formatRupiah(pesanan['total_bayar'])}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      minimumSize: const Size(115, 30),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: () =>
                                        prosesPembayaran(pesanan['id'], 'CASH'),
                                    child: const Text(
                                      "Bayar Cash",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      minimumSize: const Size(115, 30),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: () {
                                      tampilkanPopupQRIS(
                                        pesanan['id'],
                                        pesanan['total_bayar'].toString(),
                                        nomorMejaSaja,
                                        namaToko,
                                      );
                                    },
                                    child: const Text(
                                      "Konfirmasi QRIS",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      minimumSize: const Size(115, 30),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: () => tampilkanDialogBatal(
                                      pesanan['id'],
                                      namaPelanggan,
                                    ),
                                    child: const Text(
                                      "Batalkan",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}