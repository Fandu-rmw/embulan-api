import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'menu_lapak_page.dart';

class LapakListPage extends StatefulWidget {
  final String? nomorMeja;

  const LapakListPage({Key? key, this.nomorMeja}) : super(key: key);

  @override
  State<LapakListPage> createState() => _LapakListPageState();
}

class _LapakListPageState extends State<LapakListPage> {
  List<dynamic> _daftarLapak = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _ambilDataLapakAwal();

    // Auto-refresh daftar lapak setiap 3 detik secara background agar status Buka/Tutup sinkron
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _ambilDataLapakBackground();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _ambilDataLapakAwal() async {
    try {
      final data = await ApiService.getDaftarLapak();
      if (mounted) {
        setState(() {
          _daftarLapak = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _ambilDataLapakBackground() async {
    try {
      final data = await ApiService.getDaftarLapak();
      if (mounted) {
        setState(() {
          _daftarLapak = data;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("Gagal update status lapak di background: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Pilih Lapak',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Gagal memuat data pedagang.\n$_errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : _daftarLapak.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada lapak/pedagang yang terdaftar.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _daftarLapak.length,
                      itemBuilder: (context, index) {
                        final lapak = _daftarLapak[index];
                        final String namaLapak = lapak['store_name'] ??
                            lapak['nama_lapak'] ??
                            lapak['name'] ??
                            'Lapak UMKM';
                        final String? fotoLapak = lapak['foto_lapak'];

                        final String rawStatus =
                            (lapak['status'] ?? 'buka').toString().toLowerCase();
                        final bool isBuka =
                            rawStatus == 'buka' || rawStatus == 'open';
                        final String statusText = isBuka ? 'BUKA' : 'TUTUP';

                        return Card(
                          elevation: isBuka ? 3 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            // Logika absolut: jika TUTUP hanya tampilkan SnackBar tanpa ada rute navigasi
                            onTap: isBuka
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MenuLapakPage(
                                          lapakId: lapak['id'],
                                          namaLapak: namaLapak,
                                          nomorMeja: widget.nomorMeja ?? '-',
                                          qrisImage: lapak['qris_image'],
                                        ),
                                      ),
                                    );
                                  }
                                : () {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Maaf, $namaLapak sedang TUTUP.'),
                                        backgroundColor: Colors.red[700],
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                            child: Opacity(
                              opacity: isBuka ? 1.0 : 0.65,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: fotoLapak != null &&
                                            fotoLapak.isNotEmpty
                                        ? Image.network(
                                            fotoLapak.startsWith('http')
                                                ? fotoLapak
                                                : "${ApiService.baseUrl.replaceAll('/api', '')}/storage/$fotoLapak",
                                            headers: const {
                                              'ngrok-skip-browser-warning':
                                                  'true',
                                            },
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                _buildDefaultImage(),
                                          )
                                        : _buildDefaultImage(),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          namaLapak,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isBuka
                                                ? Colors.black87
                                                : Colors.grey[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isBuka
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                color: isBuka
                                                    ? Colors.green[800]
                                                    : Colors.red[800],
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.teal[50],
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 55,
          color: Colors.teal[600],
        ),
      ),
    );
  }
}