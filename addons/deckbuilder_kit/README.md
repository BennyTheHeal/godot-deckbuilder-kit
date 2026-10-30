# Deckbuilder Kit for Godot 4

Roguelike deckbuilder combat, ready to play: **energy** and a **hand** drawn every turn, **draw / discard / exhaust piles** that reshuffle by themselves, cards with **effects and keywords** (Exhaust, Ethereal, Retain, Innate, Unplayable), **upgrades**, enemies that **announce their intents** a turn ahead, **statuses in stacks** (Might, Weakened, Exposed, Poison, Thorns, Plating...), **relics**, **potions from your bag**, **card and gold rewards**, and a **finished combat screen** with drag-and-drop, aiming arrows, floating numbers and a reward picker, for the mouse, the keyboard and a gamepad.

**Pay what you want, from $0.** Code under MIT. Made by Benny, with AI tools. Official page, downloads and playable web demo: https://banc-essai.site-testeurs.workers.dev/deckbuilder-kit/
More kits, and our game prototypes waiting for testers: https://banc-essai.site-testeurs.workers.dev/

- **Cards as resources** (`DBCardData`): cost, type (Attack, Skill, Power, Status, Curse), rarity, a list of effects, keywords, and what upgrading changes (amounts, cost, keywords). Card text is written for you from the effects ("Deal 8 damage. Apply 2 Exposed."), or by you with `{0}`, `{1}` placeholders for the live numbers.
- **Effects** (`DBEffect`): damage (several hits, one enemy, all, random), block, draw, energy, statuses, heal, lose HP, add cards to a pile (wounds, dazes), cleanse, and `CUSTOM` effects your game handles through a signal.
- **Statuses** (`DBStatus`): counted in stacks, set up with fields instead of code: +damage or +block per stack, damage dealt / taken / block gained multipliers, damage per turn (poison), block per turn (plating), thorns, extra energy or cards per turn, block that stays, stacks that wear off one per turn.
- **Enemies** (`DBEnemyData`, `DBIntent`): intents in a cycle or weighted random (never twice in a row if you like), starting statuses, gold, elites. The screen shows the intent icon and the real damage, Weakened and Exposed included.
- **Relics** (`DBRelic`): effects on start of combat, start or end of turn, every Nth card of a type, end of combat.
- **Rules that hold**: refusals instead of errors (`NOT_ENOUGH_ENERGY`, `INVALID_TARGET`, `UNPLAYABLE`...), a 10-card hand limit, Innate cards always in the opening hand, combats on copies of the deck (the deck never changes by accident), the player's HP carried from fight to fight, same seed, same combat.
- **Plugs into Inventory Kit**: potions and bombs from the bag are used in combat (`item_cards`), gold rewards go into the bag, and every icon comes from the 120 Inventory Kit items in 4 art styles (or your own textures).
- **DBCombatView**: enemies, player, the hand in a fan, energy, piles you can open, items, relics, log, card reward screen. It feels alive without new art: cards fly from the draw pile and to the discard pile, attackers lunge, hits flash and shake the screen, numbers pop.
- Saving: `deck.to_save()` / `load_save()`, `player.to_save()`. Translatable texts, 45 automated tests, pure GDScript.

## Install

1. Copy `addons/inventory_kit/` and `addons/deckbuilder_kit/` into your project's `addons/` folder (skip Inventory Kit if you already have it).
2. Open `demo/cards/cards_demo.tscn`: "The Crystal Mine", a short run with two fights, a camp, an elite, a merchant and a boss, 30 cards and 5 relics.

## Five-minute setup

```gdscript
var exposed := DBStatus.make(&"exposed", "Exposed", true, true, &"clay")  # debuff, wears off
exposed.damage_taken_mult = 1.5

var strike := DBCardData.make(&"strike", "Strike", 1, DBCardData.Type.ATTACK, [DBEffect.damage(6, 3)], &"sword")
var guard := DBCardData.make(&"guard", "Guard", 1, DBCardData.Type.SKILL, [DBEffect.block(5, 3)], &"shield")
var bash := DBCardData.make(&"bash", "Bash", 2, DBCardData.Type.ATTACK,
	[DBEffect.damage(8, 2), DBEffect.apply(exposed, 2)], &"mace")

var slime := DBEnemyData.make(&"slime", "Slime", 30, [
	DBIntent.make(&"tackle", "Tackle", [DBEffect.damage(7)]),
	DBIntent.make(&"harden", "Harden", [DBEffect.block(6)]),
], &"clay")

var deck := DBDeck.from_cards([strike, strike, strike, strike, guard, guard, guard, guard, bash])
var player := DBFighter.make_player("Hero", 70, &"iron_helmet")

var combat := DBCombat.new()
combat.library = my_card_library               # card rewards come from here
combat.bag = bag.container                     # potions come from here, gold goes there
combat.item_cards = {&"health_potion": DBCardData.make(&"potion", "Potion", 0, DBCardData.Type.SKILL,
	[DBEffect.make(DBEffect.Kind.HEAL, 15, DBEffect.Target.SELF)])}
add_child(combat)

var view := DBCombatView.new()                 # the whole combat screen
view.combat = combat
view.finished.connect(func(outcome, picked_card): if picked_card: deck.add(picked_card))
add_child(view)

combat.start(deck, player, [slime, slime])
```

Without the view, drive it yourself: `combat.play_card(card, enemy)`, `combat.use_item(&"health_potion")`, `combat.end_turn()`. Each returns a `DBResult` whose `events` list what happened ("draw", "damage", "block", "status", "intent", "defeated"...), in order.

Custom effects:

```gdscript
var catalyst := DBCardData.make(&"catalyst", "Catalyst", 1, DBCardData.Type.SKILL, [DBEffect.custom(&"double_poison")])
catalyst.description = "Double the enemy's Poison."
combat.custom_effect.connect(func(effect, source, targets, card, events):
	if effect.custom_id == &"double_poison":
		for target in targets:
			target.add_status(poison, target.get_stacks(&"poison")))
```

## Classes

| Class | Role |
|---|---|
| `DBCardData`, `DBEffect`, `DBStatus`, `DBEnemyData`, `DBIntent`, `DBRelic` | Cards, effects, statuses, enemies, intents and relics as resources |
| `DBCardLibrary` | Every card by id: rebuilds saved decks, `offer(3, rng)` draws reward cards weighted by rarity |
| `DBCard`, `DBDeck` | A card instance (upgraded or not) and the player's deck: add, remove, upgrade, sort, save |
| `DBFighter` | The player or an enemy in combat: HP, block, statuses, intent |
| `DBCombat` | Turns, piles, energy, `play_card()`, `use_item()`, `end_turn()`, previews (`get_card_amount()`, `preview_intent()`), rewards; signals `turn_started`, `card_played`, `custom_effect`, `combat_ended`... |
| `DBResult`, `DBText` | Outcome codes and events, player texts and log lines |
| `DBCombatView`, `DBCardView`, `DBFighterView`, `DBCardPicker` | The combat screen, a card, a fighter, a card list to look at or pick from |

## Turn order

Start of the player's turn: block is removed (unless a status keeps it), damage per turn ticks, energy refills, TURN_START relics act, then 5 cards are drawn (the hand holds 10; extra cards go to the discard pile). End of turn: TURN_END relics, block per turn, decaying statuses lose a stack, the hand is discarded (Retain stays, Ethereal is exhausted). Then each enemy in turn: block removed, damage per turn, its intent, block per turn, decay, next intent.

Damage of one hit: `(amount + Might) × Weakened × Exposed`, rounded down, then absorbed by block. Block gained: `(amount + Agility) × Fragile`, rounded down.

## Running the tests

```bash
godot --headless --path <project> --import
godot --headless --path <project> -s res://tests/deckbuilder_kit/run_tests.gd
```

## Licenses

- Source code: MIT (`LICENSE.txt`).
- The item art in `addons/inventory_kit/art/` is covered by Inventory Kit's `LICENSE_ART.txt`: free to use in your games, please do not re-upload it; link to the official page instead.
- Found a bug or want a feature? Tell us: https://banc-essai.site-testeurs.workers.dev/
