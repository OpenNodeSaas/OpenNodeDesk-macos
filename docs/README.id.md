# OpenNodeDesk untuk macOS

**Hub koneksi jarak jauh yang mengutamakan lokal (local-first) untuk macOS.** Simpan setiap server, akun
dan parameter koneksi dalam satu daftar yang dapat dicari, digunakan ulang, dan dipindahkan — lalu beralih
dari "saya butuh mesin itu" ke sesi aktif dalam tiga langkah.

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md) · [ไทย](README.th.md) · **[Bahasa Indonesia]** · [Tiếng Việt](README.vi.md)

Versi saat ini: **v2.3.5**

---

## Apa ini

OpenNodeDesk bukan sekadar klien desktop jarak jauh lainnya. Rendering layar jarak jauh, pengalihan
periferal dan audio/video mengikuti klien paling matang di platform ini — Microsoft Windows App
untuk RDP, Screen Sharing bawaan untuk VNC, dan terminal bawaan untuk SSH. OpenNodeDesk menangani
**90% sisanya**: inventaris, parameter, kredensial, pengingat kedaluwarsa dan
riwayat koneksi.

Prinsip desain:

- **Terhubung dalam tiga detik** — cari, tekan Return, sesi terbuka.
- **Local first, dapat berfungsi offline, tanpa akun** — buka, cari, edit dan hubungkan tanpa jaringan.
- **Jangan membangun ulang roda** — rendering jarak jauh adalah urusan klien terbaik platform.
- **Parameter yang dapat dijelaskan** — setiap nilai efektif diberi label *kustom / templat / bawaan*.
- **Kegagalan yang dapat dijelaskan** — galat datang dengan penyebab dan saran yang dapat ditindaklanjuti, tidak pernah berupa kode mentah.
- **Data portabel** — sekali klik untuk ekspor dan impor; migrasikan mesin dengan satu berkas.
- **Utamakan keyboard** — setiap aksi inti memiliki pintasan.

## Fitur

### Pusat aset
- Tata letak tabel dan kisi; cari di seluruh nama, host, grup, pemilik dan catatan.
- Favorit, koneksi terbaru, dan grup yang dapat diciutkan di sidebar.
- Tampilkan/sembunyikan dan pengurutan ulang per kolom, plus ukuran font daftar secara global.
- Pengingat kedaluwarsa: aset yang kedaluwarsa dalam 30 hari (atau sudah kedaluwarsa) ditandai di tempat.
- Deteksi duplikat berdasarkan **host + port** saat impor.

### RDP / SSH / VNC
- Port bawaan per protokol (3389 / 22 / 5900) dengan opsi penimpaan bebas.
- **RDP** — membuat berkas `.rdp` sementara untuk Microsoft Windows App; mode jendela, kedalaman
  warna, pengalihan drive/audio/papan klip dan resolusi semuanya dapat dikonfigurasi. Biner FreeRDP
  dideteksi dan dijalankan dengan kata sandi yang tersimpan secara langsung, melewati permintaan kredensial.
  Pengisian otomatis kata sandi untuk dialog kredensial Windows App menggunakan API Accessibility macOS.
- **VNC** — menggunakan Screen Sharing bawaan secara default; penampil eksternal (RealVNC, TigerVNC…)
  dapat dikonfigurasi dengan templat argumen peluncuran yang mendukung
  `{host} {port} {display} {user} {password}`.
- **SSH** — terminal sungguhan yang tertanam di dalam aplikasi (SwiftTerm), dengan jump host (`-J`), autentikasi
  kunci privat, dukungan frasa sandi kunci dan argumen `ssh` tambahan yang dapat dikonfigurasi.

### Templat koneksi
Kumpulan parameter yang dapat digunakan ulang (protokol, port, nama pengguna, pengalihan, mode jendela, kedalaman
warna, ukuran jendela SSH). Setiap parameter yang diselesaikan menampilkan nilai saat ini **beserta dari mana
nilainya berasal**.

### Ruang kerja sesi
- Beberapa sesi berdampingan dengan tata letak terpisah yang dapat diganti, maksimalkan per sesi.
- Kotak "buka aset" di toolbar: ketik nama atau host lalu tekan Return, atau pilih dari daftar.
- Jendela SSH terpisah didukung saat Anda lebih menyukainya di luar ruang kerja.

### Transfer berkas SFTP
- Peramban berkas jarak jauh lengkap per aset: direktori, ukuran, izin, waktu modifikasi.
- Unggah dan unduh berkas atau seluruh folder, dengan lanjutkan (`reput` / `reget`).
- Buat folder, hapus berkas atau folder kosong, seret dan lepas berkas ke folder saat ini.
- Tersedia dari toolbar sesi dan dari menu konteks terminal SSH.

### Menu konteks terminal SSH
Salin, tempel, pilih semua dan "transfer berkas" tepat di tempat Anda mengetik. Saat program jarak jauh
mengambil alih mouse (vim, tmux), klik kanan diteruskan ke program jarak jauh seperti yang diharapkan.

### Kredensial
- Kata sandi dan frasa sandi kunci disimpan **hanya** di Keychain macOS, tidak pernah di berkas data.
- Menghapus aset atau menghilangkan centang "ingat kata sandi" akan menghapus entri Keychain.

### Impor, ekspor dan sinkronisasi
- Impor dari CSV atau Excel (`.xlsx`) dengan pemetaan kolom otomatis dan pratinjau validasi.
- Ekspor ke CSV atau JSON, dengan pemilihan per bidang; bidang sensitif tidak dicentang secara default.
- Sinkronisasi cloud menarik pratinjau terlebih dahulu dan hanya menggabungkan apa yang Anda pilih — hanya aset dan templat,
  tidak pernah kata sandi.

### Pemeriksaan keterjangkauan
Pemeriksaan TCP untuk aset tunggal, pilihan atau seluruh inventaris, sesuai permintaan atau berdasarkan pengatur waktu.

### Kunci aplikasi (frasa sandi perlindungan)
- Kunci frasa sandi opsional dengan kunci otomatis saat tidak aktif (1–60 menit).
- Hashing frasa sandi dengan **PBKDF2-SHA256**, 100 000 iterasi dan salt acak 128-bit.
- Kode pemulihan diterbitkan sekali saat penyiapan (Crockford Base32, toleran terhadap `O/0`, `I/L/1`).
- Dapat dikonfigurasi: setelah 5 kegagalan berturut-turut, hapus data lokal secara otomatis, atau tetap terkunci dan
  memerlukan penghapusan manual.

### Tampilan dan bantuan
- Ikuti tema Sistem / Terang / Gelap; antarmuka Bahasa Tionghoa Sederhana dan Inggris.
- Manual bantuan dalam aplikasi yang mencakup penggunaan VNC, pemecahan masalah per protokol, lokasi data dan
  privasi kredensial.

## Persyaratan

| Item | Persyaratan |
| --- | --- |
| macOS | 14.0 (Sonoma) atau lebih baru |
| Pembawa RDP | Microsoft Windows App (dari App Store) |
| Pembawa VNC | Screen Sharing bawaan, atau RealVNC / TigerVNC dan sejenisnya |
| Pengisian otomatis kata sandi RDP | Izin Accessibility untuk OpenNodeDesk |
| Membangun dari kode sumber | Xcode 16 atau lebih baru (toolchain Swift 6) |

## Instalasi

1. Unduh `OpenNodeDesk-<version>-macos.zip` dari halaman
   [Releases](https://github.com/OpenNodeSaas/OpenNodeDesk-macos/releases).
2. Ekstrak dan seret `OpenNodeDesk.app` ke `/Applications`.
3. Build ini tidak dinotarisasi oleh Apple, jadi Gatekeeper mungkin memberi peringatan saat peluncuran pertama — klik kanan
   aplikasi dan pilih **Open**, atau izinkan di *System Settings → Privacy & Security*.

## Membangun dari kode sumber

```bash
git clone https://github.com/OpenNodeSaas/OpenNodeDesk-macos.git
cd OpenNodeDesk-macos
make bundle   # release build + dist/OpenNodeDesk.app
make run      # build, bundle and launch
```

Target yang berguna: `make check` (kompilasi dan tampilkan diagnostik), `make clean` (hapus `.build` dan
`dist`), `make reset` (hapus data lokal dari `~/Library/Application Support/RemotePilot`).

## Tata letak proyek

```
Sources/RemotePilot/
├── App/            Titik masuk aplikasi, model global, perintah dan menu
├── Core/           SSH/SFTP, Keychain, probing, impor/ekspor, sinkronisasi, deteksi pembawa, pengisian otomatis RDP
├── Design/         Token desain dan komponen bersama
├── Localization/   String sumber Bahasa Tionghoa + tabel string Bahasa Inggris
├── Models/         Model aset, templat, pengaturan dan runtime
├── Views/          Sidebar, pusat aset, ruang kerja, sesi, pengaturan, bantuan, dialog
└── main.swift      Titik masuk (juga berfungsi sebagai helper SSH_ASKPASS)
Resources/          Info.plist dan ikon aplikasi
docs/              Dokumen desain dan README terjemahan
```

## Data dan privasi

- Aset, templat dan pengaturan tersimpan di `~/Library/Application Support/RemotePilot`
  (`assets.json`, `settings.json`).
- Kata sandi dan frasa sandi kunci hanya ditulis ke Keychain macOS; keduanya tidak pernah menjadi bagian dari
  ekspor atau muatan sinkronisasi. Karena itu, berpindah ke mesin lain mengharuskan Anda memasukkannya kembali.
- Aplikasi berfungsi sepenuhnya offline; endpoint sinkronisasi cloud bersifat opsional dan disediakan oleh pengguna.

## Catatan dan keterbatasan

- Windows App di macOS tidak dapat menampung beberapa sesi sebagai tab dalam satu jendela; memilih mode jendela
  bertab akan membuka jendela biasa sebagai gantinya. Gunakan ruang kerja sesi untuk beberapa sesi.
- Jika tidak ada pembawa RDP yang terpasang, upaya koneksi akan menjelaskan apa yang perlu dipasang dan di mana.
- Pengenal bundel internal `com.remotepilot.macos` dan direktori data
  `RemotePilot` sengaja dibiarkan tidak berubah sejak penggantian nama, sehingga aset, pengaturan dan
  entri Keychain yang ada tetap berfungsi setelah peningkatan.

## Dokumentasi

- [Desain produk & UX](PRODUCT_UX_DESIGN.md)
- [Delta desain](PRODUCT_UX_DESIGN_DELTA.md)
- [Kunci frasa sandi dan kunci otomatis saat tidak aktif](../.trae/documents/保护口令与空闲自动锁定-macOS.md)
