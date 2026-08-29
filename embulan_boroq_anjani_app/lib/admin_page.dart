import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

class AdminPage extends StatefulWidget {
  final String token;
  final String name;

  const AdminPage({super.key, required this.token, required this.name});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final String baseUrl = "https://embulan-api.cleverapps.io/api";
  List menus = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token || oldWidget.name != widget.name) {
      fetchData();
    }
  }

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

  String _getCleanUmkmName() {
    String namaUmkm = widget.name.trim();
    if (namaUmkm.isEmpty ||
        namaUmkm.contains('@') ||
        namaUmkm.toLowerCase() == 'admin') {
      return "batur";
    }
    return namaUmkm;
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Konfirmasi Keluar", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Apakah Anda yakin ingin keluar dari akun toko ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(c);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Dialog untuk unggah foto QRIS toko[cite: 9]
  void _showUploadQrisDialog() {
    XFile? pickedQrisFile;
    Uint8List? webQrisBytes;
    File? qrisFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Atur Foto QRIS Toko", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Unggah gambar QRIS resmi toko Anda agar pelanggan dapat membayar dengan mudah.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: isUploading
                    ? null
                    : () async {
                        final XFile? picked = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                        );
                        if (picked != null) {
                          if (kIsWeb) {
                            final bytes = await picked.readAsBytes();
                            setS(() {
                              pickedQrisFile = picked;
                              webQrisBytes = bytes;
                            });
                          } else {
                            setS(() {
                              pickedQrisFile = picked;
                              qrisFile = File(picked.path);
                            });
                          }
                        }
                      },
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: pickedQrisFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.memory(webQrisBytes!, fit: BoxFit.cover)
                              : Image.file(qrisFile!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.qr_code_scanner, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text("Pilih Gambar QRIS", style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(c),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
              onPressed: isUploading || pickedQrisFile == null
                  ? null
                  : () async {
                      setS(() => isUploading = true);
                      try {
                        var request = http.MultipartRequest(
                          'POST',
                          Uri.parse("$baseUrl/lapak/update-qris"),
                        );

                        final String cleanToken = widget.token.trim().replaceAll("Bearer ", "");
                        request.headers['Accept'] = 'application/json';
                        request.headers['Authorization'] = 'Bearer $cleanToken';
                        request.headers['ngrok-skip-browser-warning'] = 'true';

                        if (kIsWeb) {
                          request.files.add(
                            http.MultipartFile.fromBytes(
                              'qris_image',
                              webQrisBytes!,
                              filename: pickedQrisFile!.name,
                            ),
                          );
                        } else {
                          request.files.add(
                            await http.MultipartFile.fromPath('qris_image', qrisFile!.path),
                          );
                        }

                        var streamedResponse = await request.send();
                        var response = await http.Response.fromStream(streamedResponse);

                        if (response.statusCode == 200) {
                          if (!mounted) return;
                          Navigator.pop(c);
                          _showSnackBar("Foto QRIS berhasil diperbarui!", Colors.green);
                        } else {
                          setS(() => isUploading = false);
                          _showSnackBar("Gagal mengunggah QRIS (${response.statusCode})", Colors.red);
                        }
                      } catch (e) {
                        setS(() => isUploading = false);
                        _showSnackBar("Terjadi kesalahan: $e", Colors.red);
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Simpan QRIS", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMasterQrDialog() {
  String masterUrl = "https://embulan-api.cleverapps.io/?meja=01";
  final String qrImageUrl = "https://quickchart.io/qr?text=${Uri.encodeComponent(masterUrl)}&size=300&ecLevel=H";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Master QR Code Kolam", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                qrImageUrl,
                fit: BoxFit.contain,
                headers: const {"ngrok-skip-browser-warning": "true"},
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Cetak QR ini untuk seluruh area kolam. Pelanggan scan QR ini untuk melihat seluruh lapak yang terdaftar.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download, color: Colors.white, size: 18),
            label: const Text(
              "Unduh QR",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (kIsWeb) {
                // Penanganan aman untuk web tanpa import dart:html statis
                _showSnackBar("Silakan klik kanan / tahan gambar QR untuk menyimpan.", Colors.orange);
              } else {
                _showSnackBar("Fitur unduh QR dioptimalkan untuk versi Web.", Colors.orange);
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future fetchData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    String cleanToken = widget.token.trim().replaceAll("Bearer ", "");
    String namaUmkm = _getCleanUmkmName();

    try {
      final res = await http
          .get(
            Uri.parse(
              "$baseUrl/menus?umkm_name=${Uri.encodeComponent(namaUmkm)}",
            ),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $cleanToken",
              "ngrok-skip-browser-warning": "true",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        try {
          final decodedData = json.decode(res.body);
          setState(() {
            menus = decodedData is List
                ? decodedData
                : (decodedData['data'] ?? []);
            isLoading = false;
          });
        } catch (_) {
          setState(() {
            isLoading = false;
          });
          _showSnackBar("Respons server bukan format JSON.", Colors.orange);
        }
      } else if (res.statusCode == 401) {
        setState(() {
          isLoading = false;
        });
        _showSnackBar(
          "Sesi habis (401). Silakan keluar dan Login kembali.",
          Colors.red,
        );
      } else {
        setState(() {
          isLoading = false;
        });
        _showSnackBar("Gagal memuat menu (${res.statusCode}).", Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      _showSnackBar("Gagal mengambil data: Jaringan bermasalah.", Colors.red);
    }
  }

  Future _hapusMenu(dynamic id) async {
    String cleanToken = widget.token.trim().replaceAll("Bearer ", "");
    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/menus/$id"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $cleanToken",
          "ngrok-skip-browser-warning": "true",
        },
      );
      if (res.statusCode == 200) {
        fetchData();
        _showSnackBar("Menu berhasil dihapus", Colors.green);
      } else {
        _showSnackBar("Gagal menghapus menu (${res.statusCode})", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Gagal menghapus menu", Colors.red);
    }
  }

  Future _editMenu(dynamic id, String namaBaru, String hargaBaru) async {
    String cleanToken = widget.token.trim().replaceAll("Bearer ", "");
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/menus/$id"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $cleanToken",
          "ngrok-skip-browser-warning": "true",
        },
        body: json.encode({"nama_menu": namaBaru, "harga": hargaBaru}),
      );

      if (res.statusCode == 200) {
        fetchData();
        _showSnackBar("Menu berhasil diperbarui!", Colors.green);
      } else {
        String errorMsg = "Gagal memperbarui menu";
        try {
          var errorData = json.decode(res.body);
          errorMsg = errorData['message'] ?? errorMsg;
        } catch (_) {}
        _showSnackBar("$errorMsg (${res.statusCode})", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Kesalahan koneksi saat mengedit menu", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEditDialog(Map menu) {
    TextEditingController editNamaCtrl = TextEditingController(
      text: menu['nama_menu']?.toString(),
    );
    TextEditingController editHargaCtrl = TextEditingController(
      text: menu['harga']?.toString(),
    );
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Edit Menu", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editNamaCtrl,
                  decoration: InputDecoration(
                    labelText: "Nama Menu",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.fastfood),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editHargaCtrl,
                  decoration: InputDecoration(
                    labelText: "Harga",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating
                  ? null
                  : () {
                      editNamaCtrl.dispose();
                      editHargaCtrl.dispose();
                      Navigator.pop(c);
                    },
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isUpdating
                  ? null
                  : () async {
                      if (editNamaCtrl.text.trim().isEmpty ||
                          editHargaCtrl.text.trim().isEmpty) {
                        _showSnackBar(
                          "Nama menu dan harga tidak boleh kosong!",
                          Colors.orange,
                        );
                        return;
                      }

                      setS(() => isUpdating = true);

                      await _editMenu(
                        menu['id'],
                        editNamaCtrl.text.trim(),
                        editHargaCtrl.text.trim(),
                      );

                      if (!mounted) return;
                      editNamaCtrl.dispose();
                      editHargaCtrl.dispose();
                      Navigator.pop(c);
                    },
              child: isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Perbarui", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    TextEditingController n = TextEditingController();
    TextEditingController h = TextEditingController();
    XFile? pickedXFile;
    Uint8List? webImageBytes;
    File? imageFile;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Tambah Menu Baru", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  decoration: InputDecoration(
                    labelText: "Nama Menu",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.restaurant),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: h,
                  decoration: InputDecoration(
                    labelText: "Harga (Rp)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.payments),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: isSaving
                      ? null
                      : () async {
                          final XFile? picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 50,
                          );
                          if (picked != null) {
                            if (kIsWeb) {
                              final bytes = await picked.readAsBytes();
                              setS(() {
                                pickedXFile = picked;
                                webImageBytes = bytes;
                              });
                            } else {
                              setS(() {
                                pickedXFile = picked;
                                imageFile = File(picked.path);
                              });
                            }
                          }
                        },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: pickedXFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? Image.memory(webImageBytes!, fit: BoxFit.cover)
                                : Image.file(imageFile!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_rounded, size: 36, color: Colors.grey),
                              SizedBox(height: 8),
                              Text("Unggah Foto Menu", style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () {
                      n.dispose();
                      h.dispose();
                      Navigator.pop(c);
                    },
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (n.text.trim().isEmpty ||
                          h.text.trim().isEmpty ||
                          pickedXFile == null) {
                        _showSnackBar(
                          "Semua data dan foto wajib diisi!",
                          Colors.orange,
                        );
                        return;
                      }

                      setS(() => isSaving = true);

                      try {
                        var request = http.MultipartRequest(
                          'POST',
                          Uri.parse("$baseUrl/menus"),
                        );

                        final String cleanToken = widget.token
                            .trim()
                            .replaceAll("Bearer ", "");
                        String namaUmkm = _getCleanUmkmName();

                        request.headers['Accept'] = 'application/json';
                        request.headers['Authorization'] = 'Bearer $cleanToken';
                        request.headers['ngrok-skip-browser-warning'] = 'true';

                        request.fields['nama_menu'] = n.text.trim();
                        request.fields['harga'] = h.text.trim();
                        request.fields['umkm_name'] = namaUmkm;
                        request.fields['kategori'] = "Makanan";

                        if (kIsWeb) {
                          request.files.add(
                            http.MultipartFile.fromBytes(
                              'foto',
                              webImageBytes!,
                              filename: pickedXFile!.name,
                            ),
                          );
                        } else {
                          request.files.add(
                            await http.MultipartFile.fromPath(
                              'foto',
                              imageFile!.path,
                            ),
                          );
                        }

                        var streamedResponse = await request.send().timeout(
                          const Duration(seconds: 15),
                        );
                        var response = await http.Response.fromStream(
                          streamedResponse,
                        );

                        if (response.statusCode == 201 ||
                            response.statusCode == 200) {
                          if (!mounted) return;
                          n.dispose();
                          h.dispose();
                          Navigator.pop(c);
                          _showSnackBar(
                            "Menu berhasil disimpan!",
                            Colors.green,
                          );
                          fetchData();
                        } else {
                          setS(() => isSaving = false);
                          String msg = "Terjadi kesalahan server";
                          try {
                            var errorData = json.decode(response.body);
                            msg = errorData['message'] ?? msg;
                          } catch (_) {}
                          _showSnackBar(
                            "Gagal Server (${response.statusCode}): $msg",
                            Colors.red,
                          );
                        }
                      } catch (e) {
                        setS(() => isSaving = false);
                        _showSnackBar("Koneksi Kesalahan: $e", Colors.red);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Simpan", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 72,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Menu',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Daftar menu makanan & minuman Anda masih kosong.\nMulai tambahkan menu baru agar pelanggan dapat memesan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Tambah Menu Pertama',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Admin Kelola Menu",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.black87),
            onPressed: _showUploadQrisDialog,
            tooltip: 'Atur Foto QRIS Toko',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.black87),
            onPressed: _showMasterQrDialog,
            tooltip: 'Lihat Master QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: fetchData,
            tooltip: 'Muat Ulang Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: _handleLogout,
            tooltip: 'Keluar Akun',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : menus.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: menus.length,
                  itemBuilder: (context, i) {
                    final menu = menus[i] is Map ? menus[i] : {};

                    final String namaMenu = menu['nama_menu']?.toString() ?? '-';
                    final String hargaMenu = menu['harga']?.toString() ?? '0';
                    final String fotoMenu = menu['foto']?.toString() ?? '';
                    final String imageUrl = _getImageUrl(fotoMenu);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        headers: const {
                                          "ngrok-skip-browser-warning": "true",
                                        },
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.fastfood,
                                              color: Colors.grey,
                                              size: 30,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.fastfood,
                                      color: Colors.grey,
                                      size: 30,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    namaMenu,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Rp $hargaMenu",
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () {
                                if (menu['id'] != null) {
                                  _showEditDialog(menu);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                if (menu['id'] != null) {
                                  _showHapusConfirmation(menu['id']);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showHapusConfirmation(dynamic id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Menu", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Apakah Anda yakin ingin menghapus menu ini? Action ini tidak bisa dibatalkan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(c);
              _hapusMenu(id);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}