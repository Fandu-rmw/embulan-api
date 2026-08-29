import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class HistoryPage extends StatefulWidget {
  final String token;

  const HistoryPage({super.key, required this.token});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final String baseUrl = "https://available-rectified-usual.ngrok-free.dev/api";
  List transaksiList = [];
  bool isLoading = true;
  int totalPendapatan = 0;

  @override
  void initState() {
    super.initState();
    fetchTransaksi();
  }

  String formatRupiah(dynamic harga) {
    if (harga == null) return "0";
    String hargaStr = harga.toString().split('.')[0];
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return hargaStr.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  Future<void> fetchTransaksi() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/transaksi/rekap-harian"),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        dynamic rawData = json.decode(response.body);

        List data = [];
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData['data'] is List) {
          data = rawData['data'];
        }

        int hitungTotal = 0;
        for (var t in data) {
          double? nilaiDouble = double.tryParse(t['total_bayar'].toString());
          if (nilaiDouble != null) {
            hitungTotal += nilaiDouble.toInt();
          }
        }

        setState(() {
          transaksiList = data;
          totalPendapatan = hitungTotal;
          isLoading = false;
        });
      } else {
        debugPrint("Gagal rekap harian, status code: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error ambil data rekap: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> unduhLaporanMingguan(String format) async {
    final String urlUnduh =
        "$baseUrl/transaksi/rekap-mingguan/$format?token=${widget.token}";

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(width: 15),
            Text("Sedang mengunduh file $format..."),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse(urlUnduh),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        final Directory dir = await getApplicationDocumentsDirectory();
        final String ext = format == 'excel' ? 'xlsx' : 'pdf';
        final String filePath =
            "${dir.path}/Rekap_Mingguan_${DateTime.now().millisecondsSinceEpoch}.$ext";

        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil diunduh! Membuka file..."),
            backgroundColor: Colors.green,
          ),
        );

        await OpenFilex.open(filePath);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal unduh file (Status: ${response.statusCode})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Terjadi kesalahan saat mengunduh: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> hapusSemuaTransaksi() async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/transaksi/clear-all"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchTransaksi();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Semua riwayat berhasil dihapus!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error hapus data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rekap Harian",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => isLoading = true);
              fetchTransaksi();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Hapus Semua Riwayat?"),
                  content: const Text(
                    "Tindakan ini akan menghapus seluruh data transaksi di database.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("BATAL"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        hapusSemuaTransaksi();
                      },
                      child: const Text(
                        "HAPUS",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Container Total Pendapatan
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  color: Colors.orange[50],
                  child: Column(
                    children: [
                      const Text(
                        "Total Pendapatan Hari Ini",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Rp ${formatRupiah(totalPendapatan)}",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Unduh Laporan
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.table_view, size: 18),
                          label: const Text(
                            "Unduh Excel",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () => unduhLaporanMingguan('excel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text(
                            "Unduh PDF",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () => unduhLaporanMingguan('pdf'),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(
                  child: transaksiList.isEmpty
                      ? const Center(
                          child: Text("Belum ada transaksi hari ini."),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: transaksiList.length,
                          itemBuilder: (context, index) {
                            var transaksi =
                                transaksiList[transaksiList.length - 1 - index];

                            String namaToko =
                                (transaksi['store_name'] ?? transaksi['umkm_name'] ?? 'Toko').toString();
                            String namaPelanggan =
                                (transaksi['nama_pelanggan'] ?? 'Pelanggan').toString();
                            String waktu = transaksi['created_at'] != null
                                ? transaksi['created_at'].toString().substring(11, 16)
                                : '-';

                            // Parsing aman untuk items
                            List listItems = [];
                            if (transaksi['items'] is List) {
                              listItems = transaksi['items'];
                            } else if (transaksi['items'] is String) {
                              try {
                                listItems = json.decode(transaksi['items']);
                              } catch (_) {}
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 1.5,
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Icon(
                                    Icons.receipt_long,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  namaToko,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Pemesan: $namaPelanggan",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (listItems.isNotEmpty)
                                      ...listItems.map((menuItem) {
                                        String namaMenu = menuItem['nama_menu']?.toString() ?? 'Menu';
                                        String jumlah = menuItem['jumlah']?.toString() ?? '1';
                                        return Text(
                                          "• $namaMenu ($jumlah x)",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                          ),
                                        );
                                      })
                                    else if (transaksi['items'] is String && (transaksi['items'] as String).isNotEmpty)
                                      Text(
                                        "• ${transaksi['items']}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Waktu: $waktu",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  "Rp ${formatRupiah(transaksi['total_bayar'])}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}