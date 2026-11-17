# Handoff — Rivalift (status 17 Nov 2026)

Ringkasan supaya sesi Claude berikutnya bisa langsung lanjut. Spesifikasi produk ada di
`docs/PRD.md`, aturan kerja di `CLAUDE.md`. Baca dua file itu dulu, lalu dokumen ini.

## Konteks

- Rivalift: gym log iOS dengan liga mingguan antar teman. SwiftUI, Swift 6, SwiftData (CloudKit), iOS 17+.
- Branch kerja: `claude/determined-shannon-e2byic`. Proyek Xcode dibuat dengan `xcodegen generate`
  (jalankan setiap kali menambah atau menghapus file).
- Pemilik: Herdetya (user GitHub `herdetya96`). Bahasa percakapan: Indonesia. Teks di app: Inggris.
- Milestone: M0–M2 selesai. M3 hampir selesai (sisa: build TestFlight). M4 backend belum mulai.
  M5 liga: tampilan lengkap dengan data contoh. M6 belum.

## Status kode

Commit terakhir `5a1208a` (redesign dark glass, liga data contoh, 18 foto latihan).
**Semua pekerjaan di bawah belum di-commit.** Run penuh terakhir: **67 unit + 8 UI test lulus.**

**Langkah pertama sesi baru:** tanyakan ke Herdetya apakah boleh commit. Kalau ya, commit semuanya,
lalu pindahkan issue Notion yang In Review ke Done dan isi kolom Commit (lihat bagian Notion).

### Yang dikerjakan sejak `5a1208a`

1. **Pengingat latihan (NOT-02).** `Core/Domain/ReminderPlanner.swift` (pure, ada tes) menghitung
   tanggal notifikasi 14 hari ke depan pada hari latihan dan jam pilihan, melewati hari ini kalau
   sudah latihan. `NotificationService.scheduleWorkoutReminders`, dipanggil dari
   `AppEnvironment.refreshWorkoutReminders()` (setiap `dataDidChange` dan saat app aktif).
   Settings punya pemilih hari (`WeekdayPicker`) dan jam. Teks notifikasi sengaja tidak memakai
   kalimat PRD "your crew" karena liga belum hidup.
2. **Foto profil (AUTH-04).** `UserSettings.avatarImageData` (`@Attribute(.externalStorage)`,
   ditambahkan langsung di V1 karena belum pernah rilis). `PhotosPicker` di Edit profile,
   diperkecil ke 400 px JPEG. `ProfileAvatar` menampilkan foto atau avatar dummy.
3. **Foto semua latihan.** 132 latihan punya foto sendiri di
   `Assets.xcassets/Exercises/Exercise_<key>.imageset/photo.heic`: **HEIC transparan** 600×400,
   total 3,7 MB. Latarnya dihapus dengan `scripts/exercise_photos/` (Vision foreground mask + key
   kecerahan supaya tiang kabel/mesin tetap ada, pantulan lantai dibuang). `ExerciseArt` memakai
   foto apa pun yang ada; latihan custom jatuh ke foto per kelompok otot. Tes
   `everyExerciseHasAPhoto`.
4. **Deskripsi latihan.** `Resources/exercise_guides.json` (about + 4 langkah + 2 tips untuk ke-132
   latihan, ditulis Claude, belum dicek pelatih). Dimuat lewat `SeedLoader.loadGuides` dan
   `ExerciseRepository.guide(for:)`. `ExerciseDetailView` punya foto besar, "How to do it", "Tips".
   Detail program (`TemplateDetailView`) sekarang bisa diketuk ke detail latihan. Tes
   `everyExerciseHasAGuide`.
5. **Foto latihan di semua daftar.** Pemilih latihan, pemilih lift liga, daftar lift, rekor Home,
   detail sesi, editor template, rekomendasi di Start Workout. `ExerciseIcon` (SF Symbol) dihapus.
6. **Design system kaca untuk semua sub-screen.** Komponen bersama di
   `Core/DesignSystem/GlassForm.swift`: `GlassSection`, `GlassCard`, `GlassDivider`, `GlassRow`,
   `GlassAddLabel`, `GlassRemoveButton`, `GlassChoiceRow`, `PillMenuLabel`, `FilterPill`,
   `.glassField()`, `.glassListRow()`, `.glassList()`. Sekitar 15 layar Form/List dibangun ulang:
   buat grup, pengaturan grup, mode liga, editor kategori, penjelasan liga/skor, edit profil,
   pemilih latihan, buat latihan, editor template (tetap `List` untuk swipe/drag), susun ulang,
   semua workout, kalender, detail sesi. `ExerciseRowCard` punya varian centang (`isSelected`).
   Di daftar lift/kategori liga, hapus pakai tombol − (bukan swipe).
7. **Buat grup dan gabung grup jadi halaman push**, bukan sheet. `LeaguesView` memegang
   `isCreating` dan `navigationDestination`; `CreateGroupView(onFinish:)` → `InviteView` → Done
   kembali ke Leagues. Bug diperbaiki: keyboard muncul lagi setelah kembali dari editor kategori
   dan menutup tombol Create (fokus nama sekarang sekali saja).
8. **Onboarding:** garis merah di daftar "Building your plan" dihapus.
9. **Lain-lain:** `docs/EXERCISE_PHOTOS.md` diringkas; status M3 di `CLAUDE.md` diperbarui.

## Yang belum beres

- **2 foto perlu di-generate ulang** (posenya salah): `bayesian_cable_curl` (harus membelakangi
  mesin kabel, satu tangan, lengan sedikit di belakang badan) dan `wrist_curl` (harus telapak ke
  atas). Setelah Herdetya mengirim gambar baru, jalankan `scripts/exercise_photos/cutout.py`
  (petunjuk di docstring-nya). Detail di `docs/EXERCISE_PHOTOS.md`.
- **Label teks di Figma "All Exercises" salah ketik** (hanya di Figma, app tidak terpengaruh):
  "Shouldera", "Reserve Barbell Curl", Close-Grip Bench otot utama Biceps (harusnya Triceps),
  Reverse Dumbbell Fly otot kedua Biceps (harusnya Back).
- **TestFlight (sisa M3).** Akun Apple Developer **berbayar** (team `RXV32BBK97`, profil berlaku
  sampai Sep 2027). Yang kurang:
  - **Ikon app belum ada** (`AppIcon.appiconset` kosong). Wajib sebelum upload. Tanyakan apakah ada
    di Figma atau perlu dibuatkan.
  - Herdetya harus membuat app record di App Store Connect (bundle `app.rivalift.ios`).
  - Tambahkan `ITSAppUsesNonExemptEncryption = NO` di Info.plist.
  - Deploy skema CloudKit `iCloud.app.rivalift.ios` ke Production (TestFlight memakai production).
- **Rekomendasi retensi** (audit + riset Mobbin, tercatat di Notion): sebelum M4 kerjakan
  layar streak (pakai `streakGoalWeeks` dari onboarding yang belum pernah ditampilkan, plus
  "minggu istirahat") dan kartu share setelah latihan. Setelah M5: milestone/badge, rekap bulanan,
  peta otot, widget. Kartu share dan widget masih *out of scope* di PRD; perbarui PRD kalau diambil.

## Perangkat

- **Simulator:** iPhone 18 Pro `D8A495E6-E88B-41A3-A8DC-C511E5F99E7B`. Tap di simulator sering
  tertunda satu langkah; untuk cek visual lebih andal pakai UI test sementara yang menyimpan
  screenshot (`XCUIScreen.main.screenshot()`), lalu hapus tesnya.
- **iPhone 17 Herdetya** `00008150-001534C03A01401C`: build 16 Okt (pengingat + foto profil, belum
  ada foto/deskripsi latihan dan restyle).
- **iPhone 15 Bahrur** `00008120-0011385C2663601E`: build terbaru (17 Nov), Developer Mode aktif.
- Pasang ke HP:
  ```sh
  xcodebuild -project Rivalift.xcodeproj -scheme Rivalift -destination 'id=<UDID>' \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build/device build
  xcrun devicectl device install app --device <UDID> build/device/Build/Products/Debug-iphoneos/Rivalift.app
  xcrun devicectl device process launch --device <UDID> app.rivalift.ios
  ```
  HP baru: colok, Trust, coba build sekali (supaya opsi muncul), lalu nyalakan Developer Mode di
  Settings → Privacy & Security (paling bawah).

## Catatan teknis

- Satu run penuh `xcodebuild test` sekitar 8 menit (8 UI test). Jalankan di background dan jangan
  build lagi selama tes berjalan. Untuk satu tes: `-only-testing:RivaliftUITests/RivaliftUITests/<nama>`.
- UI test: pasang `accessibilityIdentifier` di tombolnya sendiri, **bukan** di wadah
  `.padding().background(Theme.bottomFade)`; XCUI mengetuk tengah wadah. Tutup keyboard
  (`typeText("…\n")`) sebelum mengetuk tombol di bawah. Kartu dengan
  `.accessibilityElement(children: .combine)` dicari lewat label (helper `exerciseCard`, `labelled`).
- CloudKit: semua atribut model wajib punya default atau optional; jangan pakai `.unique`.
- Mobbin, Figma (`get_design_context`, `download_assets`), dan Notion tersedia lewat MCP.
  Figma file: [Rivalift — iOS Screens](https://www.figma.com/design/UbndheXZjjzAloGIBkWKPp).

## Notion

Workspace Plainthing Studio, teamspace "Rivalift App". Database **Issues**
`collection://d7ed16ef-0624-4b38-88d8-74de0aab8e00` dan **Updates**
`collection://b005560f-90aa-4c71-8522-0bbcbd2476e8`. Aturan: setiap pekerjaan jadi issue,
setiap langkah selesai jadi update; "In Review" = sudah dites tapi belum di-commit.

Issue In Review yang menunggu commit (pindahkan ke Done + isi Commit):

| Issue | Page ID |
|---|---|
| Workout reminders (NOT-02) | `3fbb3ea8-1081-815e-9627-e9e5b23f3db6` |
| Profile photo avatar (AUTH-04) | `3fbb3ea8-1081-811b-987c-cfbea2a58d4e` |
| 114 generated exercise photos | `3ffb3ea8-1081-8124-9a1b-d36a0cd85713` |
| Exercise guides + photos on every screen | `3ffb3ea8-1081-81d4-b8e6-c7dfcbb4fbb6` |
| Glass sub-screens, push create group, transparent photos | `3ffb3ea8-1081-8188-8130-c6dcb72ed392` |

Audit retensi + riset Mobbin: `3fbb3ea8-1081-818c-8f0b-edad2aa9eed2` (Done, berisi rekomendasi).

## Langkah berikutnya

1. Commit (setelah Herdetya setuju), perbarui Notion.
2. Ganti 2 foto latihan begitu gambar barunya ada.
3. TestFlight: ikon app, Info.plist, app record, CloudKit production, archive + upload.
4. Retensi sebelum M4: layar streak, kartu share.
5. M4: proyek Supabase "rivalift" (organisasi "animos app"), login Apple + Google, sinkronisasi; lalu M5.
