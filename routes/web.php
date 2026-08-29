<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\MenuController; 

// UPDATE: Sekarang ditambahkan /{store_name} agar link website pelanggan otomatis dinamis mengikuti nama tokonya
Route::get('/menu/{store_name}', [MenuController::class, 'menuPelanggan']);

// Halaman dashboard kasir untuk memantau semua pesanan masuk
Route::get('/kasir-dashboard', [MenuController::class, 'dashboardKasir']);

// Arahkan root URL (/) ke index.html milik Flutter Web di folder public
Route::get('/', function () {
    $path = public_path('index.html');
    if (file_exists($path)) {
        return response()->file($path);
    }
    return response('File index.html Flutter belum ada di folder public Laravel.', 404);
});