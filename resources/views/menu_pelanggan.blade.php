<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daftar Menu - {{ $store_name }}</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body { 
            background-color: #f4f6f9; 
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
            color: #333;
            line-height: 1.5;
        }
        .navbar-custom {
            background: linear-gradient(135deg, #e67e22, #d35400);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            padding: 15px;
            text-align: center;
        }
        .main-title {
            font-weight: 800;
            color: white;
            letter-spacing: 1px;
            font-size: 1.2rem;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px 12px;
        }
        .sub-title {
            text-align: center;
            color: #666;
            font-size: 0.85rem;
            margin-bottom: 15px;
            padding: 0 10px;
        }
        .divider {
            width: 50px;
            height: 3px;
            background-color: #e67e22;
            margin: 0 auto 20px auto;
            border-radius: 2px;
        }
        
        /* Grid System */
        .menu-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr); 
            gap: 12px;
        }
        
        @media (min-width: 768px) {
            .menu-grid {
                grid-template-columns: repeat(3, 1fr);
            }
        }
        @media (min-width: 992px) {
            .menu-grid {
                grid-template-columns: repeat(4, 1fr);
            }
        }

        /* Desain Kartu Menu */
        .card-menu { 
            background: white;
            border-radius: 14px; 
            box-shadow: 0 4px 10px rgba(0,0,0,0.04); 
            overflow: hidden; 
            display: flex;
            flex-direction: column;
            border: 1px solid #eee;
        }
        
        /* Wadah Gambar */
        .img-container {
            width: 100%;
            height: 140px; 
            overflow: hidden;
            background-color: #f8f9fa;
        }
        .menu-img { 
            height: 100%; 
            width: 100%;
            object-fit: cover; 
        }
        
        /* Perbaikan Detail Spasi Card Body */
        .card-body {
            padding: 12px;
            display: flex;
            flex-direction: column;
            flex-grow: 1;
            gap: 8px;
        }
        .badge-kategori { 
            background-color: #ffeaa7; 
            color: #d35400; 
            font-size: 0.65rem; 
            font-weight: 700;
            border-radius: 6px; 
            padding: 2px 8px; 
            display: inline-block;
            text-transform: uppercase;
            width: fit-content;
        }
        .card-title {
            font-weight: 700;
            color: #2c3e50;
            font-size: 0.95rem;
            margin: 2px 0;
            display: block;
        }
        .price-box {
            padding-top: 6px;
            border-top: 1px solid #f8f9fa;
            margin-top: auto;
        }
        .harga { 
            color: #e67e22; 
            font-weight: 700; 
            font-size: 0.95rem; 
        }
        footer {
            text-align: center;
            padding: 25px 15px;
            margin-top: 40px;
            color: #999;
            font-size: 0.75rem;
            background-color: white;
            border-top: 1px solid #eee;
        }
    </style>
</head>
<body>

    <nav class="navbar-custom">
        <span class="main-title">🍽️ MENU DIGITAL {{ strtoupper($store_name) }}</span>
    </nav>

    <div class="container">
        <p class="sub-title">Silakan scan QR Code di meja untuk melihat daftar makanan & minuman segar kami secara real-time.</p>
        <div class="divider"></div>
        
        <div class="menu-grid">
            @foreach($menus as $item)
            <div class="card-menu">
                
                <div class="img-container">
                    @if($item->foto)
                        <img src="{{ asset('storage/' . $item->foto) }}" class="menu-img" alt="{{ $item->nama_menu }}">
                    @else
                        <div style="display: flex; align-items: center; justify-content: center; height: 100%; color: #999; font-size: 0.8rem; background: #f8f9fa;">
                            Tidak ada foto
                        </div>
                    @endif
                </div>
                
                <div class="card-body">
                    <div>
                        <span class="badge-kategori">{{ $item->kategori }}</span>
                        <h6 class="card-title">{{ $item->nama_menu }}</h6>
                    </div>
                    <div class="price-box">
                        <p class="harga">Rp {{ number_format($item->harga, 0, ',', '.') }}</p>
                    </div>
                </div>

            </div>
            @endforeach
        </div>
    </div>

    <footer>
        &copy; 2026 Kasir {{ $store_name }} &bull; Hak Cipta Dilindungi Aplikasi Skripsi
    </footer>

</body>
</html>