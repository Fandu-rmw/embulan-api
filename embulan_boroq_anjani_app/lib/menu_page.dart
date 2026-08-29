import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'history_page.dart';
import 'login_page.dart'; 

class MenuPage extends StatefulWidget {
  final String? storeName; 
  final String token; 
  final String? nomorMeja; // Menerima nomor meja dari Scan QR Code / URL

  const MenuPage({
    super.key, 
    this.storeName, 
    required this.token, 
    this.nomorMeja,
  }); 

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final String baseUrl = "https://embulan-api.cleverapps.io/api";
  final String baseStorageUrl = "https://embulan-api.cleverapps.io/storage/";

  List allMenus = [];
  List filteredMenus = [];
  String selectedCategory = "Semua";
  int totalHarga = 0;
  
  List<String> keranjangMenu = []; 
  
  final TextEditingController _noMejaController = TextEditingController();
  String activeStoreName = "Embulan Boroq Anjani";

  @override
  void initState() {
    super.initState();
    // Otomatis isi controller nomor meja jika ada parameter nomorMeja yang dikirimkan
    if (widget.nomorMeja != null && widget.nomorMeja!.isNotEmpty) {
      _noMejaController.text = widget.nomorMeja!;
    }
    _loadActiveStoreName(); 
  }

  @override
  void dispose() {
    _noMejaController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveStoreName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      activeStoreName = widget.storeName ?? prefs.getString('storeName') ?? "Embulan Boroq Anjani";
    });
    fetchMenus(); 
  }

  String formatRupiah(dynamic harga) {
    if (harga == null) return "0";
    String hargaStr = harga.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return hargaStr.replaceAllMapped(reg, (Match match) => '${match[1]}.');
  }

  // Menarik data menu dari API Laravel berdasarkan nama toko yang aktif
  Future fetchMenus() async {
    try {
      String namaTokoUrl = (activeStoreName.isEmpty || activeStoreName == "Embulan Boroq Anjani")
          ? "Kolam Anjani" 
          : activeStoreName;

      debugPrint("Mengambil data menu untuk toko: '$namaTokoUrl'");

      final response = await http.get(
        Uri.parse("$baseUrl/menus?umkm_name=${Uri.encodeComponent(namaTokoUrl.trim())}"),
        headers: {
          "ngrok-skip-browser-warning": "true",
        },
      );
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          allMenus = data;
          _applyFilter();
        });
        debugPrint("Berhasil memuat ${allMenus.length} item menu.");
      } else {
        debugPrint("Gagal memuat menu, status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetch menus: $e");
    }
  }

  void _applyFilter() {
    if (selectedCategory == "Semua") {
      filteredMenus = allMenus;
    } else {
      filteredMenus = allMenus.where((menu) {
        String kat = (menu['kategori'] ?? menu['category'] ?? 'Makanan').toString().trim();
        return kat.toLowerCase() == selectedCategory.toLowerCase();
      }).toList();
    }
  }

  void filterByCategory(String category) {
    setState(() {
      selectedCategory = category;
      _applyFilter();
    });
  }

  int hitungJumlahItem(String namaMenu) {
    return keranjangMenu.where((item) => item == namaMenu).length;
  }

  Future kirimTransaksi() async {
    if (totalHarga == 0) return;
    
    String nomorMejaSaja = _noMejaController.text.trim().isEmpty 
        ? "Umum" 
        : _noMejaController.text.trim();

    Map<String, int> pengelompokanMenu = {};
    for (var item in keranjangMenu) {
      pengelompokanMenu[item] = (pengelompokanMenu[item] ?? 0) + 1;
    }

    String daftarPesananRingkas = pengelompokanMenu.entries
        .map((e) => "${e.key} (x${e.value})")
        .join(", ");

    String namaTokoAman = (activeStoreName.isEmpty || activeStoreName == "Embulan Boroq Anjani")
        ? "Kolam Anjani" 
        : activeStoreName;

    try {
      debugPrint("Mencoba mengirim transaksi ke: $baseUrl/transaksi");

      final response = await http.post(
        Uri.parse("$baseUrl/transaksi"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "total_bayar": totalHarga,                 
          "umkm_name": daftarPesananRingkas,         
          "store_name": namaTokoAman,                
          "nomor_meja": nomorMejaSaja,               
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          totalHarga = 0;
          keranjangMenu.clear();
          if (widget.nomorMeja == null || widget.nomorMeja!.isEmpty) {
            _noMejaController.clear();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pesanan Berhasil! Data dikirim ke dapur/kasir."), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memproses: ${response.statusCode} - ${response.body}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Koneksi Masih Stuck / Timeout: $e"), backgroundColor: Colors.red),
      );
    }
  }

  String ringkasKeranjang() {
    Map<String, int> jumlahMenu = {};
    for (var item in keranjangMenu) {
      jumlahMenu[item] = (jumlahMenu[item] ?? 0) + 1;
    }
    return jumlahMenu.entries.map((e) => "${e.key} (x${e.value})").join(", ");
  }

  void _showQrisDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        String nomorMejaTampil = _noMejaController.text.trim().isEmpty 
            ? "Umum" 
            : _noMejaController.text.trim();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "MEJA $nomorMejaTampil - PROSES PESANAN", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)
              ),
              const SizedBox(height: 15),
              
              Text(
                "Total: Rp ${formatRupiah(totalHarga)}", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)
              ),
              const SizedBox(height: 5),
              Text(
                "Pesanan: ${ringkasKeranjang()}", 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)
              ),
              
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                icon: const Icon(Icons.soup_kitchen, color: Colors.white, size: 18),
                label: const Text(
                  "KIRIM KE DAPUR (BAYAR NANTI)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  if (_noMejaController.text.trim().isEmpty) {
                    _noMejaController.text = "Umum [BELUM BAYAR]";
                  } else if (!_noMejaController.text.contains("[BELUM BAYAR]")) {
                    _noMejaController.text = "${_noMejaController.text.trim()} [BELUM BAYAR]";
                  }
                  Navigator.pop(context);
                  kirimTransaksi();
                },
              ),
            ],    
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("BATAL", style: TextStyle(color: Colors.red, fontSize: 12))
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
        title: Text(
          activeStoreName, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ), 
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Menu",
            onPressed: () {
              fetchMenus(); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Memperbarui daftar rekap menu..."),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: "Riwayat Transaksi",
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => HistoryPage(token: widget.token)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Keluar Akun",
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Apakah kamu yakin ingin keluar dari aplikasi?"),
                    actions: [
                      TextButton(
                        child: const Text("Batal"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      TextButton(
                        child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.clear();

                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bagian Atas: Pilihan Filter Kategori Horisontal
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: ["Semua", "Makanan", "Minuman"].map((cat) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selectedCategory == cat,
                    onSelected: (_) => filterByCategory(cat),
                  ),
                );
              }).toList(),
            ),
          ),

          // Bagian Tengah: Tampilan Utama Grid Menu
          Expanded(
            child: filteredMenus.isEmpty
                ? const Center(child: Text("Belum ada menu yang tersedia.", style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, 
                      childAspectRatio: 0.63,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8
                    ),
                    itemCount: filteredMenus.length,
                    itemBuilder: (context, index) {
                      var item = filteredMenus[index];
                      String namaMenu = item['nama_menu'] ?? '';
                      String fileFoto = item['foto'] ?? '';
                      
                      String fullImageUrl = fileFoto.startsWith('http')
                          ? fileFoto
                          : "$baseStorageUrl${fileFoto.replaceFirst(RegExp(r'^/'), '')}";

                      int jumlahSekarang = hitungJumlahItem(namaMenu);

                      return Card(
                        elevation: 2,
                        color: Colors.white, 
                        child: Column(
                          children: [
                            Expanded(
                              child: fileFoto.isNotEmpty
                                  ? Image.network(
                                      fullImageUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      headers: const {
                                        "ngrok-skip-browser-warning": "true",
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          width: double.infinity,
                                          child: const Icon(Icons.broken_image, size: 35, color: Colors.grey),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.orange[50],
                                      width: double.infinity,
                                      child: const Icon(Icons.fastfood, size: 40, color: Colors.orange),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              namaMenu,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text("Rp ${formatRupiah(item['harga'])}", style: const TextStyle(fontSize: 12)),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    if (keranjangMenu.contains(namaMenu)) {
                                      setState(() {
                                        int harga = int.parse(item['harga'].toString());
                                        totalHarga -= harga;
                                        keranjangMenu.remove(namaMenu); 
                                      });
                                    }
                                  }, 
                                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 22)
                                ),
                                Text(
                                  "$jumlahSekarang",
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      int harga = int.parse(item['harga'].toString());
                                      totalHarga += harga;
                                      keranjangMenu.add(namaMenu); 
                                    });
                                  }, 
                                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 22)
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bagian Bawah: Informasi Nomor Meja dan Tombol Proses Pesanan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, -2))]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_restaurant, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _noMejaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: "Masukkan Nomor Meja Pelanggan (Contoh: 05)",
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                            border: UnderlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  onPressed: totalHarga > 0 ? _showQrisDialog : null,
                  child: Text(
                    "PROSES PESANAN (Rp ${formatRupiah(totalHarga)})",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}