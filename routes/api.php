<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\MenuController;
use App\Http\Controllers\TransaksiController;
use App\Http\Controllers\ApiController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// ==========================================
// 🔓 ROUTE PUBLIK (PELANGGAN - TANPA LOGIN)
// ==========================================
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/kasir/ping', [AuthController::class, 'ping']);

Route::get('/lapak', [AuthController::class, 'indexLapak']);
Route::get('/lapak/{identifier}/menus', [MenuController::class, 'getByLapak']);
Route::get('/lapak/{identifier}/menu', [MenuController::class, 'getByLapak']);
Route::get('/menus', [MenuController::class, 'index']);

Route::get('/transaksi', [TransaksiController::class, 'index']);
Route::get('/pesanan-masuk', [TransaksiController::class, 'index']);
Route::post('/transaksi', [TransaksiController::class, 'store']);
Route::post('/transaksi/pesan', [TransaksiController::class, 'store']);

Route::get('/transaksi/rekap-mingguan/excel', [TransaksiController::class, 'exportExcel']);
Route::get('/transaksi/rekap-mingguan/pdf', [TransaksiController::class, 'exportPdf']);


// ==========================================
// 🔒 ROUTE TERPROTEKSI (KASIR LAPAK - WAJIB SANCTUM)
// ==========================================
Route::middleware('auth:sanctum')->group(function () {
    
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::get('/lapak/my-status', [AuthController::class, 'getMyStatus']);
    Route::post('/lapak/toggle-status', [AuthController::class, 'toggleStatus']);
    Route::post('/user/status', [AuthController::class, 'toggleStatus']);
    
    // Endpoint baru untuk memperbarui QRIS toko[cite: 8]
    Route::post('/lapak/update-qris', [AuthController::class, 'updateQris']);

    Route::post('/menus', [MenuController::class, 'store']);
    Route::put('/menus/{id}', [MenuController::class, 'update']);
    Route::delete('/menus/{id}', [MenuController::class, 'destroy']);

    Route::put('/transaksi/{id}/update-status', [TransaksiController::class, 'updateStatus']);

    Route::get('/transaksi/rekap-harian', [TransaksiController::class, 'rekapHarian']);
    Route::delete('/transaksi/clear-all', [TransaksiController::class, 'clearAll']);
    Route::delete('/transaksi/clear-toko', [TransaksiController::class, 'clearAll']);

});