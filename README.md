# 🕵️ Param Hunter Ultimate (Windows-Friendly)

**Param Hunter Ultimate** adalah script Bash untuk melakukan hunting parameter URL dari Wayback Machine dan menguji berbagai kerentanan secara otomatis, dengan verifikasi anti false positive.

Script ini sudah dioptimalkan untuk **Windows (Git Bash)**, sehingga:
- Tidak membutuhkan `bc` (pakai `awk` untuk kalkulasi waktu)
- Hanya perlu instalasi minimal tools CLI
- Mendukung single domain (`-u`) atau list domain (`-l`)
- Output terstruktur di dalam folder custom atau `batch_TIMESTAMP`

---

## ✨ Fitur Utama

- **Pengambilan URL unik** dari Wayback Machine (`waybackurls` + filter extension)
- **Scan kerentanan**:
  - XSS (verifikasi ≥ 2 payload + context-aware)
  - LFI (verifikasi file `/etc/passwd` dan `/etc/hosts`)
  - SQLi (Error-based dan Time-based dengan selisih waktu terukur)
  - Open Redirect
  - CRLF Injection
  - Path Traversal (verifikasi 2 file berbeda)
  - Command Injection
  - SSTI (payload unik untuk mengurangi false positive)
  - CSTI (payload unik)
- **Webhook Discord** untuk notifikasi real-time
- **Output terstruktur**:
  - File TXT per kategori vuln per domain
  - HTML report per domain
  - Dashboard HTML untuk semua domain

---

## 📦 Tools yang Dibutuhkan

Script ini dijalankan di **Windows Git Bash** dan membutuhkan tools berikut:

| Tool | Fungsi | Cara Install |
|------|--------|--------------|
| `curl` | Mengirim request HTTP | Sudah ada di Git Bash |
| `grep`, `awk`, `sed`, `sort`, `nl`, `xargs` | Proses teks | Sudah ada di Git Bash |
| `go` | Bahasa Go untuk install tool Tomnomnom | [Download Go](https://go.dev/dl/) |
| `waybackurls` | Ambil URL dari Wayback Machine | `go install github.com/tomnomnom/waybackurls@latest` |
| `qsreplace` | Replace nilai parameter di URL | `go install github.com/tomnomnom/qsreplace@latest` |

**Setelah install Go**, pastikan `GOPATH/bin` masuk ke `PATH` Git Bash:
```bash
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc
```

Cek apakah tool sudah terpasang:
```bash
which waybackurls
which qsreplace
```

---

## 🚀 Cara Penggunaan

1. **Clone repository** (atau simpan file script `param_hunter_windows.sh`):

```bash
git clone https://github.com/username/param-hunter.git
cd param-hunter
```

2. **Beri izin eksekusi script**:

```bash
chmod +x param_hunter_windows.sh
```

3. **Jalankan dengan opsi**:

### Scan Single Domain
```bash
./param_hunter_windows.sh -u target.com
```

### Scan List Domain dari File
```bash
./param_hunter_windows.sh -l targets.txt
```

### Custom Folder Output
```bash
./param_hunter_windows.sh -u target.com -o hasil_scan
./param_hunter_windows.sh -l targets.txt -o hasil_scan
```

4. **Lihat hasil scan**:
   - TXT per kategori → `output_folder/<vuln>_<domain>.txt`
   - HTML report per domain → `output_folder/report_<domain>.html`
   - Dashboard HTML → `output_folder/dashboard.html`

---

## 📌 Contoh

```bash
./param_hunter_windows.sh -u example.com
# Output: batch_20250813/
#   ├── xss_example.com.txt
#   ├── sqli_example.com.txt
#   ├── ...
#   ├── report_example.com.html
#   └── dashboard.html
```

---

## 📊 Diagram Alur Proses

```mermaid
flowchart TD
    A[Mulai] --> B{Input Domain}
    B -->|Single (-u)| C[Scan Domain Tunggal]
    B -->|List (-l)| D[Scan Multiple Domain]

    C --> E[Ambil URL dari Waybackurls]
    D --> E

    E --> F[Filter & Unique URL]
    F --> G[Scan XSS]
    F --> H[Scan LFI]
    F --> I[Scan SQLi Error]
    F --> J[Scan SQLi Time-based]
    F --> K[Scan Open Redirect]
    F --> L[Scan CRLF]
    F --> M[Scan Path Traversal]
    F --> N[Scan Command Injection]
    F --> O[Scan SSTI]
    F --> P[Scan CSTI]

    G --> Q[Generate Report]
    H --> Q
    I --> Q
    J --> Q
    K --> Q
    L --> Q
    M --> Q
    N --> Q
    O --> Q
    P --> Q

    Q --> R[Generate Dashboard]
    R --> S[Selesai]
```

---

## ⚠️ Catatan

- Gunakan script ini **hanya pada target yang diizinkan** (bug bounty / pentest legal).
- Beberapa scan (SQLi Time-based, LFI, Path Traversal) bisa membuat request lambat.
- Untuk hasil maksimal, pastikan koneksi internet stabil dan tool CLI terpasang.

---

## 📄 Lisensi

Script ini dibuat untuk membantu **bug bounty hunters** dan **pentesters** bekerja lebih efisien.  
Gunakan secara etis dan bertanggung jawab.
