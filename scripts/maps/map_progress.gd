extends RefCounted
## Puzzle-specific data only. The host owns save files and story progression.
const MAP_IDS = ["office_survey", "office_survey_shifted", "tide_reference_17", "tide_sheet", "composite", "tide_example"]
var acquired = [false, false, false]
var placed = [false, false, false]
var selected = -1
var rotation_step = 0
var anchor = 1
var north_step = 1
var reference_day = 16
var complete = false
var observed = []
var office_version = "office_survey"

func assembled() -> bool:
	return placed.all(func(p): return p == true)

func observe(id: String):
	if id in MAP_IDS and id not in observed: observed.append(id)

func set_office_version(id: String):
	if id not in ["office_survey", "office_survey_shifted"]: return
	observe(office_version)
	office_version = id

func acquire(index: int):
	if index >= 0 and index < 3: acquired[index] = true

func select_piece(index: int):
	if index >= 0 and index < 3 and acquired[index] and not placed[index]:
		if selected == index: return
		selected = index
		rotation_step = [2,1,3][index]

func place(slot: int) -> String:
	if selected < 0: return "Select a recovered fragment first."
	if slot != selected: return "That torn edge breaks the coastline. Try another board position."
	if rotation_step != 0: return "The contour turns away from the adjoining edge. Rotate this fragment."
	placed[slot] = true
	selected = -1
	if assembled():
		observe("tide_sheet")
		return "Sheet restored. Compare it with the reference; the interval is still unknown."
	return "The edges and printed contour meet. This fragment is seated."

func compare() -> String:
	if not assembled(): return "Restore the torn sheet before comparing it."
	if anchor != 0: return "The lighthouse registration crosses do not coincide."
	if north_step != 0: return "The north arrows disagree. Rotate the reference."
	if reference_day != 17: return "The dates differ. Both sheets must describe the same observation."
	complete = true
	observe("composite")
	return "The trace crosses interval 3. The composite and reading are preserved in your notebook."

func snapshot() -> Dictionary:
	return {"schema":1,"acquired":acquired.duplicate(),"placed":placed.duplicate(),"selected":selected,
		"rotation_step":rotation_step,"anchor":anchor,"north_step":north_step,"reference_day":reference_day,
		"complete":complete,"observed":observed.duplicate(),"office_version":office_version}

func restore(data):
	if not data is Dictionary or data.get("schema") != 1: return
	for key in ["acquired", "placed"]:
		var values = data.get(key)
		if values is Array and values.size() == 3:
			for i in range(3):
				if values[i] is bool: get(key)[i] = values[i]
	for i in range(3): placed[i] = placed[i] and acquired[i]
	for key in ["selected","rotation_step","anchor","north_step","reference_day"]:
		var value = data.get(key)
		if value is float or value is int: set(key,int(value))
	rotation_step = posmod(rotation_step,4)
	north_step = posmod(north_step,4)
	anchor = clampi(anchor,0,2)
	reference_day = 17 if reference_day == 17 else 16
	if selected < 0 or selected > 2 or not acquired[selected] or placed[selected]: selected = -1
	complete = data.get("complete") == true and assembled() and anchor == 0 and north_step == 0 and reference_day == 17
	var saved_observed = data.get("observed",[])
	if saved_observed is Array:
		for id in saved_observed:
			if id is String and id in MAP_IDS and id != "composite" and (id != "tide_sheet" or assembled()): observe(id)
	if assembled(): observe("tide_sheet")
	if complete: observe("composite")
	if data.get("office_version") in ["office_survey", "office_survey_shifted"]: office_version = data.office_version
