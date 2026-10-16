# Exercise photos to make

Photos Rivalift still needs. 18 of 132 exercises already have one (from Figma); the rest use a photo of the same muscle group until theirs exists.

Style: same as the existing ones in `Rivalift/Resources/Assets.xcassets/Exercises/` (black background, red highlight on the worked muscles, landscape around 3:2).

Drop each file in as `Exercise_<key>.imageset` and add the key to `ExerciseArt.photos` in `Rivalift/Core/DesignSystem/Components.swift`.

## Priority: used in the built-in programs (19)

### Back

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Barbell Row | `barbell_row` | Barbell | Back | Biceps, Traps |
| Lat Pulldown | `lat_pulldown` | Cable | Back | Biceps |
| Seated Cable Row | `seated_cable_row` | Cable | Back | Biceps |

### Shoulders

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Dumbbell Lateral Raise | `dumbbell_lateral_raise` | Dumbbell | Shoulders | — |
| Face Pull | `face_pull` | Cable | Shoulders | Traps |
| Overhead Press | `overhead_press` | Barbell | Shoulders | Triceps |

### Biceps

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Dumbbell Bicep Curl | `dumbbell_bicep_curl` | Dumbbell | Biceps | Forearms |
| Hammer Curl | `hammer_curl` | Dumbbell | Biceps | Forearms |

### Triceps

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Overhead Cable Triceps Extension | `overhead_cable_triceps_extension` | Cable | Triceps | — |
| Overhead Dumbbell Triceps Extension | `overhead_dumbbell_triceps_extension` | Dumbbell | Triceps | — |
| Rope Pushdown | `rope_pushdown` | Cable | Triceps | — |
| Triceps Pushdown | `triceps_pushdown` | Cable | Triceps | — |

### Quads

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Bulgarian Split Squat | `bulgarian_split_squat` | Dumbbell | Quads | Glutes |
| Dumbbell Lunge | `dumbbell_lunge` | Dumbbell | Quads | Glutes, Hamstrings |
| Front Squat | `front_squat` | Barbell | Quads | Glutes, Core |
| Leg Extension | `leg_extension` | Machine | Quads | — |

### Hamstrings

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Seated Leg Curl | `seated_leg_curl` | Machine | Hamstrings | — |

### Calves

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Seated Calf Raise | `seated_calf_raise` | Machine | Calves | — |

### Core

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Plank | `plank` | Bodyweight | Core | — |

## Rest of the library (95)

### Chest

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Cable Crossover | `cable_crossover` | Cable | Chest | — |
| Chest Dip | `chest_dip` | Bodyweight | Chest | Triceps, Shoulders |
| Decline Barbell Bench Press | `decline_barbell_bench_press` | Barbell | Chest | Triceps |
| Decline Dumbbell Press | `decline_dumbbell_press` | Dumbbell | Chest | Triceps |
| Dumbbell Bench Press | `dumbbell_bench_press` | Dumbbell | Chest | Triceps, Shoulders |
| Dumbbell Fly | `dumbbell_fly` | Dumbbell | Chest | — |
| Incline Barbell Bench Press | `incline_barbell_bench_press` | Barbell | Chest | Shoulders, Triceps |
| Incline Dumbbell Fly | `incline_dumbbell_fly` | Dumbbell | Chest | Shoulders |
| Incline Push-Up | `incline_push_up` | Bodyweight | Chest | Triceps |
| Low-to-High Cable Fly | `low_to_high_cable_fly` | Cable | Chest | Shoulders |
| Machine Chest Press | `machine_chest_press` | Machine | Chest | Triceps |
| Pec Deck | `pec_deck` | Machine | Chest | — |
| Push-Up | `push_up` | Bodyweight | Chest | Triceps, Shoulders |
| Smith Machine Bench Press | `smith_machine_bench_press` | Machine | Chest | Triceps |

### Back

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Chest-Supported Dumbbell Row | `chest_supported_dumbbell_row` | Dumbbell | Back | Biceps |
| Chin-Up | `chin_up` | Bodyweight | Back | Biceps |
| Close-Grip Lat Pulldown | `close_grip_lat_pulldown` | Cable | Back | Biceps |
| Dumbbell Row | `dumbbell_row` | Dumbbell | Back | Biceps |
| Inverted Row | `inverted_row` | Bodyweight | Back | Biceps |
| Machine Row | `machine_row` | Machine | Back | Biceps |
| Pendlay Row | `pendlay_row` | Barbell | Back | Biceps |
| Rack Pull | `rack_pull` | Barbell | Back | Traps, Glutes |
| Straight-Arm Pulldown | `straight_arm_pulldown` | Cable | Back | — |
| T-Bar Row | `t_bar_row` | Barbell | Back | Biceps |

### Shoulders

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Cable Lateral Raise | `cable_lateral_raise` | Cable | Shoulders | — |
| Dumbbell Front Raise | `dumbbell_front_raise` | Dumbbell | Shoulders | — |
| Kettlebell Press | `kettlebell_press` | Kettlebell | Shoulders | Triceps |
| Machine Lateral Raise | `machine_lateral_raise` | Machine | Shoulders | — |
| Machine Shoulder Press | `machine_shoulder_press` | Machine | Shoulders | Triceps |
| Push Press | `push_press` | Barbell | Shoulders | Triceps, Quads |
| Reverse Dumbbell Fly | `reverse_dumbbell_fly` | Dumbbell | Shoulders | Back |
| Reverse Pec Deck | `reverse_pec_deck` | Machine | Shoulders | Back |
| Upright Row | `upright_row` | Barbell | Shoulders | Traps |

### Traps

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Barbell Shrug | `barbell_shrug` | Barbell | Traps | — |
| Dumbbell Shrug | `dumbbell_shrug` | Dumbbell | Traps | — |

### Biceps

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Bayesian Cable Curl | `bayesian_cable_curl` | Cable | Biceps | — |
| Cable Curl | `cable_curl` | Cable | Biceps | — |
| Concentration Curl | `concentration_curl` | Dumbbell | Biceps | — |
| EZ-Bar Curl | `ez_bar_curl` | Barbell | Biceps | Forearms |
| Incline Dumbbell Curl | `incline_dumbbell_curl` | Dumbbell | Biceps | — |
| Preacher Curl | `preacher_curl` | Machine | Biceps | — |

### Triceps

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Bench Dip | `bench_dip` | Bodyweight | Triceps | — |
| Close-Grip Bench Press | `close_grip_bench_press` | Barbell | Triceps | Chest, Shoulders |
| Diamond Push-Up | `diamond_push_up` | Bodyweight | Triceps | Chest |
| Dumbbell Kickback | `dumbbell_kickback` | Dumbbell | Triceps | — |
| Machine Triceps Extension | `machine_triceps_extension` | Machine | Triceps | — |
| Skull Crusher | `skull_crusher` | Barbell | Triceps | — |
| Triceps Dip | `triceps_dip` | Bodyweight | Triceps | Chest, Shoulders |

### Forearms

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Dead Hang | `dead_hang` | Bodyweight | Forearms | Back |
| Farmer's Carry | `farmers_carry` | Dumbbell | Forearms | Traps, Core |
| Reverse Barbell Curl | `reverse_barbell_curl` | Barbell | Forearms | Biceps |
| Reverse Wrist Curl | `reverse_wrist_curl` | Dumbbell | Forearms | — |
| Wrist Curl | `wrist_curl` | Dumbbell | Forearms | — |

### Quads

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Barbell Lunge | `barbell_lunge` | Barbell | Quads | Glutes |
| Bodyweight Squat | `bodyweight_squat` | Bodyweight | Quads | Glutes |
| Goblet Squat | `goblet_squat` | Dumbbell | Quads | Glutes |
| Hack Squat | `hack_squat` | Machine | Quads | Glutes |
| Hip Adduction Machine | `hip_adduction_machine` | Machine | Quads | — |
| Kettlebell Goblet Squat | `kettlebell_goblet_squat` | Kettlebell | Quads | Glutes |
| Pistol Squat | `pistol_squat` | Bodyweight | Quads | Glutes, Core |
| Sissy Squat | `sissy_squat` | Bodyweight | Quads | — |
| Smith Machine Squat | `smith_machine_squat` | Machine | Quads | Glutes |
| Step-Up | `step_up` | Dumbbell | Quads | Glutes |
| Trap Bar Deadlift | `trap_bar_deadlift` | Barbell | Quads | Glutes, Hamstrings, Back |
| Walking Lunge | `walking_lunge` | Dumbbell | Quads | Glutes |
| Wall Sit | `wall_sit` | Bodyweight | Quads | — |

### Hamstrings

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Dumbbell Romanian Deadlift | `dumbbell_romanian_deadlift` | Dumbbell | Hamstrings | Glutes |
| Good Morning | `good_morning` | Barbell | Hamstrings | Back, Glutes |
| Nordic Hamstring Curl | `nordic_hamstring_curl` | Bodyweight | Hamstrings | — |
| Stiff-Leg Deadlift | `stiff_leg_deadlift` | Barbell | Hamstrings | Glutes, Back |
| Sumo Deadlift | `sumo_deadlift` | Barbell | Hamstrings | Glutes, Quads, Back |

### Glutes

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Cable Kickback | `cable_kickback` | Cable | Glutes | — |
| Cable Pull-Through | `cable_pull_through` | Cable | Glutes | Hamstrings |
| Glute Bridge | `glute_bridge` | Bodyweight | Glutes | Hamstrings |
| Hip Abduction Machine | `hip_abduction_machine` | Machine | Glutes | — |
| Kettlebell Swing | `kettlebell_swing` | Kettlebell | Glutes | Hamstrings, Back |

### Calves

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Dumbbell Calf Raise | `dumbbell_calf_raise` | Dumbbell | Calves | — |
| Leg Press Calf Raise | `leg_press_calf_raise` | Machine | Calves | — |

### Core

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Cable Crunch | `cable_crunch` | Cable | Core | — |
| Crunch | `crunch` | Bodyweight | Core | — |
| Dead Bug | `dead_bug` | Bodyweight | Core | — |
| Hanging Knee Raise | `hanging_knee_raise` | Bodyweight | Core | — |
| Hanging Leg Raise | `hanging_leg_raise` | Bodyweight | Core | — |
| Hollow Body Hold | `hollow_body_hold` | Bodyweight | Core | — |
| Lying Leg Raise | `lying_leg_raise` | Bodyweight | Core | — |
| Mountain Climber | `mountain_climber` | Bodyweight | Core | Shoulders |
| Pallof Press | `pallof_press` | Cable | Core | — |
| Russian Twist | `russian_twist` | Bodyweight | Core | — |
| Side Plank | `side_plank` | Bodyweight | Core | — |

### Full body

| Exercise | Key | Equipment | Primary | Secondary |
|---|---|---|---|---|
| Burpee | `burpee` | Bodyweight | Full body | Chest, Quads |
| Clean and Jerk | `clean_and_jerk` | Barbell | Full body | Shoulders, Quads |
| Kettlebell Turkish Get-Up | `kettlebell_turkish_get_up` | Kettlebell | Full body | Shoulders, Core |
| Power Clean | `power_clean` | Barbell | Full body | Quads, Traps, Back |
| Snatch | `snatch` | Barbell | Full body | Shoulders, Quads |
| Thruster | `thruster` | Barbell | Full body | Quads, Shoulders |
