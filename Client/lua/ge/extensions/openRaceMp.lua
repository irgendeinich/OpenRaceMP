
local raceMarker = require("scenario/race_marker")
local logTag = "openRaceMp"
local M = {}
M.state = {
  scenario = nil,
  waypointTiming = {},
  playerName = 'thePlayer'
}

local function clearState()
  M.state.scenario = nil
  M.state.waypointTiming = {}
  if MPConfig then
    log('D', logTag, 'Setting player name to: ' .. MPConfig.getNickname())
    M.state.playerName = MPConfig.getNickname()
  end
end

local autoPrefabs = {
  prefabs = '',
  reversePrefabs = '_reverse',
  forwardPrefabs = '_forward'
}
local prefabExt = {'.prefab', '.prefab.json'}



local function freezeAll(scenario, state)
  if not scenario then
    log('D', logTag, 'Freeze all did not find a scenario....')
    return
  end

  if scenario.vehicleNameToId then
    for k, vid in pairs(scenario.vehicleNameToId) do
      local bo = be:getObjectByID(vid)
      if bo then
        bo:queueLuaCommand('controller.setFreeze('..tostring(state) ..')')
      end
    end
  else
    log('W', logTag, 'There are no vehicles to freeze.')
  end
end

local function processRaceStart()
  local scenario = M.state.scenario
  scenario.failureTimer = 0.0
  scenario.failureTimerActive = true

  extensions.hook('onRaceStartORM')
  guihooks.trigger('RaceStart')
end

local function tickRunning(dt, dtSim)
  local scenario = M.state.scenario
  -- countdown state
  if scenario.countDownTime and scenario.raceState == 'countdown' then
    scenario.countDownTime = scenario.countDownTime - dtSim
    if scenario.countDownTime <= 3 and not scenario.countDownShowed and scenario.showCountdown then
      -- tell the UI to actually count down
      guihooks.trigger('ScenarioFlashMessageReset')
      guihooks.trigger('ScenarioFlashMessage', {{3,1, "Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown1')", true},
                                                {2,1, "Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown2')", true},
                                                {1,1, "Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown3')", true}})

      scenario.countDownShowed = true
      extensions.hook("onCountdownStartedORM")
    elseif scenario.countDownTime < 1 and not scenario.countDownShowed and not scenario.showCountdown then
      guihooks.trigger('ScenarioFlashMessageReset')
      guihooks.trigger('ScenarioFlashMessage', {{'ui.scenarios.ready',1, "", true}})
      scenario.countDownShowed = true
    elseif scenario.countDownTime <= 0 then
      guihooks.trigger('ScenarioFlashMessageReset')
      guihooks.trigger('ScenarioFlashMessage', {{"ui.scenarios.go", 1, "Engine.Audio.playOnce('AudioGui', 'event:UI_CountdownGo')", true}})

      scenario.countDownTime = nil
      scenario.countDownShowed = nil

      scenario.raceState = 'racing'

      -- unlock all vehicles
      freezeAll(scenario, 0)

      -- reset the timers
      scenario.timer = 0

      extensions.hook("onCountdownEndedORM")

      -- let everyone know that we finally started
      -- but only if we have no rolling start
      processRaceStart()
    end
    return
  end

  if be:getEnabled() then
    if scenario.raceState == 'racing' and scenario.timerActive and not simTimeAuthority.getPause() then
      scenario.timer = scenario.timer + dtSim
      guihooks.trigger('openRaceMp.raceTime', {time=scenario.timer})
    end
  end
end

local function split(s, sep)
  local fields = {}
  
  local sep = sep or " "
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
  
  return fields
end

local function processWaypointsInScene(scenario)
  -- we are figuring out the waypoints and build the node graph with the positions of the level
  -- first step: complete the node graph with the spawned waypoints
  scenario.nodes = {}
  for k, nodeName in ipairs(scenetree.findClassObjects('BeamNGWaypoint')) do
    --log('D', logTag, tostring(k) .. ' = ' .. tostring(nodeName))
    local o = scenetree.findObject(nodeName)
    if o then
      if scenario.nodes[nodeName] == nil then
        local rota = nil
        if o:getField('directionalWaypoint',0) == '1' then
           rota = quat(o:getRotation())*vec3(1,0,0)
        end

        scenario.nodes[nodeName] = {
          pos = vec3(o:getPosition()),
          radius = getSceneWaypointRadius(o),
          rot = rota
        }

      end
    else
      log('E', logTag, 'waypoint not found: ' .. tostring(nodeName))
    end
  end

  --reset map to make sure waypoints from the prefab are also considered
  map.load()

  -- second step: try to find the waypoint in the AI graph
  local mapData = map.getMap()

  if mapData and scenario.lapConfig then
    local aiRadFac = (scenario.radiusMultiplierAI or 1)
    for _, wp in ipairs(scenario.lapConfig) do
      if wp:sub(1,12) ~= '__generated_' then -- only process non-generated WPs
        if scenario.nodes[wp] == nil then
          if mapData.nodes[wp] ~= nil then
            scenario.nodes[wp] = deepcopy(mapData.nodes[wp])
            scenario.nodes[wp].radius = scenario.nodes[wp].radius * aiRadFac
            scenario.nodes[wp].pos = vec3(scenario.nodes[wp].pos)
            scenario.nodes[wp].rot = vec3(scenario.nodes[wp].rot)
          else
            log('E', logTag, 'unable to find waypoint: ' .. dumps(wp))
          end
        end
      end
    end
  else
    log('W', logTag, 'no ai graph for this map found')
  end
  return scenario
end

local function setupLapConfig(scenario, infoJson)
  scenario.lapConfig = infoJson.lapConfig
  scenario.lapConfig[#scenario.lapConfig+1] = infoJson.finishLineCheckpoint

  -- process lapConfig
  scenario.BranchLapConfig = scenario.lapConfig
  scenario.lapConfig = {}
  for i, v in ipairs(scenario.BranchLapConfig) do
    if type(v) == 'string' then
      table.insert(scenario.lapConfig, v)
    end
  end
  scenario.initialLapConfig = deepcopy(scenario.lapConfig)
  return scenario
end

local function spawnPrefabs(scenario)

  local vid = be:getPlayerVehicleID(0)

  for i, filename in ipairs(scenario.prefabs) do
    if FS:fileExists(filename) then
      local _, objNameNew, _ = path.splitWithoutExt(filename, ".prefab.json")
      local _, objNameOld, _ = path.splitWithoutExt(filename, ".prefab")
      local objName = string.lower(objNameNew or objNameOld)
      if not scenetree.findObject(objName) then
        local prefabObj = spawnPrefab(objName, filename, '0 0 0', '0 0 1 0', '1 1 1')
        scenetree.ScenarioObjectsGroup:addObject(prefabObj.obj)
      else
        log('E', logTag, 'Prefab: '..objName..' already exist in level. Rejecting loading of duplicate.')
      end
    end
  end

  local vehicles = scenetree.findClassObjects('BeamNGVehicle')
  for k, vecName in ipairs(vehicles) do
    local to = scenetree.findObject(vecName)
    if to and to.obj and to.obj:getId() and prefabIsChildOfGroup(to.obj, 'ScenarioObjectsGroup') then
      to = Sim.upcast(to)
      to:delete()
    end
  end

  local veh = be:getObjectByID(vid)
  be:enterVehicle(0, veh)

  -- Fixes prefabs not having collision.
  be:physicsStartSimulation()
end

local function parseQuickRace(quickRaceName)
 
  local scenario = {}
  -- split the name into parts
  local levelDir, filename, ext = path.split(quickRaceName)
  scenario.trackName = filename

  if(scenetree.OpenRaceMpGroup) then scenetree.OpenRaceMpGroup:delete() end
  if(scenetree.ScenarioObjectsGroup) then scenetree.ScenarioObjectsGroup:delete() end

  local MissionGroup = scenetree.MissionGroup
  local ScenarioObjectsGroup = createObject('SimGroup')
  ScenarioObjectsGroup:registerObject('ScenarioObjectsGroup')
  ScenarioObjectsGroup.canSave = false
  MissionGroup:addObject(ScenarioObjectsGroup.obj)

  local parts = split(filename, ".")
  local trackName = parts[1]

  local infoJsonFile = levelDir..trackName..".json"
  local infoJson = jsonReadFile(quickRaceName)

  scenario.prefabs = infoJson.prefabs or {}

  local trackFile = {
    prefabs = {},
    reversePrefabs = {},
    forwardPrefabs = {}
  }

  for list, suf in pairs(autoPrefabs) do
    for _, ext in ipairs(prefabExt) do
      local file = levelDir..trackName..suf..ext
      if FS:fileExists(file) then
        table.insert(trackFile[list], file)
      end
    end
  end

  for _,p in ipairs(trackFile.prefabs) do
    scenario.prefabs[#scenario.prefabs+1] = p
  end
  -- TODO Support Reverse Config
  for _,p in ipairs(trackFile.forwardPrefabs) do
    scenario.prefabs[#scenario.prefabs+1] = p
  end

  local vid = be:getPlayerVehicleID(0)
  local veh = be:getObjectByID(vid)
  scenario.vehicleNameToId = {}
  scenario.vehicleIdToName = {}
  scenario.vehicleNameToId[veh] = vid
  scenario.vehicleIdToName[vid] = veh

  -- TODO: Make this configurable
  scenario.lapCount = 1

  scenario = setupLapConfig(scenario, infoJson)
  local vid = be:getPlayerVehicleID(0)
  local veh = be:getObjectByID(vid)
  spawnPrefabs(scenario)
  scenario = processWaypointsInScene(scenario)
  openRaceMpWayPoints.initialise(scenario)
  M.state.scenario = scenario
end

local function loadTrack(msg)
  clearState()
  local data = jsonDecode(msg)
  log('D', logTag, 'Loading track: ' .. data.trackName)
  be:setDynamicCollisionEnabled(true)
  openRaceMpWayPoints.onScenarioChange()

  parseQuickRace(data.quickRaceName)
end

local function getTrackList()
  local missionFile = getMissionFilename()
  local levelDir, filename, ext = path.split(missionFile)
  local quickRaceDir = levelDir.."quickrace"
  local filenames = FS:findFiles(quickRaceDir, "*.json", -1, true, false)
  local trackNames = {}
  for i, quickRaceName in ipairs(filenames) do
    -- Skip files that contain the word prefab
    if not string.find(quickRaceName, "prefab") then
      local _, trackName, _ = path.split(quickRaceName)
      table.insert(trackNames, {path=quickRaceName, name=trackName})
    end
  end
  return trackNames
end

local function remoteTriggerLoadTrack(quickRaceName)
  local _, trackName, _ = path.split(quickRaceName)

  if TriggerServerEvent then
    log('D', logTag, 'Starting Remote Loading track: ' .. trackName .. ' from ' .. quickRaceName)
    TriggerServerEvent("openRaceMp.triggerTrackLoad", jsonEncode({trackName=trackName, quickRaceName=quickRaceName}))
  else
    loadTrack(jsonEncode({trackName=trackName, quickRaceName=quickRaceName}))
  end
end

local function startRace() 
  log('D', logTag, 'Received Start Even from Server')
  local scenario = M.state.scenario
  if not scenario then
    log('D', logTag, 'Did not load a track yet')
    -- TODO: Show this in UI / hide start button until a track is loaded.
    return
  end

  freezeAll(scenario, 1)
  openRaceMpWayPoints.initialise(scenario)
  scenario.state = 'running'
  scenario.raceState = 'countdown'
  scenario.showCountdown = true
  scenario.currentLap = 0
  scenario.timerActive = true
  scenario.countDownTime = 3.5
  scenario.countDownShowed = false

  M.state.waypointTiming = {}
  guihooks.trigger('openRaceMp.raceStarting')
end

local function remoteTriggerStartRace()
  if TriggerServerEvent then
    log('D', logTag, 'Starting race on Server')
    TriggerServerEvent("openRaceMp.triggerStartRace", "start")
  else
    startRace()
  end
end

local function onPreRender(dt, dtSim)
  local scenario = M.state.scenario
  if not scenario then return end

  if scenario.state == 'pre-start' then
    -- tickPreStart(dt, dtSim)
  elseif scenario.state == 'pre-running' then
    -- tickPreRunning(dt, dtSim)
  elseif scenario.state == 'running' then
    tickRunning(dt, dtSim)
  elseif scenario.state == 'finished' then
    -- tickFinished(dt, dtSim)
  elseif scenario.state == 'post' then
    -- tickPost(dt, dtSim)
  elseif scenario.state == 'restart' then
    -- tickRestart(dt, dtSim)
  end

  if raceMarker then
    raceMarker.render(dt, dtSim)
  end
end

local function onRaceEndORM()
  -- Send final time to server
   -- Send timing data to server
  if TriggerServerEvent then
    TriggerServerEvent("openRaceMp.triggerFinish", jsonEncode({time=M.state.scenario.timer}))
  end
  M.state.scenario.raceState = 'done'
  log('D', logTag, 'Finished race')
  guihooks.trigger('openRaceMp.raceEnd')
end

local function onRemoteWaypointTiming(msg)
  local data = jsonDecode(msg)
  -- Server always sends full state, so we can simply replace the whole state.
  M.state.waypointTiming = data
  guihooks.trigger('openRaceMp.timingsUpdated', M.state.waypointTiming)
end

local function onRaceWaypointORM(data) 
  local scenario = M.state.scenario
  if not scenario then return end

  if data.lap and data.lapDiff then
    scenario.currentLap = data.lap + data.lapDiff + 1
  end
  
  scenario.previousWaypoint = data.cur 
  scenario.nextWaypoint = data.next
  local waypointName = (data.lap + 1) .. '-' .. scenario.previousWaypoint
  local payload = {
    currentLap = scenario.currentLap, 
    lapCount = scenario.lapCount,
    previousWaypoint = waypointName,
  }
  if data.next then
    payload.nextWaypoint = scenario.currentLap .. '-' .. scenario.nextWaypoint
  end
  guihooks.trigger('openRaceMp.raceWaypoint', payload)

  -- Send timing data to server
  if TriggerServerEvent then
    TriggerServerEvent("openRaceMp.triggerWaypoint", jsonEncode({waypointName=waypointName, time=data.time}))
  end
  
  -- Optimistically update local state - will get full state updated by server.
  local existingTimings = M.state.waypointTiming[waypointName] or {}
  table.insert(existingTimings, {
    playerName = M.state.playerName,
    time = data.time
  })
  M.state.waypointTiming[waypointName] = existingTimings
  guihooks.trigger('openRaceMp.timingsUpdated', M.state.waypointTiming)
end

M.getTrackList = getTrackList
M.remoteTriggerLoadTrack = remoteTriggerLoadTrack
M.remoteTriggerStartRace = remoteTriggerStartRace
M.onPreRender = onPreRender

M.onRaceEndORM = onRaceEndORM
M.onRaceWaypointORM = onRaceWaypointORM

-- Make sure we can stil develop outside of MP.
if AddEventHandler then
  AddEventHandler("openRaceMp.loadTrack", loadTrack)
  AddEventHandler("openRaceMp.startRace", startRace)
  AddEventHandler("openRaceMp.waypointTiming", onRemoteWaypointTiming)
end

return M
