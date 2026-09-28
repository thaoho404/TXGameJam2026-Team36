# Battle regression check

Run with Godot 4 from the project folder (substitute the path to your Godot executable):

```powershell
$battleLog = Join-Path (Get-Location) '.godot\battle-tests.log'
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/battle_flow_test.gd --log-file $battleLog
```

Run the physical serve and gate regression separately:

```powershell
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/pinball_physics_test.gd
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/wheel_collision_test.gd
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/ceiling_regression_test.gd
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/launch_lane_recovery_test.gd
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/bottom_side_floor_test.gd
```

Run the elemental chart, ball resource, and run progression checks:

```powershell
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/element_data_test.gd
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/run_system_test.gd
```

The physical checks cover both neutral side springs, wheel side reflections and center-gap escape, high-speed rebounds against the roof on both collision layers, launch-lane stall recovery without consuming another ball, lower side guards with an open center drain, and a drop target waiting for the ball to leave before its wall returns.

If testing a fresh checkout, first open the project in Godot to import its assets and register the named scripts. Alternatively, run the same executable with `--headless --editor --path . --quit` before the test command.

The checks cover whole-turn scoring, attack order, duplicate events, zero-score turns, boss progression, inventory, upgrades, saved currency, chart parsing, status effects, and the real Main scene's menu signals, board gates, and HP/score displays. Read the final pass/fail line as well as the process exit code when using this Windows Godot build.

The results are also saved to `.godot/battle-tests.log` if your Windows Godot executable does not keep its console output visible.

The scene test injects bumper contact notifications and a drain to keep results deterministic. It verifies the connected gameplay flow, not pinball trajectories or visual appearance. For a manual check, press Play, choose New Game or Continue, inspect the rolled ball, then press Ready. Hold Space or Enter and release to launch; use the arrow keys for flippers and press P when an opponent charge appears to parry its bonus. Confirm bumper hits raise the score, a drain damages the enemy first, and the enemy attacks if alive.

To see collision outlines while running from the Godot editor, enable **Debug > Visible Collision Shapes** before starting the game. For a command-line game launch, add `--debug-collisions`. This is a debug display option; the board's collision masks still switch normally for the ramps.
