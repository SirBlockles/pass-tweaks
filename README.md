# PASS Tweaks
PASS Tweaks is a plugin that makes a few gameplay changes to PASS Time to reduce unneeded complexity of some game mechanics and to reduce the effectiveness of solo running. This plugin is used by the PASS Time Federation in their competitive play.

## features
### hitscan anti-cheese
In vanilla PASS Time, the ball taking any damage at all while midair will reset it back to neutral. This lets pistol/SMG spam from scouts/engineers/snipers reset the ball and potentially neutralize it before a throw makes it into your goal. This plugins lets you configure this behavior - only damage above a certain threshold will actually interact with the ball. This prevents chip damage hitscan from pistols and SMGs from neutralizing the ball, but still lets high-power damage (snipers, explosives) knock it around.

### bonus goal/meter changes
PASS Tweaks can undo passes between teammates filling up the bonus meter, preventing two players from farming it to full and then throwing the ball into the most accessible goal on the entire fucking map for 3 points. The meter is still filled normally from "passes" (intercepts) between opposing teams. Additionally, stealing from enemies can be configured to contribute progress to the bonus meter. This lets the bonus meter still be earnable, but requires interacting with enemy players to do so.

### packmates: unchained
Vanilla PASS Time uses a mechanic called "the pack" to encourage teamplay, however it's very heavy-handed in its implementation and is the primary example of what was meant by "needless complexity." If the pack mechanic is enabled, then ALL of the following effects happen:
* All pack members move at the same speed as the fastest member of the pack - the way this is implemented also leads to a whipped/conched/otherwise speed-boosted scout making _everyone_ in the pack move at the speed of a whipped scout.
* All pack members besides the carrier regenerate 2 HP every second.
* The carrier is marked-for-death if there are no packmates nearby.

The internal naming of these vanilla features is also poorly communicated - the CVAR to enable or disable the pack system entirely is named `tf_passtime_pack_speed`, despite the fact that it controls much more than the speed-sharing system. _Set this to 0 if you want to disable the pack mechanic!_

PASS Tweaks provides alternatives for this system - firstly, a setting to disable the mark-for-death effect when solo-carrying. The icon is still visually shown on the player's HUD and above their head, but they don't actually take the extra mini-crits.

However, the primary "intended" design is to disable the pack mechanic entirely, and use a simpler replacement system: The ball carrier has a dispenser beam attached to them, with no mark-for-death or speed sharing included. The dispenser's heal rate can be configured via CVAR, and by default the dispenser dispenses ammo at the rate of a level 1. it also doesn't generate any metal to discourage engineers from hogging it, but this can be optionally enabled.

### round time and scoring
PASS Tweaks has a few settings to adjust the score value of normal and bonus goals. By default, if custom scoring is enabled, bonus goals are worth 2 points instead of 3. There are also some settings to adjust the starting time and max time of a single round, as well as time restored on capture. These settings aren't very revolutionary, and the code behind them is pending a cleanup and refactor anyway. There's not much to say here.

### misc stuff
There's a few small changes that don't really fit into their own category. The trail of the ball can be disabled, either entirely or only after its first pickup.

Pass, score, steal, and pickup events now have log outputs that can be read and interpreted by log parsers like [logs.tf](http://logs.tf).
## dependencies
[DHooks](https://github.com/peace-maker/DHooks2) - bundled with SourceMod since SM 1.11, but for 1.10 and earlier versions you'll need to download and install this separately. It's the same DHooks as required by TF2 Comp Fixes, so if you already have that installed, then you should be good to go.
## cvars & configuration
All settings that are toggles default to OFF, since this is intended to be used in competitive play, where configs will adjust each setting as needed. This means you'll need a server.cfg or equivalent to change these if you're running a pub server. For cvars that aren't toggles, the value in `[brackets]` is the default.

#### hit blocking

`sm_passtweaks_blockhit <0/1>` - enables hit blocking

`sm_passtweaks_blockhit_threshold [25]` - minimum damage required in a single hit before the ball actually responds to it. any hit that deals less damage than this amount will be ignored by the ball.

#### power meter
`sm_passtweaks_blockpassbonus <0/1>` - if enabled, prevents the bonus meter from filling from passes between teammates

`sm_passtweaks_powerball_steal <[0]-100>` - stealing the ball from an enemy will add this much to the power meter (each number is 1% - a value of 20 will add 20% to the meter)

#### pack/ball dispenser stuff

`sm_passtweaks_blockminicrit <0/1>` - if enabled, the mark-for-death will be cleared from solo carriers if the pack is enabled.

`sm_passtweaks_balldispenser <0/1>` - if enabled, the ball carrier will be a walking dispenser. uses the same dispenser entity from when a player has the most objectives in player destruction, and has such the same range.

`sm_passtweaks_balldispenser_healrate [5]` - heal rate, in HP/sec, of the ball dispenser. the default will probably be lowered to the standard 2/sec in the future.

`sm_passtweaks_balldispenser_metal <0/1>` - if enabled, the ball dispenser will generate metal. it is functionally the same as a level 1 dispenser - it generates 40 at a time, every 5 seconds, and has a reserve of 400 that can be pulled from by any engineer connected to it.

#### scoring & round time
`sm_passtweaks_custom_scoring <0/1>` - enables custom goal scoring

`sm_passtweaks_custom_scoring_base [1]` - points per goal for normal goals if custom scoring is enabled

`sm_passtweaks_custom_scoring_bonus [2]` - points per goal for bonus goals if custom scoring is enabled

`sm_passtweaks_custom_timer <0/1>` - enables custom round time handling

`sm_passtweaks_custom_timer_starttime [480]` - time, in seconds, the round starts with

`sm_passtweaks_custom_timer_maxtime [600]` - time, in seconds, the timer can max out at after time being added

`sm_passtweaks_custom_timer_goal [60]` - time, in seconds, to add to round time on a normal goal

`sm_passtweaks_custom_timer_goal_bonus [120]` - time, in seconds, to add to round time on a bonus goal

#### misc
`sm_passtweaks_removetrail <0/1/2>` - controls if, and when, the trail should be removed from the ball.

0\) the trail is not removed from the ball, ever

1\) the trail is removed as soon as the ball spawns

2\) the trail is removed after the ball is initially picked up, allowing the freshly-spawned ball to use its trail as a beacon while still not doing the same for players

## planned features
This plugin is one of those ones where i'll work on it for a week or two uninterrupted then leave it untouched for a few months. The next wave of changes I plan to tackle are:
* Alternate setting for hitscan-blocking that only filters bullet damage, so you can set it to a high number and block all hitscan without blocking explosives
* Run speed cap for ball carrier (ie scouts move at medic/spy speed while carrying ball)
* Better round time management code, including the ability to only add round time if the scoring team is losing or scores are even ([i've heard that one before...](https://github.com/SirBlockles/improved-CTF))
* Ability to disable bonus goals/meter entirely, and possibly have the power meter provide some other effect or buff as a substitute

## changelog
```
1.1 - updated gamedata offsets from game update, slightly cleaner DHooks calls

1.0 - initial version
```