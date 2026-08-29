<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'store_name',
        'nama_lapak',   
        'foto_lapak',  
        'qris_image',   
        'status',       
        'role',
        'last_seen_at', 
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Relasi ke Model Menu (Satu Lapak punya Banyak Menu)
     */
    public function menus()
    {
        return $this->hasMany(Menu::class, 'user_id');
    }

    /**
     * Relasi ke Model Transaksi (Satu Lapak punya Banyak Transaksi)
     */
    public function transactions()
    {
        return $this->hasMany(Transaksi::class, 'user_id');
    }
}