<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\TransactionItem; 

class Menu extends Model
{
    use HasFactory;

    protected $table = 'menus';

    protected $fillable = [
        'user_id',
        'nama_menu',
        'harga',
        'umkm_name',
        'kategori',
        'deskripsi',
        'foto',
        'is_available',
    ];

    /**
     * Relasi: Setiap menu milik satu User (Lapak)
     */
    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Relasi ke detail item transaksi
     */
    public function transactionItems()
    {
        return $this->hasMany(TransactionItem::class, 'menu_id');
    }
}