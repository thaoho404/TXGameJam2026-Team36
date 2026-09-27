# Pinball and battle integration

The current playable slice is one battle with the Normal ball. Play opens the
gacha placeholder; Ready starts a fresh battle. Bumper contacts add points to the
current turn. A drain applies the full score to the enemy once. A surviving enemy
then deals its base damage. The board serves another ball after that exchange.
Victory and defeat stop the board; Try Again returns to Ready and Main Menu exits
the battle.

## Board interface

`scripts/physics/PinballController.gd` owns the physical board and exposes:

| Signal | Meaning |
| --- | --- |
| `ball_launched()` | The prepared ball was launched; begin the scoring turn. |
| `bumper_hit(element: BevoData.ElementType, points: int)` | One bumper contact during active play. Currently Normal, with 10 points by default. |
| `ball_drained()` | The active ball drained. Input and scoring are stopped before this signal is emitted. |

Combat calls `prepare_next_ball()` when another launch is allowed, and
`stop_board()` to disable launching and freeze the ball. Preparation is deferred
until physics callbacks are finished. Consumers should use the signals instead
of reading or changing the controller's internal board state.
Serving a ball synchronizes its physics body with the visible spawn position.
The one-way launch gate collides with both playfield and ramp collision modes,
so a returning ball cannot pass back into the launch lane.
The ball's exported maximum speed and the thicker hidden ceiling prevent a fast
bumper rebound from crossing the top edge. Drop targets wait for the ball to
leave their hitbox before restoring their solid wall.

`Plunger.gd` is the only script that charges and applies a launch impulse.
If a weak shot returns to the launch lane, the plunger allows another launch of
that same ball. The board emits `ball_launched()` only on the first launch, so
the current turn and its score continue. A held launch key must be released
before charging again after the ball returns.

`PinballController.gd` controls the flippers, scores bumper contacts, resets ramp
state on a new serve, and forwards launch/drain events. `BevoBall.gd` retains the
existing collision flash. New scoring objects can emit the same `bumper_hit`
contract when their points should count toward the current turn.
`LeftSpringBumper` and `RightSpringBumper` are neutral side springs. Their
`kick_strength` can be tuned in the Inspector, and their contacts do not emit
`bumper_hit` or award elemental points.

## Battle and display

`scripts/core/TurnManager.gd` owns score, HP, damage order, and battle outcomes.
It is a child of the `Main` scene, not an autoload. Its Inspector settings are
player/enemy maximum HP, enemy base damage, and the two attack display delays.
The table's Inspector exposes bumper points. HP is clamped at zero and overkill
does not increase `total_damage_dealt` beyond the enemy's remaining HP.

`scenes/ui/main.gd` connects the board signals to the manager, serves a new ball
on `turn_ready`, and updates both HP bars, HP labels, score, hit count, status,
and the retry button. Leaving the gameplay screen stops the board and cancels
delayed retaliation. Do not rely on hiding a Control to stop pinball physics.

## Follow-up systems

This slice does not yet implement ball inventory, multiple opponents, charge and
parry timing, real gacha rolls, elemental effects, currency, upgrades, or saving.
Those can be added to the battle/run layer without making the physical ball or
plunger decide combat outcomes.

## Validation

See `tests/README.md` for the headless battle regression checks. For a manual
smoke test, choose Play, Ready, hold Space or Enter, and release to launch. Left
and Right arrows control the flippers. Check that points increase on bumper
contacts, HP changes only after a drain, a defeated enemy never retaliates, and
the ball cannot launch during damage resolution or while a menu is open.
