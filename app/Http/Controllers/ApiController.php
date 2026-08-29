<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Menu;
use App\Models\Transaksi;

class ApiController extends Controller
{
    // 1. Ambil semua menu
    public function getMenus()
    {
        return response()->json(Menu::all());
    }

    // 2. Tambah menu baru
    public function storeMenu(Request $request)
    {
        $menu = Menu::create([
            'nama_menu' => $request->nama_menu,
            'harga' => $request->harga,
            'umkm_name' => $request->umkm_name
        ]);
        return response()->json($menu);
    }

    // 3. Update menu (Logika CRUD)
    public function updateMenu(Request $request, $id)
    {
        $menu = Menu::find($id);
        if ($menu) {
            $menu->update($request->all());
            return response()->json(['message' => 'Berhasil diupdate']);
        }
        return response()->json(['message' => 'Menu tidak ditemukan'], 404);
    }

    // 4. Hapus menu (Logika CRUD)
    public function deleteMenu($id)
    {
        $menu = Menu::find($id);
        if ($menu) {
            $menu->delete();
            return response()->json(['message' => 'Berhasil dihapus']);
        }
        return response()->json(['message' => 'Menu tidak ditemukan'], 404);
    }

    // 5. Simpan transaksi (Pembayaran Satu Pintu)
    public function storeTransaksi(Request $request)
    {
        $tr = Transaksi::create([
            'total_bayar' => $request->total_bayar
        ]);
        return response()->json($tr);
    }

    // 6. Ambil riwayat transaksi
    public function getTransaksi()
    {
        // Mengambil semua data dari tabel transaksis
        $data = \App\Models\Transaksi::all();
        return response()->json($data);
    }
}
