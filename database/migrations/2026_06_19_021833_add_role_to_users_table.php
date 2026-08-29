<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        // Menambahkan kolom role setelah password dan memberi nilai default 'kasir'
        $table->string('role', 50)->default('kasir')->after('password');
    });
}

public function down(): void
{
    Schema::table('users', function (Blueprint $table) {
        // Menghapus kolom jika migration di-rollback
        $table->dropColumn('role');
    });
}
};
