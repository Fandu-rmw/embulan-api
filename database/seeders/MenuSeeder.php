<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class MenuSeeder extends Seeder
{
    public function run(): void
{
    \DB::table('menus')->insert([
        [
            'nama_menu' => 'Nasi Goreng Boroq',
            'harga' => 15000,
            'kategori' => 'makanan',
            'is_ready' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ],
        [
            'nama_menu' => 'Es Jeruk Segar',
            'harga' => 5000,
            'kategori' => 'minuman',
            'is_ready' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]
    ]);
}
}
