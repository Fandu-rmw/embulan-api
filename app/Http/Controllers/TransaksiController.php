<?php

namespace App\Http\Controllers;

use App\Models\Transaksi;
use App\Models\TransactionItem;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;

class TransaksiController extends Controller
{
    /**
     * Mengambil daftar pesanan PENDING khusus untuk akun yang login
     */
    public function index(Request $request)
    {
        try {
            $userId = Auth::id() ?? auth('sanctum')->id() ?? $request->user_id;

            $query = Transaksi::with(['items', 'user'])
                ->where(function ($q) {
                    $q->where('status_pembayaran', 'pending')
                      ->orWhere('status', 'pending');
                });

            if ($userId) {
                $query->where('user_id', $userId);
            }

            $transaksi = $query->orderBy('created_at', 'desc')->get();

            $formattedData = $transaksi->map(function ($item) {
                return [
                    'id' => $item->id,
                    'kode_transaksi' => $item->kode_transaksi,
                    'nomor_meja' => $item->nomor_meja,
                    'nama_pelanggan' => $item->nama_pelanggan ?? 'Pelanggan',
                    'catatan' => $item->catatan,
                    'store_name' => optional($item->user)->name ?? optional($item->user)->store_name ?? 'Toko',
                    'umkm_name' => optional($item->user)->name ?? 'Toko',
                    'total_bayar' => $item->total_bayar,
                    'status' => $item->status_pembayaran ?? $item->status ?? 'pending',
                    'status_pembayaran' => $item->status_pembayaran ?? $item->status ?? 'pending',
                    'metode_pembayaran' => $item->metode_pembayaran,
                    'created_at' => $item->created_at,
                    'items' => $item->items,
                ];
            });

            return response()->json($formattedData, 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal mengambil data pesanan: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Pelanggan membuat pesanan baru
     */
    public function store(Request $request)
    {
        $request->validate([
            'user_id' => 'required|exists:users,id',
            'nomor_meja' => 'required|string',
            'items' => 'required|array|min:1',
            'items.*.menu_id' => 'required|exists:menus,id',
            'items.*.nama_menu' => 'required|string',
            'items.*.harga_satuan' => 'required|numeric',
            'items.*.jumlah' => 'required|integer|min:1',
            'metode_pembayaran' => 'nullable|string',
            'catatan' => 'nullable|string',
        ]);

        DB::beginTransaction();
        try {
            $totalBayar = 0;
            foreach ($request->items as $item) {
                $totalBayar += ($item['harga_satuan'] * $item['jumlah']);
            }

            $transaksi = Transaksi::create([
                'kode_transaksi' => 'TRX-' . strtoupper(Str::random(8)),
                'user_id' => $request->user_id,
                'nomor_meja' => $request->nomor_meja,
                'nama_pelanggan' => $request->nama_pelanggan ?? 'Pelanggan',
                'total_bayar' => $totalBayar,
                'metode_pembayaran' => $request->metode_pembayaran ?? 'qris',
                'status' => 'pending',
                'status_pembayaran' => 'pending',
                'status_pesanan' => 'menunggu_konfirmasi',
                'catatan' => $request->catatan,
            ]);

            foreach ($request->items as $item) {
                TransactionItem::create([
                    'transaction_id' => $transaksi->id,
                    'menu_id' => $item['menu_id'],
                    'nama_menu' => $item['nama_menu'],
                    'harga_satuan' => $item['harga_satuan'],
                    'jumlah' => $item['jumlah'],
                    'subtotal' => $item['harga_satuan'] * $item['jumlah'],
                ]);
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Pesanan berhasil dibuat',
                'data' => $transaksi->load('items')
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal membuat pesanan: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Memperbarui status transaksi menjadi lunas
     */
    public function updateStatus(Request $request, $id)
    {
        try {
            $transaksi = Transaksi::find($id);

            if (!$transaksi) {
                return response()->json([
                    'success' => false,
                    'message' => 'Transaksi tidak ditemukan'
                ], 404);
            }

            $status = $request->input('status', 'lunas');

            $updateData = [
                'status_pembayaran' => $status,
                'status_pesanan' => 'selesai',
            ];

            if (Schema::hasColumn('transaksis', 'status')) {
                $updateData['status'] = $status;
            }

            $transaksi->update($updateData);

            return response()->json([
                'success' => true,
                'message' => 'Status transaksi berhasil diperbarui',
                'data' => $transaksi
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal memperbarui status: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Kasir Lapak melihat rekap transaksi yang SUDAH LUNAS milik akunnya sendiri
     */
    public function rekapHarian(Request $request)
    {
        try {
            $userId = Auth::id() ?? auth('sanctum')->id() ?? $request->user_id;

            $query = Transaksi::with(['items', 'user'])
                ->where(function ($q) {
                    $q->where('status_pembayaran', 'lunas')
                      ->orWhere('status', 'lunas');
                });

            if ($userId) {
                $query->where('user_id', $userId);
            }

            $transaksi = $query->orderBy('created_at', 'desc')->get();

            $formattedData = $transaksi->map(function ($item) {
                return [
                    'id' => $item->id,
                    'kode_transaksi' => $item->kode_transaksi,
                    'nomor_meja' => $item->nomor_meja,
                    'nama_pelanggan' => $item->nama_pelanggan ?? 'Pelanggan',
                    'catatan' => $item->catatan,
                    'store_name' => optional($item->user)->name ?? optional($item->user)->store_name ?? 'Toko',
                    'umkm_name' => optional($item->user)->name ?? 'Toko',
                    'total_bayar' => $item->total_bayar,
                    'status' => 'lunas',
                    'status_pembayaran' => 'lunas',
                    'metode_pembayaran' => $item->metode_pembayaran,
                    'created_at' => $item->created_at,
                    'items' => $item->items,
                ];
            });

            return response()->json($formattedData, 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Error: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Hapus riwayat transaksi khusus akun yang sedang login
     */
    public function clearAll(Request $request)
    {
        try {
            $userId = Auth::id() ?? auth('sanctum')->id() ?? $request->user_id;

            $query = Transaksi::query();
            if ($userId) {
                $query->where('user_id', $userId);
            }

            $query->delete();

            return response()->json([
                'success' => true,
                'message' => 'Seluruh riwayat transaksi toko Anda berhasil dihapus'
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal menghapus riwayat: ' . $e->getMessage()
            ], 500);
        }
    }
}