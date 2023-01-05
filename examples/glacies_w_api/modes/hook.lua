id = "hook"
setup = {
  slots_max = { 10, 10 },
}
weapons = {
  { gid = 0, name = "Solomon", chamber_max = 2, firepower = 4, firerange = 3, spread = 55, ammo_max = 6, }, --4
  { gid = 1, name = "Victoria", chamber_max = 1, firepower = 5, firerange = 4, spread = 45, ammo_max = 3, },
  { gid = 2, name = "Ramesses II", chamber_max = 2, firepower = 4, firerange = 3, spread = 65, ammo_max = 5,
    knockback = 50, },
  { gid = 3, name = "Richard III", chamber_max = 3, firepower = 3, firerange = 3, spread = 75, ammo_max = 8 },
  { gid = 4, name = "Makeda", chamber_max = 2, firepower = 3, firerange = 3, spread = 50, ammo_max = 6, blade = 2 }
}
ranks = {
  { nothing = 1 },
  { gain = { 0, 0 } },
  { gain = { 1 } },
  { king_hp = 1 },
  { spread = 10 },
  { ammo_max = -1 },
  { gain = { 2 } },
  { king_hp = 1 },
  { rook_hp = 1 },
  { boss_hprc = 200 },
  { gain = { 3 }, delay = 10 },
  { knight_hp = 1 },
  { spread = 15 },
  { rook_hp = 1 },
  { all_hp = 1, ammo_max = 2 },
}
base = {
  promotion = 1, surrender = 1, special = "hook",
  gain = { 3, 0, 0, 0, 1, 5, 2, 0 },

}
MODNAME = current_mod


-- JP_API CODE
do
  -- LOGGING CODE
  function _logv(o, start_str)
    if not start_str then
      start_str = ""
    end
    local function data_tostring_recursive(data, depth)
      local function indent(n)
        local str = ""
        for i = 0, n do
          str = str .. "  "
        end
        return str
      end

      if data == nil then
        return "nil"
      end
      local data_type = type(data)
      if data_type == type(true) then
        if data then
          return "true"
        else
          return "false"
        end
      elseif data_type == type(1) then
        return "" .. data
      elseif data_type == type("") then
        return "\"" .. data .. "\""
      elseif data_type == type(function() end) then
        return "function()"
      elseif data_type == type({}) then
        if depth == 4 then
          return "{...}"
        end
        local data_string = "{"
        for key, value in pairs(data) do
          if value == "_G" then
            data_string = data_string .. "\n" .. indent(depth) ..
                "_G: {...}," -- don't recurse into _G
          else
            data_string = data_string .. "\n" .. indent(depth) ..
                data_tostring_recursive(key, depth + 1) .. ": " .. data_tostring_recursive(value, depth + 1) .. ","
          end
        end
        if data_string == "{" then
          return "{}"
        end
        if data_string:sub(-1) == "," then
          data_string = data_string:sub(1, -2)
        end
        data_string = data_string .. "\n" .. indent(depth - 1) .. "}"
        return data_string
      else
        return "MISSING DATA TYPE: " .. data_type
      end
    end

    _log("DATA START: " .. start_str .. "\n" .. data_tostring_recursive(o, 0) .. "\nDATA END")
  end

  function _logs(o, value)
    local function search_recurse(p, v, d, path)
      if type(p) == type({}) then
        for k, v2 in pairs(p) do
          if v2 == v and type(v2) == type(v) then
            if (type(k) == type("")) or (type(k) == type(1)) then
              _log(path .. "." .. k)
            else
              _log(path .. "[non-string key]")
            end
          elseif (d < 4) and (v2 ~= _G) then
            if (type(k) == type("")) or (type(k) == type(1)) then
              search_recurse(v2, v, d + 1, path .. "." .. k)
            else
              search_recurse(v2, v, d + 1, path .. "[non-string key]")
            end
          end
        end
      end
    end

    if (type(value) == type("")) or (type(value) == type(1)) then
      _log("SEARCHING FOR " .. value)
    else
      _log("SEARCHING FOR NON-STRING/NUMBER")
    end
    search_recurse(o, value, 0, "")
  end

  -- LISTENER CODE
  function init_listeners()
    if LISTENER then
      del(ents, LISTENER)
    end
    LISTENER = mke()
    LISTENER.listeners = {}
    LISTENER.specials = {}
    LISTENER.listeners["shot"] = {}
    LISTENER.listeners["blade"] = {}
    LISTENER.listeners["move"] = {}
    LISTENER.listeners["special"] = {}
    LISTENER.listeners["upd"] = {}
    LISTENER.listeners["dr"] = {}
    LISTENER.listeners["bullet_init"] = {}
    LISTENER.listeners["bullet_upd"] = {}
    LISTENER.listeners["after_black"] = {}
    LISTENER.listeners["after_white"] = {}
    local function click_tracker()
      local function shoot_tracker(ent)
        ent.old_left_clic = ent.left_clic
        ent.left_clic = function()
          local old_sq = hero.sq
          ent.old_left_clic()
          if old_sq ~= hero.sq then
            for listener in all(LISTENER.listeners["move"]) do
              listener()
            end
          end
          local shot = false
          for b in all(bullets) do
            if b.shot and not b.old_upd then
              b.old_upd = b.upd
              b.upd = function(self)
                for listener in all(LISTENER.listeners["bullet_upd"]) do
                  listener(self)
                end
                self.old_upd(self)
              end
              for listener in all(LISTENER.listeners["bullet_init"]) do
                listener(b)
              end
              shot = true
            end
          end
          if shot then
            for listener in all(LISTENER.listeners["shot"]) do
              listener()
            end
          end
        end
        if ent.right_clic then
          local skip = false
          for special, func in pairs(LISTENER.specials) do
            if stack[special] then
              ent.old_right_clic = func
              skip = true
            end
          end
          if not skip then
            ent.old_right_clic = ent.right_clic
          end
          ent.right_clic = function()
            ent.old_right_clic()
            for listener in all(LISTENER.listeners["special"]) do
              listener()
            end
          end
        end
      end

      local function blade_tracker(ent)
        ent.old_left_clic = ent.left_clic
        ent.left_clic = function()
          local folly = check_folly_shields(hero.sq)
          if folly then
            if ((#hero.sq.danger == 1) and (hero.sq.danger[1] == get_square_at(mx, my).p)) or stack.bushido then
              folly = false
            end
          end
          ent.old_left_clic()
          if not folly then
            for listener in all(LISTENER.listeners["blade"]) do
              listener()
            end
          end
        end
        if ent.right_clic then
          local skip = false
          for special, func in pairs(LISTENER.specials) do
            if stack[special] then
              ent.old_right_clic = func
              skip = true
            end
          end
          if not skip then
            ent.old_right_clic = ent.right_clic
          end
          ent.right_clic = function()
            ent.old_right_clic()
            for listener in all(LISTENER.listeners["special"]) do
              listener()
            end
          end
        end
      end

      local function move_tracker(ent)
        ent.old_left_clic = ent.left_clic
        ent.left_clic = function()
          local old_sq = hero.sq
          ent.old_left_clic()
          if old_sq ~= hero.sq then
            for listener in all(LISTENER.listeners["move"]) do
              listener()
            end
          end
        end
        if ent.right_clic then
          local skip = false
          for special, func in pairs(LISTENER.specials) do
            if stack[special] then
              ent.old_right_clic = func
              skip = true
            end
          end
          if not skip then
            ent.old_right_clic = ent.right_clic
          end
          ent.right_clic = function()
            ent.old_right_clic()
            for listener in all(LISTENER.listeners["special"]) do
              listener()
            end
          end
        end
      end

      if not hero then return end
      for ent in all(ents) do
        local ent_sq = get_square_at(ent.x, ent.y)
        if ent.button and ent_sq and ent.left_clic and not ent.old_left_clic then
          local hero_square = hero.sq
          if not hero_square then return end
          if abs(ent_sq.px - hero_square.px) <= 1 and abs(ent_sq.py - hero_square.py) <= 1 then
            -- WITHIN 3x3
            if not ent_sq.p then move_tracker(ent)
            elseif stack.blade and ent_sq.p.hp <= stack.blade then blade_tracker(ent)
            else shoot_tracker(ent) end
          else
            shoot_tracker(ent)
          end
        end
      end
    end

    LISTENER.run = true
    LISTENER.jumping = false
    function LISTENER:upd()
      if not LISTENER.run then return end
      click_tracker()
      for listener in all(LISTENER.listeners["upd"]) do
        listener()
      end
      for special, func in pairs(LISTENER.specials) do
        if stack.special == special then
          stack.special = "grenade"
          stack[special] = true
        end
      end
      if hero and hero.twc then
        LISTENER.jumping = true
      end
      if hero and (not hero.twc) and LISTENER.jumping then
        LISTENER.jumping = false
        for listener in all(LISTENER.listeners["after_black"]) do
          listener()
        end
      end
    end

    function LISTENER:dr()
      if not LISTENER.run then return end
      lprint("JP_API 1.1", 248, 162.5, 2)
      lprint(MODNAME, 5, 162.5, 2)
      for listener in all(LISTENER.listeners["dr"]) do
        listener()
      end
    end
  end

  function add_listener(event, listener)
    if not LISTENER.listeners[event] then
      LISTENER.listeners[event] = {}
    end

    del(LISTENER.listeners[event], listener)
    add(LISTENER.listeners[event], listener)
  end

  function remove_listener(event, listener)
    del(LISTENER.listeners[event], listener)
  end

  function new_special(name, special)
    LISTENER.specials[name] = special
  end

  function on_new_turn()
    for listener in all(LISTENER.listeners["after_white"]) do
      listener()
    end
  end

  -- GUN DESCRIPTIONS
  function initialize()
    load_mod("none")
    load_mod(MODNAME)
    if mode.ranks then mode.ranks_index = mid(0, bget(0, 4), #ranks - 1) end
    if mode.weapons then mode.weapons_index = mid(0, bget(1, 4), #weapons - 1) end
    palette("mods\\" .. MODNAME .. "\\gfx.png")
  end

  function enable_description()
    local x = {}
    if weapons[mode.weapons_index + 1].desc then
      x = mk_hint_but(280, 64, 8, 9, weapons[mode.weapons_index + 1].desc, { 4 }, 100, nil, { x = 170, y = 75 })
    else
      x = mke()
    end
    x.lastindex = mode.weapons_index
    x.dr = function(self)
      if weapons[mode.weapons_index + 1].desc then
        lprint("?", 284, 67, 5)
      end
      if (mode.weapons_index ~= self.lastindex) then
        del(ents, self)
        enable_description()
      end
    end
  end

  function get_weapons_list()
    local a = {}
    for i = 0, #weapons do
      add(a, i)
    end
    enable_description()
    return a
  end
end
-- LISTENER CODE END

-- MOD CODE
do
  function mod_setup()
    init_listeners()
    enable_hook()
    add_listener("dr", function()
      lprint(lang.credits, 181, 158, 6)
    end)
  end

  function enable_hook()
    --[[
		  Relavant Card Effects:

		  special = "hook"			Activates the Hook
	  	hookdmg = <num>				Increases damage of the hook by <num>
	  	<piece>_hkim = 1			<piece> can't be pulled or stunned anymore
	  --]]
    new_special("hook", function()
      local def_dmg = 1 -- default damage of the hook
      local immune = { -- pieces that don't get pulled or stunned
        -- pawn = false,
        -- knight = false,
        -- bishop = false,
        -- rook = false,
        -- queen = false,
        king = true,
        boss = true,
        -- canonball = false
      }
      local leader_immune = false -- whether the current leader can be pulled or stunned

      -- display setup
      local hook_speed = 9 -- animation speed of the hook (unit: pixels per frame)
      local rope_time = 20 -- duration for which the rope can exist before hitting a piece (unit: frame)
      local rope_colour = 5 -- colour of the rope
      local piece_tempo = 12 -- number of frames it takes for the piece to get pulled back
      local enable_sfx = true -- enables sfx for throwing the hook

      local hook = mke()
      if enable_sfx then sfx("grab_done") end
      hook.x = hero.x + 8 + 8 * cos(hero.current_an)
      hook.y = hero.y + 8 + 8 * sin(hero.current_an)
      hook.vx = hook_speed * cos(hero.current_an)
      hook.vy = hook_speed * sin(hero.current_an)
      hook.start_x = hero.x + 8 + 8 * cos(hero.current_an)
      hook.start_y = hero.y + 8 + 8 * sin(hero.current_an)
      hook.life = rope_time
      function hook:upd()
        local hook_sq = get_square_at(hook.x, hook.y)
        if hook_sq and hook.stop == nil then
          if hook_sq.p then
            local p = hook_sq.p
            hit(p, def_dmg) -- code by Glacies
            if p.dead or immune[p.name] or p.hkim or (p.leader and leader_immune) then
              del(ents, hook)
              hook:nxt()
            else
              p.stun = true
              hook.vx = 0
              hook.vy = 0
              hook.stop = true
              hook.life = nil
              wait(15, function()
                if hook.sq then
                  p.sq.p = nil
                  hook.sq.p = p
                  p.sq = hook.sq
                  p.sx = p.x
                  p.sy = p.y
                  p.ex = hook.sq.x
                  p.ey = hook.sq.y
                  p.tws = piece_tempo
                  p.twc = 0
                  if p.type == 0 and hook.sq.py == 7 then
                    add_event(ev_promote, p)
                  end
                  hook.sx = hook.x
                  hook.sy = hook.y
                  hook.ex = hook.start_x
                  hook.ey = hook.start_y
                  hook.tws = piece_tempo
                  hook.twc = 0
                  function hook:twf()
                    del(ents, hook)
                    hook:nxt()
                  end
                else
                  del(ents, hook)
                  hook:nxt()
                end
              end)
            end
          elseif hook.sq == nil then
            hook.sq = hook_sq
          end
        end
      end

      function hook:dr()
        line(self.start_x, self.start_y, self.x, self.y, rope_colour)
      end

      function hook:nxt()
        wait(15, opp_turn)
      end

      remove_buts()
    end)
  end
end
-- MOD CODE END

function start()

  init_vig({ 1, 2, 3 }, function()
    init_game()
    mode.lvl = 0
    mode.turns = 0

    -- MOD SETUP
    mod_setup()

    next_floor()
  end)

end

function next_floor()
  mode.lvl = mode.lvl + 1
  new_level()
end

function grow()
  if mode.lvl < 11 then
    local data = {
      id = "level_up",
      pan_xm = 1,
      pan_ym = 2,
      pan_width = 80,
      pan_height = 96,
      choices = {
        { { team = 0 }, { team = 1 } },
        { { team = 0 }, { team = 1 } },
      },
      force = {
        { lvl = 3, id = "Homecoming", choice_index = 0, card_index = 1, desc_key = "queen_escape" },
        { lvl = 3, id = "Homecoming", choice_index = 1, card_index = 1, desc_key = "queen_everywhere" }
      }
    }
    level_up(data, next_floor)
  elseif mode.lvl == 11 then
    add(upgrades, { gain = { 6 }, sac = { 5 } })
    init_vig({ 4 }, next_floor)
  end
end

function outro()

  local v = { 6, 7 }
  local best = 13
  trig_achievement("COMPLETE")

  if boss.book then
    best = 14
    v = { 8, 6, 11 }
    trig_achievement("AVENGED")
    if chamber > 0 then
      best = 15
      v = { 8, 9, 10, 6, 12 }
      trig_achievement("EXORCISED")
    end
  end

  -- BEST FLOOR
  local rank = mode.ranks_index + 1
  progress(rank, 1, bfl)

  -- BEST RANK
  progress(0, 1, rank)

  -- BEST TIME
  if opt("speedrun") == 1 then
    local best_time = bget(rank, 2)
    if best_time == 0 or chrono_time < best_time then
      bset(rank, 2, chrono_time)
      new_best_time = true
    end
  end
  --
  save()


  -- COLLECTION
  check_collections()


  init_vig(v, init_menu)
end

-- ON
function on_empty()
  end_level(grow)

end

function on_hero_death()
  progress(mode.ranks_index + 1, 1, mode.lvl)
  check_collections()
  save()
  gameover()
end

function on_boss_death()
  -- CHECK BLACK BISHOP SPAWN
  local bishops = get_pieces(2)
  local book = has_card("The Red Book")
  local theo = perm["Theocracy"]
  if book and theo and (#bishops == 1 or (DEV and #bishops >= 1)) then
    bishops[1].chosen = true
    spawn_dark_bishop()
    return
  end

  -- END GAME
  music("ending_A", 0)
  fade_to(-4, 30, outro)

end

function check_unlocks()
end

function save_preferences()
  bset(0, 4, mode.ranks_index)
  bset(1, 4, mode.weapons_index)
  save()
end

--
function draw_inter()
  local s = lang.floor_
  local x = lprint(s, MCW / 2, board_y - 19, 3, 1)
  lprint(mode.lvl, x, board_y - 19, 5)
end