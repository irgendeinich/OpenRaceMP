local state = {}

function clearState()
	state = {
		waypointTiming = {}
	}
end

clearState()

function triggerTrackLoadORM(sender_id, message)
	clearState()
	print("triggerTrackLoadORM")
	print(sender_id)
	print(message)
  print("json")
	local data = Util.JsonDecode(message)
	print(data)
	MP.TriggerClientEvent(-1, "openRaceMp.loadTrack", message)
end

function triggerStartRaceORM(sender_id, message)
	clearState()
	print("triggerStartRace")
	print(sender_id)
	print(sender_name)
	print(message)
	MP.TriggerClientEvent(-1, "openRaceMp.startRace", message)
end

function triggerWaypointORM(sender_id, message)
	print("triggerWaypoint")
	print(sender_id)
	print(sender_name)
	print(message)
	local data = Util.JsonDecode(message)
	local playerName = MP.GetPlayerName(sender_id)
	local waypointName = data.waypointName
	local time = data.time

	local existingTimings = state.waypointTiming[waypointName] or {}
	table.insert(existingTimings, {playerName = playerName, time = time})
	state.waypointTiming[waypointName] = existingTimings
	print(Util.JsonEncode(state.waypointTiming))
	MP.TriggerClientEvent(-1, "openRaceMp.waypointTiming", Util.JsonEncode(state.waypointTiming))
end

function prettyTime(seconds)
	local thousandths = seconds * 1000
	local min = math.floor((thousandths / (60 * 1000))) % 60
	local sec = math.floor(thousandths / 1000) % 60
	local ms = math.floor(thousandths % 1000)
	return string.format("%02d:%02d.%03d", min, sec, ms)
end

function triggerFinish(sender_id, message)
	print("triggerFinish")
	print(sender_id)
	print(sender_name)
	print(message)
	local data = Util.JsonDecode(message)
	local playerName = MP.GetPlayerName(sender_id)
	local time = data.time
	MP.SendChatMessage(-1, playerName .. " finished in " .. prettyTime(time))
end


MP.RegisterEvent("openRaceMp.triggerTrackLoad", "triggerTrackLoadORM")
MP.RegisterEvent("openRaceMp.triggerStartRace", "triggerStartRaceORM")
MP.RegisterEvent("openRaceMp.triggerWaypoint", "triggerWaypointORM")
MP.RegisterEvent("openRaceMp.triggerFinish", "triggerFinish")
