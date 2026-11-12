# MyDevEnv-mac - Portable macOS Web Dev Stack

Varian macOS dari [mydevenv-win](https://github.com/mbagusrd/mydevenv-win): stack development lokal portabel tanpa Docker. Menyediakan Nginx, multi-versi PHP (5.6, 7.4, 8.2, 8.3, 8.4), MariaDB, dan Composer dengan struktur & port yang sama dengan varian Windows.

---

## Fitur Utama

- **Struktur & port identik dengan varian Windows**: routing Nginx, pemetaan FastCGI, dan layout folder sama persis.
- **Multi-PHP FastCGI (php-fpm)**:
  - PHP 5.6 pada FastCGI port `9056` (web `8056`)
  - PHP 7.4 pada FastCGI port `9074` (web `8074`)
  - PHP 8.2 pada FastCGI port `9082` (web `8082`)
  - PHP 8.3 pada FastCGI port `9083` (web `8083`)
  - PHP 8.4 pada FastCGI port `9084` (web `8084`)
- **Dynamic Default PHP**: versi default pada port `8080` dapat diubah on-the-fly (`switch-php.sh`).
- **Nginx Web Server**: routing Laravel (`/app/public/`) dan CodeIgniter/legacy (`index.php/path`).
- **MariaDB**: data database tersimpan lokal di `bin/mariadb/data` (mudah dibackup/dipindah).
- **Composer CLI Ready**: wrapper `bin/composer`.
- **Data dir portabel**: MariaDB dijalankan dengan `--datadir` lokal project, bukan `brew services`.

---

## Perbedaan dari Varian Windows

| Aspek | Windows (`mydevenv-win`) | macOS (`mydevenv-mac`) |
|---|---|---|
| Sumber binary | ZIP portabel (windows.php.net, archive.mariadb.org) | Homebrew (tap `shivammathur/php` + `nginx` + `mariadb`) |
| Eksekusi PHP | `php-cgi.exe` per versi | `php-fpm` per versi (php-cgi tidak ada lagi sejak PHP 8) |
| Port web default | 80 | **8080** (port < 1024 butuh sudo/root di macOS) |
| Port MariaDB | 3306 | 3306 default, dikonfigurasi via `MARIADB_PORT` (di Mac ini `3307` karena sudah ada MySQL bawaan) |
| Installer | `install.bat` + `setup.ps1` | `install.sh` |
| Start/Stop | `start.bat` / `stop.bat` | `./start.sh` / `./stop.sh` |
| Portabilitas | Bisa dipindah ke drive lain | Runtime via Homebrew; yang portabel adalah konfigurasi & data (`conf/`, `bin/mariadb/data`) |

> Catatan: macOS tidak menyediakan binary PHP portabel seperti Windows, jadi runtime diambil dari Homebrew. Folder project (config, data MariaDB, www) tetap bisa dibackup/dipindah.

---

## Persyaratan Sistem

- macOS (Apple Silicon atau Intel)
- [Homebrew](https://brew.sh) terpasang
- Koneksi internet (saat instalasi pertama)

---

## Instalasi

```bash
cd ~/Documents/dev/mydevenv-mac
./install.sh
```

Installer akan: tap `shivammathur/php`, menginstal PHP 5.6/7.4/8.2/8.3/8.4, Nginx, MariaDB, Composer, menginisialisasi database di `bin/mariadb/data`, dan menulis semua konfigurasi ke `conf/`.

Password root MariaDB dibaca dari `.env` (`MARIADB_ROOT_PASSWORD`, default `root`) — set dulu sebelum menjalankan `install.sh` jika ingin berbeda.

---

## Penggunaan

### 1. Menjalankan service
```bash
./start.sh
```
Semua service (MariaDB, 5 PHP-FPM, Nginx) berjalan di background (nohup), log di `logs/`.

URL:
- **Default PHP (Port 8080)**: `http://localhost:8080/`
- **PHP 5.6**: `http://localhost:8056/`
- **PHP 7.4**: `http://localhost:8074/`
- **PHP 8.2**: `http://localhost:8082/`
- **PHP 8.3**: `http://localhost:8083/`
- **PHP 8.4**: `http://localhost:8084/`
- **MariaDB**: `127.0.0.1:3307` atau socket `bin/mariadb/mysqld.sock` (user `root`; port bisa diubah lewat `MARIADB_PORT` di `.env` — default `3306`, diubah ke `3307` karena Mac ini sudah menjalankan MySQL sendiri di `3306`)

### 2. Menghentikan service
```bash
./stop.sh
```

### 3. Status service
```bash
./status.sh
```

### 4. Mengganti versi PHP default (Port 8080)
```bash
./switch-php.sh   # lalu pilih 1-5
```

### 5. Mengubah document root
Edit `.env`:
```env
# Relatif terhadap root project
NGINX_WEB_ROOT=./www

# Mengarah ke public project Laravel
NGINX_WEB_ROOT=./www/my-laravel-project/public

# Path absolut
NGINX_WEB_ROOT=/Users/bagus/Projects/my-app/public
```
Lalu jalankan ulang `./start.sh` (atau reload nginx).

---

## CLI

Wrapper di `bin/` (tambahkan `bin/` ke PATH atau pakai `./cmd.sh`):

| Perintah | Deskripsi |
|---|---|
| `./cmd.sh` | Shell interaktif dengan PATH & alias aktif |
| `bin/php -v` | PHP versi default (sesuai `.env`) |
| `bin/php56 -v` | PHP 5.6 spesifik |
| `bin/php74 -v` | PHP 7.4 spesifik |
| `bin/php82 -v` | PHP 8.2 spesifik |
| `bin/php83 -v` | PHP 8.3 spesifik |
| `bin/php84 -v` | PHP 8.4 spesifik |
| `bin/composer <cmd>` | Composer dengan PHP default |
| `bin/mysql` | MariaDB client (socket lokal) |

---

## Struktur Direktori

```text
mydevenv-mac/
├── archives/            # (opsional) cache download
├── bin/
│   ├── mariadb/         # Data database MariaDB (datadir lokal)
│   ├── composer.phar    # Binary Composer
│   ├── php              # Wrapper PHP default
│   ├── php56..php84     # Wrapper PHP per versi
│   ├── composer         # Wrapper Composer CLI
│   └── mysql            # Wrapper MariaDB client
├── conf/
│   ├── nginx/           # nginx.conf, webroot.conf, default_php.conf
│   └── php-fpm/         # Konfigurasi php-fpm per versi
├── logs/                # Log & pid semua service
├── www/                 # Default folder web root
├── .env                 # Konfigurasi aktif
├── .env.example         # Template konfigurasi
├── common.sh            # Helper bersama
├── install.sh           # Installer
├── start.sh             # Launcher service
├── stop.sh              # Stop semua service
├── status.sh            # Cek status service
├── switch-php.sh        # Switcher PHP default
└── cmd.sh               # Shell CLI environment
```

---

## Troubleshooting

- **Port 3306 terpakai** (misal ada MySQL/MariaDB lain berjalan): matikan service lain (`brew services stop mariadb`) atau ubah `--port` di `start.sh`.
- **Port 8080 terpakai**: hentikan proses lain yang memakainya (`lsof -nP -iTCP:8080`).
- **`brew services`**: jangan jalankan `brew services start mariadb/nginx` untuk stack ini — `start.sh` mengelola prosesnya sendiri dengan datadir & config lokal.

---

## Lisensi

MIT License.
