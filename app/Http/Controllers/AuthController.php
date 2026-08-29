<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
        ]);

        $namaToko = $request->store_name ?? $request->nama_lapak ?? $request->name;

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'store_name' => $namaToko, // Disimpan ke store_name saja
            'role' => $request->role ?? 'kasir',
            'status' => 'buka',
        ]);

        return response()->json([
            'message' => 'Register success',
            'user' => $user
        ], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'Email atau password salah.'
            ], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        $namaToko = $user->store_name ?? $user->nama_lapak ?? $user->name;

        return response()->json([
            'status' => 'success',
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'store_name' => $namaToko,
                'status' => $user->status ?? 'buka',
            ]
        ], 200);
    }

    /**
     * Mengambil status toko yang sedang login[cite: 10]
     */
    public function getMyStatus(Request $request)
    {
        $user = $request->user('sanctum') ?? auth('sanctum')->user();

        if (!$user && $request->filled('user_id')) {
            $user = User::find($request->user_id);
        }

        if (!$user) {
            $user = User::where('role', 'kasir')->first();
        }

        if ($user) {
            return response()->json([
                'status' => strtolower($user->status ?? 'buka'),
                'toko'   => $user->store_name ?? $user->name,
                'qris_image' => $user->qris_image ?? null,
            ], 200);
        }

        return response()->json(['status' => 'buka'], 200);
    }

    /**
     * Mengubah manual status Buka / Tutup toko via Saklar Kasir[cite: 10]
     */
    public function toggleStatus(Request $request)
    {
        try {
            $user = $request->user('sanctum') ?? auth('sanctum')->user();

            if (!$user && $request->filled('user_id')) {
                $user = User::find($request->user_id);
            }

            if (!$user && $request->filled('store_name')) {
                $user = User::where('store_name', $request->store_name)
                    ->orWhere('name', $request->store_name)
                    ->first();
            }

            if (!$user) {
                $user = User::where('role', 'kasir')->first();
            }

            if (!$user) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Data user toko tidak ditemukan'
                ], 404);
            }

            $newStatus = strtolower($request->input('status', 'buka'));
            $user->status = ($newStatus === 'tutup' || $newStatus === 'closed') ? 'tutup' : 'buka';
            $user->save();

            return response()->json([
                'success' => true,
                'message' => 'Status toko berhasil diperbarui',
                'status'  => $user->status,
                'toko'    => $user->store_name ?? $user->name
            ], 200);
        } catch (\Throwable $e) {
            return response()->json([
                'status' => 'error',
                'message' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Memperbarui foto QRIS toko[cite: 10]
     */
    public function updateQris(Request $request)
    {
        $user = $request->user('sanctum') ?? auth('sanctum')->user();

        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 401);
        }

        if ($request->hasFile('qris_image')) {
            $path = $request->file('qris_image')->store('qris', 'public');
            $user->qris_image = $path;
            $user->save();

            return response()->json([
                'success' => true,
                'message' => 'Foto QRIS berhasil diperbarui',
                'qris_image' => $path
            ], 200);
        }

        return response()->json(['success' => false, 'message' => 'File gambar tidak ditemukan'], 400);
    }

    /**
     * Mengambil daftar seluruh lapak untuk tampilan QR Pelanggan[cite: 10]
     */
    public function indexLapak()
    {
        try {
            $lapak = User::all()->map(function ($item) {
                $namaToko = !empty($item->store_name) ? $item->store_name : (!empty($item->nama_lapak) ? $item->nama_lapak : $item->name);
                $status = strtolower($item->status ?? 'buka');

                return [
                    'id' => $item->id,
                    'name' => $namaToko,
                    'store_name' => $namaToko,
                    'nama_lapak' => $namaToko,
                    'email' => $item->email,
                    'foto_lapak' => $item->foto_lapak ?? null,
                    'qris_image' => $item->qris_image ?? null,
                    'status' => ($status === 'tutup' || $status === 'closed') ? 'tutup' : 'buka',
                    'role' => $item->role ?? 'kasir',
                ];
            });

            return response()->json([
                'status' => 'success',
                'data' => $lapak
            ], 200);
        } catch (\Throwable $e) {
            return response()->json([
                'status' => 'error',
                'message' => $e->getMessage()
            ], 500);
        }
    }
}