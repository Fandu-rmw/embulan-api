<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TransactionItem extends Model
{
    use HasFactory;

    protected $table = 'transaction_items';

    protected $fillable = [
        'transaction_id',
        'menu_id',
        'nama_menu',
        'harga_satuan',
        'jumlah',
        'subtotal',
    ];

    /**
     * Relasi balik ke Transaksi
     */
    public function transaction()
    {
        return $this->belongsTo(Transaksi::class, 'transaction_id');
    }

    /**
     * Relasi ke Menu
     */
    public function menu()
    {
        return $this->belongsTo(Menu::class, 'menu_id');
    }
}