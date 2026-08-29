<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\TransactionItem;

class Transaksi extends Model
{
    use HasFactory;

    protected $table = 'transaksis';

    protected $fillable = [
        'kode_transaksi',
        'user_id',
        'nomor_meja',
        'nama_pelanggan',
        'total_bayar',
        'metode_pembayaran',
        'status_pembayaran',
        'status_pesanan',
        'catatan',
    ];

    /**
     * Relasi: Transaksi terikat ke Lapak (User) tertentu
     */
    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Relasi: Satu transaksi punya banyak item menu yang dipesan
     */
    public function items()
    {
        return $this->hasMany(TransactionItem::class, 'transaction_id');
    }
}