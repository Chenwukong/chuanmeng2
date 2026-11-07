extends RefCounted

const MULTIPLIERS := [1.0 / 3.0, 0.5, 1.0, 1.5, 2.0, 3.0]
const EFFECTS := ["下次攻击伤害 ÷3", "下次攻击伤害 ÷2", "下次攻击伤害不变", "下次攻击伤害 +50%", "下次攻击伤害 +100%", "下次攻击伤害 +200%"]

## 零气运六面等概率；气运越高，概率向高点数倾斜，低点数仍可能出现。
static func weights(luck: float) -> Array[float]:
	var power := 3.0 * maxf(luck, 0.0) / (100.0 + maxf(luck, 0.0))
	var result: Array[float] = []
	for face in range(1, 7): result.append(pow(float(face), power))
	return result

static func roll(luck: float, unit_roll: float = -1.0) -> int:
	var chances := weights(luck)
	var total := 0.0
	for weight in chances: total += weight
	var cursor := clampf(randf() if unit_roll < 0.0 else unit_roll, 0.0, 0.999999) * total
	for index in 6:
		cursor -= chances[index]
		if cursor < 0.0: return index + 1
	return 6
