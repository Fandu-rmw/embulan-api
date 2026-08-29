<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth; 
use Illuminate\Support\Facades\Validator;

class MenuController extends Controller
{
    // Mengambil data menu SPESIFIK milik toko yang meminta
    public function index(Request $request)
    {
        $namaToko = $request->query('umkm_name');
        $userId = Auth::id() ?? auth('sanctum')->id() ?? $request->query('user_id');

        $query = DB::table('menus');

        if ($namaToko) {
            $query->where('umkm_name', trim($namaToko));
        } elseif ($userId) {
            $user = DB::table('users')->where('id', $userId)->first();
            if ($user) {
                $storeName = $user->store_name ?? $user->name;
                $query->where('umkm_name', trim($storeName));
            }
        }

        $menus = $query->latest()->get();

        // Transform URL foto agar selalu Full HTTPS
        $menus->transform(function ($item) {
            if (!empty($item->foto)) {
                if (!str_starts_with($item->foto, 'http')) {
                    $item->foto = asset('storage/' . ltrim($item->foto, '/'));
                }
            }
            return $item;
        });

        return response()->json($menus, 200);
    }

    // Mengambil menu berdasarkan nama lapak (store_name / umkm_name)
    public function getByLapak($identifier)
    {
        try {
            $decoded = urldecode(trim($identifier));
            $query = DB::table('menus');

            if (is_numeric($decoded)) {
                $user = DB::table('users')->where('id', $decoded)->first();
                if ($user) {
                    $namaToko = $user->store_name ?? $user->name;
                    $query->where('umkm_name', trim($namaToko));
                } else {
                    return response()->json([], 200);
                }
            } else {
                $query->where('umkm_name', trim($decoded));
            }

            $menus = $query->latest()->get();

            // Ubah field foto menjadi Full URL HTTPS
            $menus->transform(function ($item) {
                if (!empty($item->foto)) {
                    if (!str_starts_with($item->foto, 'http')) {
                        $item->foto = asset('storage/' . ltrim($item->foto, '/'));
                    }
                }
                return $item;
            });

            return response()->json($menus, 200);

        } catch (\Exception $e) {
            return response()->json([], 200);
        }
    }

    // Menyimpan menu baru dinamis sesuai toko yang membuat beserta kategori otomatis
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'nama_menu' => 'required',
            'harga'     => 'required',
            'foto'      => 'required|image|max:10000', // Set ke 10MB
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal Validasi Input',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized: Token tidak valid atau kosong'], 401);
        }

        try {
            if ($request->hasFile('foto')) {
                $file = $request->file('foto');
                $fileName = time() . '_' . str_replace(' ', '_', $file->getClientOriginalName());
                $filePath = $file->storeAs('menus', $fileName, 'public');

                // Ambil nama toko dari profil user atau request
                $namaToko = $request->umkm_name ?? $user->store_name ?? $user->name;
                if (empty($namaToko)) {
                    $namaToko = "Embulan Boroq Anjani";
                }

                // Otomatisasi kategori berdasarkan nama menu
                $namaMenuLower = strtolower($request->nama_menu);
                $kategoriOtomatis = 'Makanan';

                $keywordMinuman = [
                    'es', 'jus', 'juice', 'teh', 'tea', 'kopi', 'coffee', 
                    'jeruk', 'boba', 'susu', 'milk', 'water', 'aqua', 'ice',
                    'lemon', 'soda', 'cendol', 'dawet', 'fanta', 'coca', 'sprite'
                ];

                foreach ($keywordMinuman as $keyword) {
                    if (str_contains($namaMenuLower, $keyword)) {
                        $kategoriOtomatis = 'Minuman';
                        break;
                    }
                }

                $kategoriFinal = $request->kategori ?? $kategoriOtomatis;

                DB::table('menus')->insert([
                    'nama_menu'  => $request->nama_menu,
                    'harga'      => $request->harga,
                    'umkm_name'  => trim($namaToko), 
                    'kategori'   => $kategoriFinal,
                    'foto'       => $filePath,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);

                return response()->json(['success' => true, 'message' => 'Success'], 201);
            }

            return response()->json(['message' => 'No file uploaded'], 400);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Error Database: ' . $e->getMessage()
            ], 500);
        }
    }

    // Mengubah data nama menu dan harga
    public function update(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'nama_menu' => 'required',
            'harga'     => 'required|numeric',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal Validasi Input',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $menu = DB::table('menus')->where('id', $id)->first();

            if (!$menu) {
                return response()->json(['success' => false, 'message' => 'Menu tidak ditemukan'], 404);
            }

            $namaMenuLower = strtolower($request->nama_menu);
            $kategoriFinal = 'Makanan'; 

            $keywordMinuman = [
                'es', 'jus', 'juice', 'teh', 'tea', 'kopi', 'coffee', 
                'jeruk', 'boba', 'susu', 'milk', 'water', 'aqua', 'ice',
                'lemon', 'soda', 'cendol', 'dawet', 'fanta', 'coca', 'sprite'
            ];

            foreach ($keywordMinuman as $keyword) {
                if (str_contains($namaMenuLower, $keyword)) {
                    $kategoriFinal = 'Minuman';
                    break;
                }
            }

            DB::table('menus')
                ->where('id', $id)
                ->update([
                    'nama_menu'  => $request->nama_menu,
                    'harga'      => $request->harga,
                    'kategori'   => $kategoriFinal,
                    'updated_at' => now(),
                ]);

            return response()->json(['success' => true, 'message' => 'Menu berhasil diperbarui'], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Error Database: ' . $e->getMessage()
            ], 500);
        }
    }

    // Menghapus menu berdasarkan ID 
    public function destroy($id)
    {
        DB::table('menus')->where('id', $id)->delete();
        return response()->json(['message' => 'Success']);
    }
    
    // Menampilkan menu pelanggan dinamis berdasarkan nama toko di URL web
    public function menuPelanggan($store_name)
    {
        $menus = DB::table('menus')
            ->where('umkm_name', trim($store_name))
            ->latest()
            ->get(); 
        
        return view('menu_pelanggan', compact('menus', 'store_name'));
    }

    // Menampilkan dashboard kasir
    public function dashboardKasir()
    {
        $transaksis = DB::table('transaksis')
            ->orderBy('created_at', 'desc')
            ->get();
        
        return view('kasir_dashboard', compact('transaksis'));
    }
}