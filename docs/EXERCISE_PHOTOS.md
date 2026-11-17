# Exercise photos

All 132 built-in exercises have their own photo in
`Rivalift/Resources/Assets.xcassets/Exercises/Exercise_<key>.imageset` (600×400 JPG, padded
to 3:2 on the photo's black background). Source: Figma "Rivalift — iOS Screens", frame
"All Exercises" (node 164:105933). `SeedDataTests.everyExerciseHasAPhoto` fails if one is missing.
Custom exercises fall back to a photo of the same muscle group (`ExerciseArt`).

Style: black background, red highlight on the worked muscles, landscape around 3:2.

## To regenerate

| Exercise | Key | Problem | Should show |
|---|---|---|---|
| Bayesian Cable Curl | `bayesian_cable_curl` | Same pose as Cable Curl | Facing away from the cable stack, one arm, upper arm slightly behind the torso |
| Wrist Curl | `wrist_curl` | Overhand grip, same as Reverse Wrist Curl | Palms up (underhand), forearms resting on the thighs |

To swap one, replace `photo.jpg` in its imageset; no code change is needed.
