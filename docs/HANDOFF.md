# Handoff — Rivalift (status 1 Oct 2026)

Ringkasan sesi 24 Sep – 1 Okt 2026 supaya sesi berikutnya bisa langsung lanjut. Spesifikasi
produk ada di `docs/PRD.md`, aturan kerja di `CLAUDE.md`.

## Konteks

- Rivalift: gym log iOS dengan liga mingguan antar teman. SwiftUI, Swift 6, SwiftData (CloudKit), iOS 17+.
- Branch kerja: `claude/determined-shannon-e2byic`. Proyek Xcode dibuat dengan `xcodegen generate`.
- Simulator: iPhone 18 Pro, `D8A495E6-E88B-41A3-A8DC-C511E5F99E7B`.
- Milestone: M0–M2 selesai. M3 berjalan (sisa: pengingat NOT-02, foto avatar, TestFlight).
  M4 backend belum mulai. M5 liga: tampilan dengan data contoh sudah ada. M6 belum.

## Commit

| Commit | Isi |
|---|---|
| `9ab4d95` | Scaffold M0–M2 |
| `597e09e` | Onboarding 6 langkah, start chooser, metrik Home |
| `c18c9bc` | Start workout jadi layar push, detail template, perbaikan bug, team ID di `project.yml` |

### Belum di-commit

Liga dengan data contoh, mode Strength/Custom, penjelasan 1RM, perbaikan alur kategori,
batas lift 1–5, update PRD.

- Diubah: `AppEnvironment`, `Components`, `CustomCategoryScorer`, `StrengthScorer`, `HomeView`,
  `LeaguesView`, `OnboardingView`, `ExerciseDetailView`, `ExerciseCardView`, `WorkoutSummaryView`,
  `RivaliftUITests`, `docs/PRD.md`.
- Baru: `Core/Domain/LeagueBoards.swift`, `Core/Domain/LeagueStandings.swift`,
  `Features/Leagues/{GroupLeaderboardView, GroupSetupViews, LeagueModeViews, LeagueStore, WeekResultsView}.swift`,
  `RivaliftTests/{LeagueBoardsTests, LeagueStandingsTests}.swift`.

**Langkah pertama:** jalankan semua tes, lalu commit. Run penuh terakhir yang tercatat lolos
(62 unit, 7 UI) terjadi sebelum batas lift dinaikkan ke 5. Setelah itu hanya
`testAddLiftThenMixIntoCustom` yang dijalankan (lolos). Run penuh dengan 8 UI test belum tercatat hasilnya.

## Yang dikerjakan

### Alur mulai latihan (sudah di-commit)
- `TemplateDetailView`: pratinjau latihan, sets × reps, waktu istirahat, tombol Start.
- Layar start: program diringkas jadi satu baris "Browse all templates".
- Start workout adalah layar push dari Home (`StartWorkoutView`). Setelah workout dimulai, app
  kembali ke Home. Sheet dan jalan pintasnya (`choose`, `begin`) dihapus.

### Liga dengan data contoh (belum ada backend)
Keputusan Herdetya: tampilan dulu, backend nanti. Login nanti: Apple + Google.

- Domain: `LeagueStandings` (peringkat, aturan penentu skor sama, selisih poin, naik/turun),
  `InviteCode` (6 karakter tanpa 0/O/1/I), `LeagueCountdown`, `LeagueBoards` (ketiga mode jadi
  baris papan peringkat), `LeagueMode`, `StrengthSetup` (1–5 lift), preset kategori Custom.
- `LeagueStore` + `SampleLeagues`: Office Lifters (Consistency), Garage Gym (Strength Relative),
  Pull-up Club (Custom: pull-up max reps, curl best set volume min 8, plank longest hold),
  Campus Crew (Consistency). Baris "me" memakai latihan asli lewat `env.myLeagueInput(for:)`.
- Layar: daftar grup; leaderboard (tab Overall + per kategori, mode badge, keterangan
  "mulai Senin depan", pengaturan grup); hasil minggu lalu dengan podium; Create group dengan
  pemilih mode; Invite (kode + link `rivalift.app/join/…`); Join with code; kartu liga di Home;
  tanda 🏆 di latihan yang dilombakan ("Your best · Leader"); perubahan peringkat di ringkasan
  workout (**belum dicek langsung di layar**).
- Batasan preview: grup yang dibuat/diikuti hilang saat app ditutup; kode apa pun membuka grup
  contoh "Iron Squad"; domain `rivalift.app` belum terdaftar.

### Penjelasan dan kemudahan
- ⓘ untuk **1RM** (arti, rumus Epley, contoh, aturan 1–12 reps) di Exercise detail, rekor Home,
  dan ringkasan workout.
- Bug diperbaiki: "New category" menutup layar New group (sheet bertumpuk). Semua editor sekarang push.
- Kategori bisa diedit; setiap metrik dan cara membandingkan (Absolute/Improvement) punya
  penjelasan dan contoh. Contoh Andi vs Sam untuk Strength Relative/Absolute.
- Strength 1–5 lift (PRD SOC-13 dan bagian 6.2 diperbarui). "Add lift" dan "New category" selalu
  terlihat (abu-abu saat penuh). "Mix lifts with other exercises" mengubah mode ke Custom dengan
  lift jadi kategori Estimated 1RM.

## Di luar kode

- **Figma:** [Rivalift — iOS Screens](https://www.figma.com/design/UbndheXZjjzAloGIBkWKPp)
  (tim Plainthing Studios). Semua layar termasuk 9 layar onboarding, komponen, variabel Light/Dark.
  Layar liga, mode, dan 1RM yang baru **belum** ada di Figma.
- **PRD artifact:** https://claude.ai/artifact/FapSBEKvvgJo1aAL33hLAA (privat, bagikan lewat
  Share). Belum memuat perubahan 1–5 lift.
- **Notion:** workspace Plainthing Studio, teamspace "Rivalift App", halaman "Rivalift" dengan
  database **Issues** (RIV-n) dan **Updates**. Setiap pekerjaan dicatat sebagai issue, setiap
  kemajuan sebagai update. Issue liga, 1RM, bug kategori, dan kejelasan mode masih **In Review**:
  pindahkan ke Done dan isi hash commit setelah commit.
- **iPhone fisik:** team `RXV32BBK97` login di Xcode; app terpasang di iPhone 17
  (`00008150-001534C03A01401C`), masih versi `c18c9bc` (belum ada liga). Pasang ulang:
  build ke destination itu dengan `-allowProvisioningUpdates`, lalu
  `xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-iphoneos/Rivalift.app`.
- **Supabase:** organisasi "animos app" (proyek baru gratis). Belum ada proyek Rivalift; rencananya
  proyek baru "rivalift" saat backend dimulai.
- **Disk Mac:** sempat penuh; sisa sekitar 20 GB. Pantau sebelum build besar.

## Langkah berikutnya

1. Jalankan semua tes, commit, perbarui issue Notion, pasang ke iPhone.
2. Sisa M3: pengingat latihan NOT-02 (pengaturan sudah ada di `UserSettings`, belum dijadwalkan),
   foto avatar (AUTH-04), build TestFlight.
3. M4: proyek Supabase, login Apple + Google, sinkronisasi; lalu M5 liga sungguhan.
4. Opsional: perbarui Figma dan PRD artifact.
5. Backlog: edit sesi lama (LOG-15), liga cardio/lari (ditunda atas permintaan Herdetya).
