# Battle regression check

Run with Godot 4 from the project folder (substitute the path to your Godot executable):

```powershell
$battleLog = Join-Path (Get-Location) '.godot\battle-tests.log'
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/battle_flow_test.gd --log-file $battleLog
```

Run the physical serve and gate regression separately:

```powershell
& 'C:\Users\icese\OneDrive\Documents\Godot.exe.exe' --headless --path . --script res://tests/pinball_physics_test.gd
```

This also checks both neutral side springs, that a fast bumper rebound stays inside the table, and that a drop target waits for the ball to leave before its wall returns.

If testing a fresh checkout, first open the project in Godot to import its assets and register the named scripts. Alternatively, run the same executable with `--headless --editor --path . --quit` before the test command.

The test exits with code 0 on success and code 1 if a check fails. It checks whole-turn scoring, attack order, duplicate events, zero-score turns, victory, defeat, cancellation of delayed attacks, and the real Main scene's menu signals, board gates, and HP/score displays.

The results are also saved to `.godot/battle-tests.log` if your Windows Godot executable does not keep its console output visible.

The scene test injects bumper contact notifications and a drain to keep results deterministic. It verifies the connected gameplay flow, not pinball trajectories or visual appearance. For a manual check, press Play, Ready, hold Space or Enter, release to launch, then use the arrow keys for the flippers. Confirm bumper hits raise the score, a drain damages the enemy first, the enemy attacks if alive, and the next ball is then served.

To see collision outlines while running from the Godot editor, enable **Debug > Visible Collision Shapes** before starting the game. For a command-line game launch, add `--debug-collisions`. This is a debug display option; the board's collision masks still switch normally for the ramps.
