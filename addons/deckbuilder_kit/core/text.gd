class_name DBText
extends RefCounted
## Every text Deckbuilder Kit shows to players goes through here, so it can be translated
## or reworded with Godot's translation system (template:
## [code]addons/deckbuilder_kit/translations/deckbuilder_kit.csv[/code]).

const BETTER := "#7ee081"
const WORSE := "#ff8a7a"

static var result_texts := {
	DBResult.Code.INVALID_ARGUMENT: "That did not work.",
	DBResult.Code.COMBAT_OVER: "The combat is over.",
	DBResult.Code.NOT_YOUR_TURN: "Wait for your turn.",
	DBResult.Code.NOT_IN_HAND: "That card is not in your hand.",
	DBResult.Code.NOT_ENOUGH_ENERGY: "Not enough energy.",
	DBResult.Code.UNPLAYABLE: "This card cannot be played.",
	DBResult.Code.INVALID_TARGET: "Choose an enemy.",
	DBResult.Code.NO_ITEM: "None left in the bag.",
}


static func t(text: String) -> String:
	if text.is_empty():
		return text
	return String(TranslationServer.translate(text))


static func result_message(result: DBResult) -> String:
	if result == null or result.ok:
		return ""
	if result.inventory_result != null and not result.inventory_result.player_text.is_empty():
		return IKText.result_message(result.inventory_result)
	return t(result_texts.get(result.code, "That did not work."))


static func type_name(type: DBCardData.Type) -> String:
	match type:
		DBCardData.Type.ATTACK:
			return t("Attack")
		DBCardData.Type.SKILL:
			return t("Skill")
		DBCardData.Type.POWER:
			return t("Power")
		DBCardData.Type.STATUS:
			return t("Status")
		DBCardData.Type.CURSE:
			return t("Curse")
	return ""


static func rarity_name(rarity: DBCardData.Rarity) -> String:
	match rarity:
		DBCardData.Rarity.STARTER:
			return t("Starter")
		DBCardData.Rarity.COMMON:
			return t("Common")
		DBCardData.Rarity.UNCOMMON:
			return t("Uncommon")
		DBCardData.Rarity.RARE:
			return t("Rare")
	return t("Special")


static func type_color(type: DBCardData.Type) -> Color:
	match type:
		DBCardData.Type.ATTACK:
			return Color(0.78, 0.32, 0.28)
		DBCardData.Type.SKILL:
			return Color(0.27, 0.52, 0.78)
		DBCardData.Type.POWER:
			return Color(0.85, 0.66, 0.25)
		DBCardData.Type.STATUS:
			return Color(0.45, 0.47, 0.52)
	return Color(0.48, 0.3, 0.62)


static func rarity_color(rarity: DBCardData.Rarity) -> Color:
	match rarity:
		DBCardData.Rarity.UNCOMMON:
			return Color(0.45, 0.75, 1.0)
		DBCardData.Rarity.RARE:
			return Color(1.0, 0.8, 0.3)
	return Color(0.78, 0.78, 0.8)


## The card text in BBCode. With a [param combat], damage and block show their live values
## (green when boosted, red when reduced), against [param target] once one is aimed.
static func describe_card(card: DBCard, combat: DBCombat = null, target: DBFighter = null) -> String:
	var data := card.data
	var lines := PackedStringArray()
	if card.is_innate():
		lines.append("[b]%s[/b]" % t("Innate"))
	if data.unplayable:
		lines.append("[b]%s[/b]" % t("Unplayable"))
	var written := data.upgraded_description if card.upgraded and not data.upgraded_description.is_empty() else data.description
	if not written.is_empty():
		var text := t(written)
		for i in data.effects.size():
			text = text.replace("{%d}" % i, _amount(card, i, combat, target))
		lines.append(text)
	else:
		for i in data.effects.size():
			var line := describe_effect(data.effects[i], _amount(card, i, combat, target))
			if not line.is_empty():
				lines.append(line)
	if card.is_retain():
		lines.append("[b]%s[/b]" % t("Retain"))
	if card.is_ethereal():
		lines.append("[b]%s[/b]" % t("Ethereal"))
	if card.is_exhaust():
		lines.append("[b]%s[/b]" % t("Exhaust"))
	return "\n".join(lines)


static func _amount(card: DBCard, index: int, combat: DBCombat, target: DBFighter) -> String:
	var base := card.get_amount(index)
	var live := combat.get_card_amount(card, index, target) if combat != null and combat.player != null else base
	var text := str(live)
	if live > base:
		return "[color=%s]%s[/color]" % [BETTER, text]
	if live < base:
		return "[color=%s]%s[/color]" % [WORSE, text]
	return text


## One sentence for an effect (from the player's point of view), [param amount] already
## formatted. Empty for CUSTOM effects: write the card's [member DBCardData.description].
static func describe_effect(effect: DBEffect, amount: String) -> String:
	var status_title := effect.status.get_title() if effect.status != null else ""
	match effect.kind:
		DBEffect.Kind.DAMAGE:
			var line := t("Deal %s damage") % amount
			if effect.hits > 1:
				line += t(" %d times") % effect.hits
			if effect.target == DBEffect.Target.ALL_OPPONENTS:
				line += t(" to ALL enemies")
			elif effect.target == DBEffect.Target.RANDOM_OPPONENT:
				line += t(" to a random enemy")
			return line + "."
		DBEffect.Kind.BLOCK:
			return t("Gain %s Block.") % amount
		DBEffect.Kind.DRAW:
			return (t("Draw %s card.") if amount == "1" else t("Draw %s cards.")) % amount
		DBEffect.Kind.ENERGY:
			return t("Gain %s energy.") % amount
		DBEffect.Kind.STATUS:
			match effect.target:
				DBEffect.Target.SELF, DBEffect.Target.ALL_ALLIES:
					return t("Gain %s %s.") % [amount, status_title]
				DBEffect.Target.ALL_OPPONENTS:
					return t("Apply %s %s to ALL enemies.") % [amount, status_title]
				DBEffect.Target.RANDOM_OPPONENT:
					return t("Apply %s %s to a random enemy.") % [amount, status_title]
			return t("Apply %s %s.") % [amount, status_title]
		DBEffect.Kind.HEAL:
			return t("Heal %s HP.") % amount
		DBEffect.Kind.LOSE_HP:
			return t("Lose %s HP.") % amount
		DBEffect.Kind.ADD_CARD:
			var title := effect.card.get_title() if effect.card != null else "?"
			var where := t("your hand") if effect.pile == DBEffect.Pile.HAND else (t("your draw pile") if effect.pile == DBEffect.Pile.DRAW else t("your discard pile"))
			return t("Add %s %s to %s.") % [amount, title, where]
		DBEffect.Kind.CLEANSE:
			if effect.status == null:
				return t("Remove your debuffs.")
			return t("Remove %s.") % status_title
	return ""


## Tooltip text of a status, built from its fields.
static func describe_status(status: DBStatus, stacks: int) -> String:
	var parts := PackedStringArray()
	var n := maxi(stacks, 1)
	if status.damage_bonus != 0:
		parts.append(t("Attacks deal %+d damage.") % (status.damage_bonus * n))
	if status.block_bonus != 0:
		parts.append(t("Block gains %+d.") % (status.block_bonus * n))
	if not is_equal_approx(status.damage_dealt_mult, 1.0):
		parts.append(t("Attacks deal %d%% damage.") % roundi(status.damage_dealt_mult * 100.0))
	if not is_equal_approx(status.damage_taken_mult, 1.0):
		parts.append(t("Takes %d%% damage from attacks.") % roundi(status.damage_taken_mult * 100.0))
	if not is_equal_approx(status.block_gain_mult, 1.0):
		parts.append(t("Gains %d%% block.") % roundi(status.block_gain_mult * 100.0))
	if status.damage_per_turn > 0:
		parts.append(t("Loses %d HP at the start of its turn.") % (status.damage_per_turn * n))
	elif status.damage_per_turn < 0:
		parts.append(t("Heals %d HP at the start of its turn.") % (-status.damage_per_turn * n))
	if status.block_per_turn > 0:
		parts.append(t("Gains %d Block at the end of its turn.") % (status.block_per_turn * n))
	if status.thorns > 0:
		parts.append(t("Attackers take %d damage.") % (status.thorns * n))
	if status.energy_per_turn != 0:
		parts.append(t("%+d energy each turn.") % (status.energy_per_turn * n))
	if status.draw_per_turn != 0:
		parts.append(t("%+d cards each turn.") % (status.draw_per_turn * n))
	if status.keeps_block:
		parts.append(t("Block is not removed at the start of its turn."))
	if status.decays:
		parts.append(t("Lasts %d turns.") % n if n > 1 else t("Lasts 1 turn."))
	return " ".join(parts)


## What an intent shows next to the icon: "12", "6×3", "" (no damage).
static func intent_label(preview: Dictionary) -> String:
	if preview.is_empty() or int(preview.get("hits", 0)) == 0:
		return ""
	if int(preview.hits) > 1:
		return "%d×%d" % [preview.damage, preview.hits]
	return str(preview.damage)


static func intent_kind_name(kind: DBIntent.Kind) -> String:
	match kind:
		DBIntent.Kind.ATTACK:
			return t("Attack")
		DBIntent.Kind.ATTACK_DEBUFF:
			return t("Attack and debuff")
		DBIntent.Kind.ATTACK_DEFEND:
			return t("Attack and defend")
		DBIntent.Kind.DEFEND:
			return t("Defend")
		DBIntent.Kind.BUFF:
			return t("Buff")
		DBIntent.Kind.DEBUFF:
			return t("Debuff")
	return t("Unknown")


## One combat log line for [param event] (see [DBCombat] for event types). Empty for events
## that need no line.
static func describe(event: Dictionary) -> String:
	var target: DBFighter = event.get("target")
	var who := target.get_title() if target != null else ""
	var source: DBFighter = event.get("source")
	var by := source.get_title() if source != null else ""
	match String(event.type):
		"turn":
			return t("Turn %d.") % event.turn
		"enemy_turn":
			return t("Enemy turn.")
		"play":
			var card: DBCard = event.card
			return t("You play %s.") % card.get_title()
		"item":
			return t("You use an item.")
		"relic":
			return t("%s takes effect.") % (event.relic as DBRelic).get_title()
		"intent":
			return t("%s: %s.") % [by, (event.intent as DBIntent).get_title()]
		"damage":
			if event.thorns:
				return t("%s takes %d damage from thorns.") % [who, event.hp_loss]
			if event.hp_loss == 0 and event.blocked > 0:
				return t("%s blocks %d damage.") % [who, event.blocked]
			if event.blocked > 0:
				return t("%s takes %d damage (%d blocked).") % [who, event.hp_loss, event.blocked]
			return t("%s takes %d damage.") % [who, event.hp_loss]
		"lose_hp":
			if event.status != null:
				return t("%s loses %d HP from %s.") % [who, event.amount, (event.status as DBStatus).get_title()]
			return t("%s loses %d HP.") % [who, event.amount]
		"heal":
			return t("%s recovers %d HP.") % [who, event.amount] if event.amount > 0 else ""
		"block":
			return t("%s gains %d Block.") % [who, event.amount] if event.amount > 0 else ""
		"status":
			var status: DBStatus = event.status
			if event.stacks > 0:
				return t("%s gains %d %s.") % [who, event.stacks, status.get_title()]
			if event.total == 0:
				return t("%s on %s wears off.") % [status.get_title(), who]
			return ""
		"shuffle":
			return t("Discard pile shuffled into the draw pile.")
		"burn":
			return t("Hand full: %s goes to the discard pile.") % (event.card as DBCard).get_title()
		"add_card":
			return t("%s added to your cards.") % (event.card as DBCard).get_title()
		"exhaust":
			return t("%s is exhausted.") % (event.card as DBCard).get_title()
		"defeated":
			return t("%s is defeated.") % who
		"victory":
			return t("Victory!")
		"defeat":
			return t("Defeat...")
	return ""
