import 'package:flutter/material.dart';
import 'services/api_service.dart';

class MenuLapakPage extends StatefulWidget {
  final int lapakId;
  final String namaLapak;
  final String nomorMeja; // Bisa berisi 'Umum' atau nomor jika ada
  final String? qrisImage;

  const MenuLapakPage({
    Key? key,
    required this.lapakId,
    required this.namaLapak,
    this.nomorMeja = 'Umum',
    this.qrisImage,
  }) : super(key: key);

  @override
  State<MenuLapakPage> createState() => _MenuLapakPageState();
}

class _MenuLapakPageState extends State<MenuLapakPage> {
  late Future<List<dynamic>> _menuFuture;
  final Map<int, int> _keranjang = {};
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedKategori = 'Semua';
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = ApiService.getMenuByLapak(widget.lapakId);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _catatanController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Format angka ke Rupiah (contoh: 10000 -> 10.000)
  String _formatRupiah(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  // Helper untuk membentuk URL Gambar yang valid, menyertakan storage/, dan aman dari spasi
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

    final String base = ApiService.baseUrl.replaceAll('/api', '');
    final String fullUrl = '$base/$cleanPath';

    return Uri.encodeFull(fullUrl);
  }

  int _hitungTotalHarga(List<dynamic> listMenu) {
    int total = 0;
    _keranjang.forEach((menuId, jumlah) {
      final menu = listMenu.firstWhere((m) => m['id'] == menuId, orElse: () => null);
      if (menu != null) {
        final harga = int.tryParse(menu['harga'].toString()) ?? 0;
        total += harga * jumlah;
      }
    });
    return total;
  }

  void _prosesCheckout(List<dynamic> listMenu) async {
    if (_keranjang.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 menu sebelum checkout!')),
      );
      return;
    }

    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan nama Pemesan!')),
      );
      return;
    }

    if (_catatanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi lokasi duduk (misal: Berugaq 2 / Dekat Kolam)!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    List<Map<String, dynamic>> itemsPayload = [];
    _keranjang.forEach((menuId, jumlah) {
      if (jumlah > 0) {
        final menu = listMenu.firstWhere((m) => m['id'] == menuId);
        itemsPayload.add({
          'menu_id': menu['id'],
          'nama_menu': menu['nama_menu'] ?? menu['name'],
          'harga_satuan': int.tryParse(menu['harga'].toString()) ?? 0,
          'jumlah': jumlah,
        });
      }
    });

    try {
      await ApiService.buatPesanan(
        lapakId: widget.lapakId,
        nomorMeja: widget.nomorMeja,
        namaPelanggan: _namaController.text.trim(),
        catatan: _catatanController.text.trim(),
        items: itemsPayload,
      );

      if (!mounted) return;
      final int totalBayar = _hitungTotalHarga(listMenu);

      setState(() {
        _isSubmitting = false;
        _keranjang.clear();
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Pesanan Berhasil! 🎉'),
          content: Text(
            'Pesanan Anda telah diteruskan ke ${widget.namaLapak}.\n\n'
            'Pemesan: ${_namaController.text.trim()}\n'
            'Lokasi/Catatan: ${_catatanController.text.trim()}\n'
            'Total Bayar: Rp ${_formatRupiah(totalBayar)}',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesanan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.namaLapak),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Menu belum tersedia di lapak ini.'));
          }

          final listMenu = snapshot.data!;

          // Logika pemfilteran ketat & presisi untuk memisahkan Makanan dan Minuman
          final filteredList = listMenu.where((menu) {
            final String nama = (menu['nama_menu'] ?? menu['name'] ?? '').toString().toLowerCase();
            final String kategori = (menu['kategori'] ?? '').toString().toLowerCase();
            
            final bool matchesSearch = nama.contains(_searchQuery.toLowerCase());
            
            // Deteksi tegasapakah item merupakan minuman
            final bool isMinuman = kategori.contains('minum') || 
                                   kategori.contains('es') || 
                                   kategori.contains('jus') || 
                                   kategori.contains('teh') || 
                                   kategori.contains('kopi') ||
                                   nama.contains('jus') || 
                                   nama.contains('es ') || 
                                   nama.contains('teh') || 
                                   nama.contains('kopi');

            bool matchesKategori = true;
            if (_selectedKategori == 'Makanan') {
              matchesKategori = !isMinuman;
            } else if (_selectedKategori == 'Minuman') {
              matchesKategori = isMinuman;
            }

            return matchesSearch && matchesKategori;
          }).toList();

          final totalHarga = _hitungTotalHarga(listMenu);

          return Column(
            children: [
              // Form Input Nama & Lokasi
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.teal.shade50,
                child: Column(
                  children: [
                    TextField(
                      controller: _namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pemesan',
                        hintText: 'Masukkan nama Anda',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _catatanController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Lokasi Duduk & Catatan Pesanan',
                        hintText: 'Contoh: Duduk di Berugaq 3 dekat kolam / Bungkus / Pedas sedang',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar & Filter Kategori
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.white,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari menu di ${widget.namaLapak}...',
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(color: Colors.teal.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Semua', 'Makanan', 'Minuman'].map((kategori) {
                          final bool isSelected = _selectedKategori == kategori;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(kategori),
                              selected: isSelected,
                              selectedColor: Colors.teal,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (bool selected) {
                                setState(() {
                                  _selectedKategori = kategori;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // List Menu
              Expanded(
                child: filteredList.isEmpty
                    ? const Center(child: Text('Menu tidak ditemukan.'))
                    : ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final menu = filteredList[index];
                          final menuId = menu['id'];
                          final jumlah = _keranjang[menuId] ?? 0;
                          final harga = int.tryParse(menu['harga'].toString()) ?? 0;
                          final String imageUrl = _getImageUrl(menu['foto']);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        imageUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        headers: const {
                                          'ngrok-skip-browser-warning': 'true',
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.fastfood, color: Colors.teal),
                                          );
                                        },
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.fastfood, color: Colors.teal),
                                    ),
                              title: Text(
                                menu['nama_menu'] ?? menu['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Rp ${_formatRupiah(harga)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (jumlah > 0)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          if (jumlah > 1) {
                                            _keranjang[menuId] = jumlah - 1;
                                          } else {
                                            _keranjang.remove(menuId);
                                          }
                                        });
                                      },
                                    ),
                                  if (jumlah > 0)
                                    Text(
                                      '$jumlah',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: Colors.teal),
                                    onPressed: () {
                                      setState(() {
                                        _keranjang[menuId] = jumlah + 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Bar Total Pembayaran & Checkout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total Pembayaran:'),
                        Text(
                          'Rp ${_formatRupiah(totalHarga)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _prosesCheckout(listMenu),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Pesan Sekarang',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}