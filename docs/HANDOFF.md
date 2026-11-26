# Handoff — Rivalift (status 26 Nov 2026)

Ringkasan supaya sesi Claude berikutnya bisa langsung lanjut. Spesifikasi produk ada di
`docs/PRD.md`, aturan kerja di `CLAUDE.md`. Baca dua file itu dulu, lalu dokumen ini.

## Konteks

- Rivalift: gym log iOS dengan liga mingguan antar teman. SwiftUI, Swift 6, SwiftData (CloudKit), iOS 17+.
- Proyek Xcode dibuat dengan `xcodegen generate` (jalankan setiap kali menambah atau menghapus file).
- Pemilik: Herdetya (user GitHub `herdetya96`). Bahasa percakapan: Indonesia. Teks di app: Inggris.
- Milestone: M0–M2 selesai. M3 hampir selesai (sisa: build TestFlight). M4 backend belum mulai.
  M5 liga: tampilan lengkap dengan data contoh. M6 belum.

## Branch dan status

| Branch | Isi | Status |
|---|---|---|
| `claude/determined-shannon-e2byic` | Pekerjaan sampai `54b5381` (My Plan Home pertama) | Di-push, base PR #1 |
| `claude/minimal-design-system` | Dibuat dari `54b5381`, berisi semua pekerjaan sejak 23 Nov | **Branch aktif.** Di-push, PR #1 |

Run penuh terakhir di `claude/minimal-design-system` (`e74475f`): **93 unit + 12 UI test lulus.**
PR: https://github.com/Plainthingstudio/rivaliftapp/pull/1 (ke `claude/determined-shannon-e2byic`,
bisa di-merge, belum di-review; repo tidak punya CI).

Commit di branch aktif (lama → baru):

| Commit | Isi |
|---|---|
| `54b5381` | My Plan Home: latihan hari ini, strip minggu, progres plan |
| `58a1357` | Design system minimalis dari Figma + kartu Home sesuai artifact |
| `2303ac2` | Layar Plan dan tukar latihan (⇄) |
| `38a9104` | Detail plan: mode preview, tombol Edit membuka mode edit |
| `7828a3d` | Tab Library menggantikan History; History pindah ke Profile |
| `4ef2191` | Plan bernama tujuan (PlanCatalog); split jadi isi plan |
| `3839565` | Program sendiri untuk Get Lean ("Full body burn") |
| `2aed1ea`, `b557b14` | Dokumen handoff |
| `7562d66` | Layar Streak dengan rest week (RIV-58) |
| `b608f3b` | Quick Workout dari menu mode Home (RIV-59) |
| `acb5f6f` | PRD: PLAN-01…09, LIB-07, PROG-07 (RIV-61) |
| `53a313a` | Pilih jumlah hari per minggu sebuah plan; jadwal minggu ini (RIV-63) |
| `de963cf` | Detail plan: tombol hari besar, pilih hari, mulai di tengah minggu, konfirmasi ganti (RIV-64) |
| `dac39a5` | Plan ditulis dengan nama tujuan di onboarding (RIV-66) |
| `d59e591`, `684d5fc` | Mode Custom dibangun ulang di sekitar workout sendiri; nama tetap "Custom" (RIV-67) |
| `2114e56` | Custom: edit workout, Create workout jadi menu utama, Save as mine (RIV-67) |
| `d0a3059` | Editor workout: kartu rapi, ganti latihan, menu Sets/Reps/Rest (RIV-67) |
| `e74475f` | Editor workout jadi layar sendiri, bukan sheet (RIV-67) |

## Latar belakang keputusan (sesi 23 Nov)

Masalah yang disampaikan Herdetya: app terlalu membingungkan untuk pemula, istilahnya tidak ramah
pemula, program tidak konsisten, memilih program susah. Tujuannya:

- Di Home user langsung tahu latihan hari ini; program sudah pasti tapi tetap bisa diubah.
- Nama plan ramah pemula ("Get in Shape", "Get Lean", "Build Muscle"…); split (Push/Pull/Legs dll.)
  hanya isi di dalamnya.
- Dua mode seperti Hevy: **My Plan** (terarah) dan **Custom** (bebas), plus Quick Workout untuk
  satu latihan dadakan (dibuat, lihat bagian 7; Custom dibangun ulang, lihat bagian 8).
- IA baru: tab **Home, Library, Leagues, Profile**. History pindah ke Profile.
- Gaya visual: lebih minimalis, mengikuti Figma node `695:29871` ("Home").

Desain konsep ada di artifact canvas **"Rivalift Coach Mode"**:
https://claude.ai/artifact/DbxV2uho7pZvLZdUJYMdo8 (Home penuh, rest day, menu mode, Quick Workout,
Custom, Plan, Library, Profile, Swap sheet, dan Home untuk 1×–6× seminggu). Desain itu konsep,
bukan spesifikasi piksel; app mengikuti alurnya dengan design system dari Figma.

Keputusan streak (sudah diimplementasikan, `7562d66`): streak **mingguan**, bukan harian (hari
istirahat bagian dari plan; Herdetya setuju tetap mingguan). Rest week **hanya melindungi streak
pribadi**, poin liga tidak berubah. Rest week didapat otomatis: 1 per 4 minggu yang mencapai target,
maksimal 2 disimpan.

## Yang sudah dikerjakan

### 1. My Plan Home (`54b5381`, disempurnakan di commit berikutnya)

- **Domain** `Core/Domain/PlanWeek.swift` (pure, tes di `PlanWeekTests`):
  - `PlanWeek.make(rotation:weekdays:done:lastDone:now:calendar:)` membagi rotasi latihan ke hari
    latihan Senin–Minggu. Status hari: `done`, `today`, `upcoming`, `missed`, `rest`. Latihan
    berikutnya = setelah latihan plan terakhir yang selesai (`PlanRecommender.next`), jadi hari
    terlewat tidak melompati latihan.
  - `PlanWeek.defaultWeekdays(count:)`: hari bawaan kalau user belum memilih (1×: Sab, 2×: Sel/Jum,
    3×: Sen/Rab/Jum, 4×: Sen/Sel/Kam/Jum, 5×: +Sab, 6×: Sen–Sab).
  - `PlanProgress.make`: "Week x of n" dan "x of y workouts done".
- **AppEnvironment** (extension di bawah `TrainingOverview`):
  - `planHome(now:) -> PlanHome?`: program dari `settings.planProgram`, minggu ini, progres. Mengisi
    `planStartedAt` sekali kalau kosong.
  - `planWeekdays()`: hari latihan pilihan user, atau `defaultWeekdays(effectiveWeeklyTarget)`.
  - `prescription(for:)`: "3 sets · 8 reps · 40 kg" (beban dari `ProgressionEngine`, muncul setelah
    ada riwayat).
  - `splitName(for:)`: nama split ("Full body", "Upper / Lower", "Push / Pull / Legs",
    "Strength basics", "Full body burn").
- **UI** `Features/Home/PlanHomeViews.swift`: `PlanCard`, `PlanWeekStrip` (label pendek dari nama
  template lewat `shortLabel`), `PlanToday` (daftar latihan hari ini, atau kartu rest/done dengan
  "Next up"), `PlanStartButton` (menempel di bawah: "Start today's workout" / "Train anyway · …" /
  "Resume workout").
- **Menu mode** di header Home: "My Plan ▾" / "Custom ▾" (`UserSettings.homeMode`,
  `homeModeRaw`). Isi Custom lihat bagian 8. Tanpa plan, Home selalu Custom. UI test pindah ke
  Custom lewat helper `openStartScreen` (menunggu `startPickExercises`).
- Urutan Home (My Plan): header → kartu plan → strip minggu → latihan hari ini → kartu liga →
  personal best minggu ini → "Your training".

### 2. Design system minimalis (`58a1357`)

Semua token terpusat, jadi seluruh app ikut berubah:

- `Theme.glassFill` = putih 10%, `Theme.border` = putih 16%, `Theme.glassControl` = `#292929`,
  `Theme.success` = `#17B26A`, `Theme.primaryGradient` = biru `#0072BE → #27A9FF` (atas → bawah).
  `AccentColor` sekarang biru `#27A9FF`. `Theme.heat` (merah) hanya untuk ikon api streak.
- `.glassCard(cornerRadius:)` = fill + border tipis + bayangan `0 4 4 / 25%`.
- `.buttonStyle(.primary)` = pill putih, teks hitam, tinggi 48. `.secondary` = pill `#292929`,
  border putih 30%.
- `ScreenBackground` = hitam dengan satu glow biru di atas (path dari Figma "Bg"); glow merah di
  tengah dihapus.
- Dihapus: `redCard`/`redFill`, `barGradient`, `blueGlow`, `dotTexture`, aset `DotGrid`,
  `DotGridWeek`, `BlueGlow`, ring putus-putus. `RingIcon` = lingkaran biru polos.
  `InfoChip` = outline, `PillPicker`/`WeekdayPicker` = fill kartu + border.
- **Font:** tetap SF (sistem); Figtree dari Figma sengaja tidak dipakai (keputusan 24 Nov, RIV-60
  Canceled). Masih ada beberapa inner shadow kecil di level
  fitur (trek progres di History/Exercise detail, `RestTimerBar`) yang belum diseragamkan.
- Kartu Home mengikuti artifact: liga menampilkan top 3 (atau top 2 + kamu) dengan baris kamu
  disorot dan selisih poin; "Personal bests this week"; "Your training" = Workouts, Time trained,
  Total lifted vs minggu lalu + batang 8 minggu.

### 3. Tukar latihan (⇄) dan layar Plan (`2303ac2`, `38a9104`)

- **Domain** `Core/Domain/ExerciseSwap.swift` (tes `ExerciseSwapTests`):
  - `candidates(for:from:excluding:limit:)`: otot utama sama, bukan latihan yang sudah ada di sesi
    itu; urutan berdasar otot pembantu yang sama, lalu jenis (compound/isolation).
  - `DaySwaps`: tukar "Just today", disimpan di `UserSettings.daySwapsRaw` sebagai
    `"yyyy-MM-dd|teID:exID,…"`, otomatis kedaluwarsa besok.
- **AppEnvironment:** `todaySwaps()`, `planExercise(for:)`, `swapCandidates(for:)`,
  `swap(_:to:always:)`. "Always in my plan" mengubah `TemplateExercise.exercise` di template bawaan
  secara langsung (aman: seeder tidak pernah menimpa template yang sudah ada; ada komentar
  `ponytail:`).
- **Start:** `WorkoutStore.StartRequest.template(UUID, swaps: [UUID: UUID] = [:])` →
  `SessionRepository.start(from:swaps:)`. Tombol start plan mengirim `env.todaySwaps()`.
- **UI:** `Features/Home/SwapSheet.swift` (daftar pilihan, PillPicker "Just today / Always in my
  plan", tombol "Swap to …"). Tombol ⇄ di setiap baris latihan hari ini.
- **Layar Plan** `Features/Plan/PlanView.swift`, dibuka dengan mengetuk kartu plan di Home
  (`accessibilityIdentifier("planCard")`). Tidak ada link "Edit plan" di Home (permintaan Herdetya).
  - **Preview** (default): judul, "split · N days a week · N weeks", "Week x of n · Started …",
    kartu per hari latihan (hari jatuhnya minggu ini + foto latihan, buka `TemplateDetailView`),
    ringkasan Training days dan Plan length.
  - **Edit** (tombol toolbar Edit/Done): `WeekdayPicker` untuk hari latihan, Stepper panjang plan
    (4–16 minggu, menulis `streakGoalWeeks`), tombol "Change plan" (sheet berisi katalog plan).
  - Hari latihan = `UserSettings.trainingWeekdays` (sama dengan hari pengingat).

### 4. Library dan History di Profile (`7828a3d`)

- `AppTab` = `home, library, leagues, profile`. Tab History dihapus.
- `Features/Library/LibraryView.swift`: PillPicker **Plans / Exercises / My workouts**.
  - Plans: "CURRENT PLAN" (buka `PlanView`) lalu "ALL PLANS" dari `PlanCatalog` (kartu
    `PlanCatalogCard`: judul, ringkasan, chip hari/minggu/level).
  - `PlanDetailView`: ringkasan, "What's inside: <split>", hari-hari latihan, tombol
    "Start this plan" (`env.startPlan`) → pindah ke tab Home.
  - Exercises = `ExerciseLibraryView` (dulu di Profile). My workouts = `TemplatesView(showsPrograms: false)`.
- Profile: kartu **History** (jumlah latihan bulan ini + latihan terakhir, "See all" →
  `HistoryView` sekarang punya tombol kembali). Menu Templates dan Exercises dihapus dari Profile.

### 5. Plan bernama tujuan (`4ef2191`, `3839565`)

- `Core/Domain/PlanCatalog.swift` (tes `PlanCatalogTests`, termasuk cek ke `templates.json`):

  | ID | Judul | Isi | Hari | Minggu | Level |
  |---|---|---|---|---|---|
  | `get-in-shape` | Get in Shape | Full body; 4 hari → Upper/Lower | 3–4 | 8 | Beginner |
  | `get-lean` | Get Lean | Full body burn; 4 hari → Upper/Lower | 3–4 | 8 | Beginner |
  | `build-muscle` | Build Muscle | Upper/Lower; 5+ hari → Push/Pull/Legs | 4–6 | 12 | All levels |
  | `get-stronger` | Get Stronger | 5×5 | 3 | 8 | Beginner |
  | `overall-fitness` | Overall Fitness | Full body | 2–3 | 6 | Beginner |
  | `go-all-in` | Go All In | Push/Pull/Legs | 5–6 | 12 | Experienced |

- `UserSettings.planID` menyimpan plan yang dipilih. `env.currentPlan` = plan itu, atau
  `PlanCatalog.plan(for: goal)` untuk user lama. Judul di Home/Library/Plan selalu dari sini.
- `env.startPlan(_:)` mengisi `planID`, `planProgram` (dari target mingguan), `streakGoalWeeks`
  (= minggu plan), `planStartedAt`, mengosongkan swap hari ini, dan mode Home = My Plan.
  **Hari latihan tidak ikut berubah** (misalnya Build Muscle tetap jalan 3 hari kalau target 3).
- Onboarding mengisi `planID` dari goal (strength → Get Stronger, muscle → Build Muscle,
  consistency → Get in Shape, fitness → Overall Fitness). `planProgram` masih dari
  `PlanRecommender.program` (mempertimbangkan level).
- Program baru di `templates.json`: **"Get Lean 3×"** (`PlanRecommender.getLean`), hari
  "Full Body Burn A/B/C": 12–15 repetisi, istirahat 45–60 detik, finisher (kettlebell swing,
  burpee, mountain climber, plank).
- Baris Goal di layar Plan dihapus (plan = tujuan). `AppEnvironment.planTitle(for:)` dan
  `programInfo(for:)` sudah tidak ada.

### 6. Layar Streak (`7562d66`)

- `Core/Domain/PersonalStreak.swift` (tes `PersonalStreakTests`): minggu terhitung kalau target
  mingguan tercapai; tiap 4 minggu terhitung memberi 1 rest week (maks 2); minggu terlewat memakai
  1 rest week dan streak lanjut tanpa bertambah; tanpa rest week streak dan simpanan reset; minggu
  berjalan tidak pernah memutus streak. `history` = met/rest/missed per minggu selesai.
- `AppEnvironment.streakOverview()` menghitung dari minggu latihan pertama, target per minggu dari
  `effectiveWeeklyTarget(at:)`. **Liga tetap memakai `WeekCalendar.streak`** (tanpa rest week) di
  `leagueEstimate` dan `WorkoutStore.myLeagueEntry`.
- 🔥 di header Home = streak pribadi, membuka `Features/Streak/StreakView.swift` (hero + best,
  This week, Rest weeks dengan ikon perisai, 12 minggu terakhir, catatan liga). "Best streak" di
  Profile memakai aturan yang sama. 🔥 di kartu This week (mode Custom) dihapus.

### 7. Quick Workout (`b608f3b`)

- `Core/Domain/QuickWorkout.swift` (tes `QuickWorkoutTests`): `Kit` (gym, dumbbells, none, bands →
  peralatan yang boleh), `Focus` (full body, upper, legs, core → slot otot berurutan), jumlah latihan
  15/30/45/60 menit → 3/4/5/6. Tiap slot diisi satu latihan, compound dulu, tanpa duplikat;
  compound 3×10, isolasi 2×12, durasi 2 set. `shuffle` memilih kandidat lain per slot.
  `advancedKeys` (pistol squat, sissy squat, nordic curl) tidak ditawarkan.
- `AppEnvironment.quickWorkout(...)` mengurutkan latihan berdasar seberapa sering dipakai template
  bawaan (squat/bench/row dulu). `createdAt` tidak bisa dipakai untuk urutan seed (semua sama).
- Mulai: `StartRequest.quick([Item])` → `SessionRepository.start(name:items:)`, sesi tanpa template
  sehingga plan tidak bergeser; tetap dihitung untuk streak dan liga.
- UI: menu mode Home (My Plan / Custom / ⚡ Quick Workout) membuka `Features/Home/QuickWorkoutView.swift`
  (pill peralatan, durasi, fokus; daftar dengan foto; tombol acak; Start workout). `FilterPill` tidak
  terpilih sekarang bergaya kartu (putih 10% + border).
- UI test: item menu dicari dengan `label BEGINSWITH "Quick Workout"` karena label-nya ikut subtitle.

### 8. Mode Custom dan editor workout (24–25 Nov, RIV-66, RIV-67)

- **Kenapa:** Custom lama membuka layar "Start a workout" yang kartu utamanya rekomendasi dari plan,
  dan workout buatan sendiri tersebar di tiga tempat. Nama "My Workouts" sempat dicoba lalu
  dikembalikan ke **Custom** (terlalu mirip "My Plan").
- **Home Custom** (`HomeView.myWorkouts`): This week → (Resume workout) → **Your workouts** (workout
  sendiri yang berisi latihan, tombol ▶ langsung mulai, tap kartu = detail, tahan = Edit / Duplicate
  / Delete, "Manage" = `TemplatesView(showsPrograms: false)`) → Repeat last workout → **Create
  workout** (tombol primary, `Menu`: *Start from scratch* = editor kosong, *From a ready-made
  workout* = `TemplatesView(opensPrograms: true)`) → **Pick exercises** (secondary, picker lalu
  latihan mulai). Kosong: kartu "Build your first workout". Tidak ada rekomendasi plan di Custom.
- **Dihapus:** `StartWorkoutView` (layar "Start a workout"), `AppEnvironment.recommendedWorkout()`,
  `WorkoutStore.isStartScreenPresented`, `TemplateRepository.recentlyUsed`, kartu Quick start dan
  aset `QuickStartUpper/Lower`. Empty state History sekarang membawa ke Home.
- **Detail workout** (`TemplateDetailView`): workout sendiri punya **Edit**; template bawaan punya
  **Save as mine** (`templates.duplicate`, lalu editor).
- **Editor** (`TemplateEditorView` di `TemplatesView.swift`): layar yang di-push
  (`navigationDestination(item:)` dari Home, Templates, detail), bukan sheet. Back menyimpan
  (`onDisappear` → `templates.save()`); kanan atas **Reorder** / Done. `TemplateExerciseRow`: foto,
  nama, otot · alat, menu ⋯ (*Replace exercise* lewat `ExercisePickerView` satu pilihan →
  `TemplateRepository.replaceExercise`, sets/reps tetap, rest ikut latihan baru; *Remove*), dan
  tiga kotak `Menu` Sets / Reps / Rest. Saat Reorder baris jadi ringkas dan tanpa tombol hapus.
- `glassListRow()` sekarang punya margin samping 16 (juga dipakai sheet urutkan latihan saat sesi).
- PRD LOG-01 dan PLAN-05 sudah disesuaikan.

### Model data baru di `UserSettings` (langsung di V1, app belum pernah rilis)

`planStartedAt: Date?`, `homeModeRaw`, `daySwapsRaw`, `planID`. Semua punya default (aturan CloudKit).

## Belum dikerjakan (urutan yang disarankan)

1. **Merge PR #1** setelah Herdetya review (push dan PR sudah).
   - Usulan Custom yang belum dikerjakan: nama workout baru otomatis dari isinya atau kolom nama
     langsung aktif (sekarang "New workout" / "… Copy"); "Pick exercises" → "Start empty workout"
     dan **Save as workout** di ringkasan latihan.
   - Figma section 3 · Workout dan artifact "Custom Flow" masih memakai Custom lama.
2. Dari artifact yang sengaja dilewati: fase plan (Foundations/Build/Easy/Push, isi latihan belum
   berbeda per fase), baris Equipment dan "Rebuild plan" di layar Plan (belum ada data peralatan).
3. Sisa lama:
   - **2 foto latihan** perlu di-generate ulang: `bayesian_cable_curl` (membelakangi mesin kabel,
     satu tangan) dan `wrist_curl` (telapak ke atas). Pakai `scripts/exercise_photos/cutout.py`,
     detail di `docs/EXERCISE_PHOTOS.md`.
   - **TestFlight (sisa M3):** ikon app belum ada (`AppIcon.appiconset` kosong, Herdetya pilih
     "later"); app record di App Store Connect (bundle `app.rivalift.ios`);
     `ITSAppUsesNonExemptEncryption = NO`; deploy skema CloudKit `iCloud.app.rivalift.ios` ke
     Production. Akun developer berbayar, team `RXV32BBK97`.
   - Label salah ketik di Figma "All Exercises" (hanya Figma).
   - Kartu share setelah latihan; setelah M5: badge, rekap bulanan, peta otot, widget.
4. M4: proyek Supabase "rivalift" (organisasi "animos app"), login Apple + Google, sinkronisasi;
   lalu M5.

## Perangkat

- **Simulator:** iPhone 18 Pro `D8A495E6-E88B-41A3-A8DC-C511E5F99E7B`.
- **iPhone 17 Herdetya** `00008150-001534C03A01401C`: build 24 Nov pagi (sebelum Custom baru).
- **iPhone 15 Bahrur** `00008120-0011385C2663601E`: build 24 Nov `684d5fc` (Custom baru, tanpa
  editor baru), Developer Mode aktif. Yang tersambung kabel ke laptop.
- Pasang ke HP:
  ```sh
  xcodebuild -project Rivalift.xcodeproj -scheme Rivalift -destination 'id=<UDID>' \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build/device build
  xcrun devicectl device install app --device <UDID> build/device/Build/Products/Debug-iphoneos/Rivalift.app
  xcrun devicectl device process launch --device <UDID> app.rivalift.ios
  ```
- **iPhone Mirroring** bisa dilihat (bukan dikendalikan) dengan `screencapture -x -o -l <windowID>`.
  Computer use diblokir di level organisasi; Herdetya admin-nya (claude.ai → Organization settings →
  Capabilities → Computer use).

## Catatan teknis

- **Screenshot untuk cek visual:** buat UI test sementara `RivaliftUITests/TempShots.swift` yang
  onboarding lalu menyimpan `app.screenshot().pngRepresentation` ke folder scratchpad, jalankan
  dengan `-only-testing:RivaliftUITests/TempShots`, lalu hapus file-nya dan `xcodegen generate`.
  Tap manual di simulator sering tertunda.
- Satu run penuh `xcodebuild test` sekitar 6–7 menit (10 UI test). Jalankan di background dengan
  `grep --line-buffered` supaya hasil per test terlihat; jangan build lagi selama tes berjalan.
  Pernah ada run yang menggantung >10 menit: hentikan dan ulangi.
- Onboarding di UI test kadang gagal menemukan `nameField` kalau diketuk terlalu cepat; `sleep(2)`
  setelah `onboardingGetStarted` di test sementara membantu.
- UI test yang memanggil helper (`labelled`, `exerciseCard`) wajib `@MainActor`.
- UI test: pasang `accessibilityIdentifier` di tombolnya sendiri, bukan di wadah
  `.padding().background(Theme.bottomFade)`. Tutup keyboard (`typeText("…\n")`) sebelum mengetuk
  tombol di bawah. Identifier baru: `planCard`, `swapExercise`, `confirmSwap`, `editPlanButton`,
  `changePlanButton`, `startPlanWorkout`, `homeModeMenu`, `plan-<id>`, `startThisPlan`,
  `profileHistory`, `startPickExercises`, `createWorkoutButton`, `repeatLastWorkout`,
  `saveTemplateCopy`, `editTemplateButton`. Item `Menu` dicari lewat label-nya, mis.
  `app.buttons["From a ready-made workout"]`.
- Simulator: setelah `simctl launch` layar bisa hitam beberapa detik; tunggu sebelum mengetuk.
- CloudKit: semua atribut model wajib punya default atau optional; jangan pakai `.unique`.
- Figma: [Rivalift — iOS Screens](https://www.figma.com/design/UbndheXZjjzAloGIBkWKPp), node
  minimalis `695:29871`. `get_design_context` per node anak lebih hemat daripada seluruh layar.
  Page **"App flows · 24 Nov 2026"** (`860:2`): semua alur sebagai layer biasa (data contoh), satu
  section per alur (1 Onboarding … 9 Leagues) plus **10 · Custom · updated 26 Nov**. Section 3
  · Workout masih memakai Custom lama. Generatornya HTML → `html_to_figma` (skrip sementara di
  scratchpad, tidak di repo). Artifact "Custom Flow": https://claude.ai/artifact/KqqALriUD83VByiTB8EsDZ
  (versi 24 Nov, sebelum menu Create workout dan editor baru).

## Notion

Workspace Plainthing Studio, teamspace "Rivalift App". Database **Issues**
`collection://d7ed16ef-0624-4b38-88d8-74de0aab8e00` dan **Updates**
`collection://b005560f-90aa-4c71-8522-0bbcbd2476e8`. Aturan: setiap pekerjaan jadi issue,
setiap langkah selesai jadi update.

Sesi 23 Nov tercatat: **RIV-51 … RIV-57** (Done, kolom Commit terisi), **RIV-58 … RIV-62** (Todo:
streak, Quick Workout, Figtree, PRD, push + PR; RIV-58, RIV-59, RIV-62 Done, RIV-60 Figtree Canceled), dua entri Updates 23 Nov, baris M3 di tabel
milestone hub, dan open decision soal aturan rest week.

Sesi 24–25 Nov: **RIV-63, RIV-64** (jadwal dan detail plan), **RIV-65** (Figma semua alur),
**RIV-66** (judul plan, `dac39a5`), **RIV-67** (Custom dan editor workout, beberapa commit), semua
Done, dengan entri Updates per langkah.

**Akses:** konektor Notion di Claude masuk ke workspace pribadi, bukan Plainthing Studio. Pakai
REST API dengan token integration "Rivalift Claude" (workspace Plainthing Studio, akses ke hub
Rivalift) yang tersimpan di `~/.config/notion/rivalift_token` (izin 600, jangan ditampilkan).
Header `Notion-Version: 2025-09-03`, parent halaman baru `{"type": "data_source_id", ...}`.
Python bawaan python.org butuh `ssl.create_default_context(cafile="/etc/ssl/cert.pem")`.
Di zsh jangan pakai `path` sebagai nama variabel (itu PATH).
