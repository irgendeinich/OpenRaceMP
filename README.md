# OpenRaceMP
A mod for BeamMP to run multiplayer time trials.

All quick races using the `lapConfig` format for defining the route are supported. Both closed loops and rallies are supported.

## Installation On The Server
1. Download the latest release from the releases section.
2. Extract it into your BeamMP server.

The directory structure should look like:

- Resources
  - Client
    - openracemp.zip
  - Server
    - OpenRaceMP
      - main.lua

## Setup in BeamNG

1. Add the OpenRaceMP UI App.
2. Add the Race Countdown App.
3. Pick a track to load from the UI app. (Make sure all players are already connected, otherwise simply hit the load button again.)
4. Once everyone is in place, hit start race the countdown will start.
5. After the race, if you don't change the track simply hit start race again to restart the same track.

## Features

- Supports many existing time trials.
- Spawns in any barriers / other items defined for tracks.
- Works for any number of players.
- Works for closed loops and point to point races.
- No host advantage - timing is client side (so cheating is possible), but everyone has the same chance regardless of network.

## Not Implemented Right Now

- Multi Lap Support (fully working but missing UI to enable it)
- Automatically moving players to the start line (on most maps you can simply teleport to the existing mission marker)
- Some handling of recovering / resetting (either DQ, penalty, etc.)
- Integrating with Cobalt Essentials permission management. (right now I would not use this on a public server)
- Stopping a race without finishing it (missing UI).
- Some kind of permanent leaderboards?

## Known Bugs

- Tracks that spawn vehicle prefabs (like the cones on Hirochi Raceway) are handled weirdly (the cones are removed, but sometimes still appear for other players)

### Tested Tracks

- Hiroshi Raceway (All tracks but rock crawl)
- Utah (River Rally, Asphalt Mix)
