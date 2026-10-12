-- All the tuning knobs for Bomb Bonk live here. Tweak, sync, playtest.

local Config = {
	-- Rounds
	MIN_PLAYERS = 2,
	STUDIO_SOLO = true, -- in Studio, allow 1-player practice rounds so you can test alone
	INTERMISSION = 12, -- seconds in the lobby between rounds
	PRE_ROUND = 3, -- countdown after teleporting into the arena
	POST_ROUND = 5, -- time to show the winner before returning to the lobby
	OVERTIME_AFTER = 90, -- seconds into a round before the bomb starts speeding up on its own
	RESPAWN_TIME = 2,

	-- Map (generated automatically if Workspace has no "BombBonkMap")
	ARENA_CENTER = Vector3.new(0, 150, 0), -- top surface of the arena floor
	ARENA_RADIUS = 70,
	LOBBY_CENTER = Vector3.new(0, 150, 260),
	LOBBY_SIZE = 90,
	FALL_LIMIT = 30, -- falling this far below the arena eliminates you

	BOMB = {
		SIZE = 4,
		START_SPEED = 32,
		SPEED_MULT = 1.12, -- multiplied on every parry...
		SPEED_ADD = 2, -- ...then this is added
		MAX_SPEED = 260,
		OVERTIME_ACCEL = 4, -- speed gained per second during overtime
		TURN_RATE = 5, -- how hard the bomb curves toward its target
		SNAP_TIME = 0.15, -- when this close (in seconds of travel), fly straight at the target
		HIT_RADIUS = 4,
		FREE_DISTANCE = 12, -- after a parry, fly straight this far before homing
		SOLO_FREE_DISTANCE = 45, -- longer in solo practice so the bomb comes back to you
		PAUSE_AFTER_HIT = 1.2, -- the bomb hovers this long after bonking someone
	},

	PARRY = {
		WINDOW = 0.45, -- a press this recent still counts when the bomb arrives
		COOLDOWN = 0.9, -- missed parries lock you out this long (successful ones reset it)
		BASE_RANGE = 14, -- press within this distance to parry instantly...
		RANGE_PER_SPEED = 0.12, -- ...plus extra range as the bomb gets faster
	},

	KNOCKBACK = {
		HORIZONTAL = 140,
		VERTICAL = 90,
		KILL_DELAY = 1.5, -- seconds of ragdoll flight before the character dies
	},

	REWARDS = {
		PARTICIPATE = 5,
		PARRY = 1,
		WIN = 25,
	},

	DATASTORE_NAME = "BombBonk_v1",
	AUTOSAVE_INTERVAL = 120,
}

return Config
