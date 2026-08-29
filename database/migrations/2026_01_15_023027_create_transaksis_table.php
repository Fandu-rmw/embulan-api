<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
{
    Schema::create('transaksis', function (Blueprint $table) {
        $table->id();
        $table->string('total_bayar');
        $table->string('umkm_name');
        $table->string('store_name');
        $table->string('nomor_meja');
        $table->string('status')->default('pending');
        $table->string('metode_bayar')->default('CASH'); 
        $table->timestamps();
    });
}

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transaksis');
    }
};
