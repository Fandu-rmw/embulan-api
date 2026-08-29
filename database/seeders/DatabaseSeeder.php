<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Menu;

class DatabaseSeeder extends Seeder
{
    public function run()
    {
        $umkms = [
            "UMKM 1 - Snack Boroq", "UMKM 2 - Minuman Anjani", 
            "UMKM 3 - Nasi Tradisional", "UMKM 4 - Gorengan Kolam",
            "UMKM 5 - Mie & Bakso", "UMKM 6 - Kopi Pengurus",
            "UMKM 7 - Aneka Jus", "UMKM 8 - Sate & Bakar",
            "UMKM 9 - Jajanan Pasar", "UMKM 10 - Es Kelapa Muda"
        ];

        foreach ($umkms as $name) {
            Menu::create([
                'nama_menu' => 'Menu Spesial ' . explode(' - ', $name)[1],
                'harga' => 15000,
                'umkm_name' => $name
            ]);
        }
    }
}