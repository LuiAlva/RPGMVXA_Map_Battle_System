=begin
MBS.battle(Enemy ID, $game_map.map_id, @event_id, $game_party.leader.id) 
MBS.battle( 1, 112,$game_map.map_id, @event_id, $game_party.leader.id)
MBS.health_add(enemy, amount)
=end

  MEM_VARIABLE    = 203
  HIT_ANIMATION   = 112
  PLAYER_COOLDOWN = 60
  MAX_AGILITY     = 250
  # Player attack animations
  PA_ANIM_RIGHT   = 120
  PA_ANIM_DOWN    = 121
  PA_ANIM_LEFT    = 122
  PA_ANIM_UP      = 123
  
  #* If you are using Map HUD v1.20 by Adiktuzmiko
  #* (Download link: http://forums.rpgmakerweb.com/index.php?/topic/22668-shanas-map-hud-v120/)
  MAP_HUD              = true
  MAP_ENEMY_HP_GAUGE   = true

class MBS < Game_Character
  
  def self.initial
    if $game_variables[MEM_VARIABLE] == 0
      $player_cooldowns = [0,0,0]
      $enemies = [[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0]]
      $skills = [[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]]
    else
      $enemies = $game_variables[MEM_VARIABLE][0]
      $skills = $game_variables[MEM_VARIABLE][1]
      $player_cooldowns = $game_variables[MEM_VARIABLE][2]
    end
    if MAP_ENEMY_HP_GAUGE
      $enemy_hp_window = Enemy_Info_Window.new(1, 0) #(enemy_id, hp)
      $enemy_hp_window.close
    end
  end
  
  #||=========================================================================||
  #|| BATTLE   ===============================================================||
  #||=========================================================================||
  def self.battle(enemy_num, enemy_id, hit_anim, atk_anim, map_id, event_id)
    actor_id = $game_party.leader.id
    # get skill
    set_attack_skill
    set_skill(0, $skills[0][0])
    set_skill(1, $skills[1][0])
    $attack = $game_actors[actor_id].atk + rand( $game_actors[actor_id].atk / 2 )
    if alive?(enemy_num) == false
      start(enemy_num, enemy_id, hit_anim, atk_anim, map_id, event_id, actor_id)
    end
    
    # Player attack
    if range(1,0,2,0,event_id) #player_attack_radius?($game_player.direction, $game_player.x, $game_player.y, $game_map.events[event_id].x, $game_map.events[event_id].y) then
      # HIT
      if $player_cooldowns[0] == 0 then
        if Input.trigger?(Input::C) then
          attack(enemy_num, enemy_id, event_id)
        end
      end
    end
	
	#Player Skill Use [id, range, distance/width, height, cooldown, animation, timer]
	if Input.trigger?(Input::L)
    if $skills[0][6] == 0
      if range($skills[0][1],0,$skills[0][2],$skills[0][3],event_id)
        calc_damage(0, enemy_num, enemy_id)
        $skills[0][6] = $skills[0][4]
      end
    end
  end
  if Input.trigger?(Input::R)
    if $skills[1][6] == 0
      if range($skills[1][1],0,$skills[1][2],$skills[1][3],event_id)
        calc_damage(1, enemy_num, enemy_id)
        $skills[1][6] = $skills[1][4]
      end
    end
  end
  if Input.trigger?(Input::X)
    if $skills[3][6] == 0
      if range($skills[3][1],0,$skills[3][2],$skills[3][3],event_id)
        calc_damage(3, enemy_num, enemy_id)
        $skills[3][6] = $skills[3][4]
      end
    end
  end
    
    # Enemy Attacking
    if range(1,1,1,0,event_id) #enemy_attack_radius?(event_id, $game_player.x, $game_player.y, $game_map.events[event_id].x, $game_map.events[event_id].y) then
      enemy_attack(enemy_num, enemy_id, event_id, actor_id)
    end
    
    #Enemy deaths
    enemy_death_check(enemy_num, enemy_id, map_id, event_id) #Check if enemy is dead
    if all_dead? == true
      Audio.me_play("Audio/ME/Fanfare1", 80, 100)
      $game_map.autoplay
    end
    
    #player death
    if $game_actors[actor_id].hp == 0
      $game_actors[actor_id].set_graphic("Damage1", 4, "Actor4", 4)
      $game_player.refresh
      Audio.se_play("Audio/SE/Collapse3", 80, 100)
      tone = Tone.new(0,0,0,255)
      $game_map.screen.start_tone_change(tone, 1)
      SceneManager.call(Scene_Gameover)
    end
    
    #Cooldown Timers update
    #update_timers(enemy_num)
    
    
  end # <= End of Battle
  
  #||=========================================================================||
  #|| BATTLE SYSTEM   ===============================================================||
  #||=========================================================================||
  
  def self.start(enemy_num, enemy_id, hit_anim, atk_anim, map_id, event_id, actor_id)
    Audio.bgm_play("Audio/BGM/Battle4", 80, 100)
    Audio.se_play("Audio/SE/Powerup", 80, 100)
    health = $data_enemies[enemy_id].params[0]
    magic = $data_enemies[enemy_id].params[1]
  #*$enemy_# = [health, magic, hit_anim, atk_anim, dead/alive, atk_timer, status, status_timer]
    $enemies[enemy_num] = [health, magic, hit_anim, atk_anim, 1, 0, 0, 0, event_id]
    if MAP_HUD then
      if ADIK::MAP_HUD.use_hud == false then
        ADIK::MAP_HUD.change_actor($game_party.leader.id)
        ADIK::MAP_HUD.toggle
      end
    end
  end
  
  def self.change_enemy_stats(enemy_num, stat, amount, change)
    if change == 0 #equal
      $enemies[enemy_num][stat] = amount 
    elsif change == 1 #add
      $enemies[enemy_num][stat] += amount
    elsif change == 2 #subtract
      $enemies[enemy_num][stat] -= amount
    elsif change == 3 #multiply 
      $enemies[enemy_num][stat] *= amount
    elsif change == 4 #divide
      $enemies[enemy_num][stat] /= amount
    elsif change == 5 #divide
      $enemies[enemy_num][stat] %= amount
    end
  end
  
  def self.enemy_death_check(enemy_num, enemy_id, map_id, event_id)
    if $enemies[enemy_num][0] <= 0
      $enemies[enemy_num][4] = 0
      $game_party.gain_gold($data_enemies[enemy_id].gold)
      Audio.se_play("Audio/SE/Coin", 80, 100)
      $game_party.members.each { |actor| actor.change_exp(actor.exp + $data_enemies[enemy_id].exp, true) }
      kill_enemy(map_id, event_id)
    end
  end
  
  def self.kill_enemy(map_id, event_id)
    if MAP_ENEMY_HP_GAUGE
      $enemy_hp_window.close
    end
    if all_dead? == true then
      Audio.me_play("Audio/ME/Fanfare1", 80, 100)
      $game_map.autoplay
      if MAP_HUD then
        ADIK::MAP_HUD.change_actor($game_party.leader.id)
        ADIK::MAP_HUD.toggle
      end
    end
    $game_self_switches[[map_id, event_id, "A"]] = false
    $game_self_switches[[map_id, event_id, "B"]] = true
  end
  
  def self.all_dead?
    if $enemies[0][4] == 0 && $enemies[1][4] == 0 && $enemies[2][4] == 0 && $enemies[3][4] == 0 && $enemies[4][4] == 0 && $enemies[5][4] == 0 && $enemies[6][4] == 0 && $enemies[7][4] == 0 && $enemies[8][4] == 0 && $enemies[9][4] == 0
      return true
    else
      return false
    end
  end
  
  def self.attack_animation
    if $game_player.direction == 6
      $game_player.animation_id = PA_ANIM_RIGHT
    elsif $game_player.direction == 4
      $game_player.animation_id = PA_ANIM_LEFT
    elsif $game_player.direction == 8
      $game_player.animation_id = PA_ANIM_UP
    elsif $game_player.direction == 2
      $game_player.animation_id = PA_ANIM_DOWN
    end
  end
  
  def self.calc_cooldown(agility)
    return 120 - ((60 * agility) / MAX_AGILITY)
  end
  
  def self.update_timers
    $enemies.each_index {|x| ($enemies[x][5] -= 1) if ($enemies[x][5] > 0) }
    $enemies.each_index {|x| ($enemies[x][7] -= 1) if ($enemies[x][7] > 0) }
    $player_cooldowns.each_index {|x| ($player_cooldowns[x] -= 1) if ($player_cooldowns[x] > 0) }
    $skills.each_index {|x| ($skills[x][6] -= 1) if ($skills[x][6] > 0) }
    # Write Variable to memory
    $game_variables[MEM_VARIABLE]  = []
    $game_variables[MEM_VARIABLE] += $enemies
    $game_variables[MEM_VARIABLE] += $skills
    $game_variables[MEM_VARIABLE] += $player_cooldowns
  end
  
  def self.alive?(enemy_num) #Checks if enemy is alive
    if $enemies[enemy_num][4] == 1
      return true
    else
      return false
    end
  end
  
  #||=========================================================================||
  #|| DAMAGE   ===============================================================||
  #||=========================================================================||
  
  def self.attack(enemy_num, enemy_id, event_id)
    attack_animation
    $player_cooldowns[0] = calc_cooldown($game_actors[$game_party.leader.id].agi)
    calc_damage(2, enemy_num, enemy_id)
    $enemies[enemy_num][5] += calc_cooldown($data_enemies[enemy_id].params[6]) / 4
    # Event move away from player
    if $enemies[enemy_id][0] <= 0
      move_route = RPG::MoveRoute.new; move_route.repeat = false; move_route.skippable = true
      m = RPG::MoveCommand.new; m.code = 11; move_route.list.insert(0, m)
      $game_map.events[event_id].force_move_route(move_route) # For Events
    end
  end
  
  def self.enemy_attack(enemy_num, enemy_id, event_id, actor_id)
    if $enemies[enemy_num][5] == 0
      pcool = calc_cooldown($game_actors[actor_id].agi)
      $player_cooldowns[0] += pcool / 3
      $player_cooldowns[0] = pcool if $player_cooldowns[0] > pcool
      $enemies[enemy_num][5] = calc_cooldown($data_enemies[enemy_id].params[6])
      #$game_actors[actor_id].hp -= calc_enemy_formula(1, enemy_id)
      calc_damage(1, enemy_num, enemy_id, 1)
    end
  end
  
  def self.calc_player_formula(skill_id, enemy_id = 0)
    actor_id = $game_party.leader.id
    formula = "#{$data_skills[skill_id].damage.formula}"
    formula.sub! 'a.mhp', "#{$game_actors[actor_id].mhp}"
    formula.sub! 'a.mmp', "#{$game_actors[actor_id].mmp}"
    formula.sub! 'a.atk', "#{$game_actors[actor_id].atk}"
    formula.sub! 'a.def', "#{$game_actors[actor_id].def}"
    formula.sub! 'a.mat', "#{$game_actors[actor_id].mat}"
    formula.sub! 'a.mdf', "#{$game_actors[actor_id].mdf}"
    if enemy_id != 0
      formula.sub! 'b.mhp', "#{$data_enemies[enemy_id].params[0]}"
      formula.sub! 'b.mmp', "#{$data_enemies[enemy_id].params[1]}"
      formula.sub! 'b.atk', "#{$data_enemies[enemy_id].params[2]}"
      formula.sub! 'b.def', "#{$data_enemies[enemy_id].params[3]}"
      formula.sub! 'b.mat', "#{$data_enemies[enemy_id].params[4]}"
      formula.sub! 'b.mdf', "#{$data_enemies[enemy_id].params[5]}"
    end
    damage = eval(formula)
    damage = 0 if damage < 0
    (damage = ((damage *  ( 100 - $data_skills[skill_id].damage.variance + rand($data_skills[skill_id].damage.variance))) / 100)) if damage != 0
    return damage
  end
  
  def self.calc_enemy_formula(skill_id, enemy_id = 0)
    actor_id = $game_party.leader.id
    formula = "#{$data_skills[skill_id].damage.formula}"
    formula.sub! 'a.mhp', "#{$data_enemies[enemy_id].params[0]}"
    formula.sub! 'a.mmp', "#{$data_enemies[enemy_id].params[1]}"
    formula.sub! 'a.atk', "#{$data_enemies[enemy_id].params[2]}"
    formula.sub! 'a.def', "#{$data_enemies[enemy_id].params[3]}"
    formula.sub! 'a.mat', "#{$data_enemies[enemy_id].params[4]}"
    formula.sub! 'a.mdf', "#{$data_enemies[enemy_id].params[5]}"
    formula.sub! 'b.mhp', "#{$game_actors[actor_id].mhp}"
    formula.sub! 'b.mmp', "#{$game_actors[actor_id].mmp}"
    formula.sub! 'b.atk', "#{$game_actors[actor_id].atk}"
    formula.sub! 'b.def', "#{$game_actors[actor_id].def}"
    formula.sub! 'b.mat', "#{$game_actors[actor_id].mat}"
    formula.sub! 'b.mdf', "#{$game_actors[actor_id].mdf}"
    damage = eval(formula)
    damage = 0 if damage < 0
    (damage = ((damage *  ( 100 - $data_skills[skill_id].damage.variance + rand($data_skills[skill_id].damage.variance))) / 100)) if damage != 0
    return damage
  end
  
  def self.calc_damage(skill, enemy_num, enemy_id, switch = 0)
    if switch == 0
      skill_id  = $skills[skill][0]
    else
      skill_id = skill
    end
    actor_id = $game_party.leader.id
    skill_type = $data_skills[skill_id].damage.type
    skill_cost = $data_skills[skill_id].mp_cost
    player_mp = $game_actors[actor_id].mp
    if (switch == 0 && skill_cost <= player_mp) || (switch == 1 && skill_cost <= $enemies[enemy_num][1])
      if skill_type == 0 #"None"
        
      elsif skill_type == 1 #"HP Damage"
        if switch == 0
          $enemies[enemy_num][0] -= calc_player_formula(skill_id, enemy_id)
        elsif switch == 1
          $game_actors[actor_id].hp -= calc_enemy_formula(skill_id, enemy_id)
        end
      elsif skill_type == 2 #"MP Damage"
        if switch == 0
          $enemies[enemy_num][1] -= calc_player_formula(skill_id, enemy_id)
        elsif switch == 1
          $game_actors[actor_id].mp -= calc_enemy_formula(skill_id, enemy_id)
        end
      elsif skill_type == 3 #"HP Recovery"
        if switch == 0 && $game_actors[actor_id].hp != $game_actors[actor_id].mhp
          $game_player.animation_id = $skills[skill][5]
          $game_actors[actor_id].hp += calc_player_formula(skill_id, 0)
        elsif switch == 1
          $game_map.events[$enemies[enemy_num][8]].animation_id = $enemies[enemy_num][2]
          $enemies[enemy_num][0] += calc_enemy_formula(skill_id, enemy_id)
        end
      elsif skill_type == 4 #"MP Recovery"
        
      elsif skill_type == 5 #"HP Drain"
        
      elsif skill_type == 6 #"MP Drain"
      
      end
      if switch == 0 && skill_type != 3 && skill_type != 4
        $game_map.events[$enemies[enemy_num][8]].animation_id = $skills[skill][5] #hit on event
        $game_actors[actor_id].mp -= skill_cost
      elsif switch == 1 && skill_type != 3 && skill_type != 4
        $game_player.animation_id = $enemies[enemy_num][2]
        $enemies[enemy_num][1] -= skill_cost
      end
    end
    if MAP_ENEMY_HP_GAUGE
      $enemy_hp_window.close
      $enemy_hp_window = Enemy_Info_Window.new(enemy_id, $enemies[enemy_num][0]) #(enemy_id, hp)
      $enemy_hp_window.open
    end
  end
  
  #||=========================================================================||
  #|| SKILLS   ===============================================================||
  #||=========================================================================||
  # $skills = [id, range, distance/width, height, cooldown, hit_anim, timer]
  def self.set_skill(equip_slot,skill_id)
    if $skills[equip_slot][0] != skill_id
      if skill_id == 1
        $skills[equip_slot] = [skill_id, 1, 2, 0, 120, 112, 0]
      elsif skill_id == 26
        $skills[equip_slot] = [skill_id, 0, 0, 0, 160, 37, 0]
      elsif skill_id == 51
        $skills[equip_slot] = [skill_id, 1, 5, 0, 300, 57, 0]
      elsif skill_id == 55
        $skills[equip_slot] = [skill_id, 1, 4, 0, 360, 61, 0]
      end
    end
  end
  
  def self.set_attack_skill
    skill = weapon_skill
    set_skill(2, skill[0])
    $skills[2][4] = calc_cooldown($game_actors[$game_party.leader.id].agi)
    $skills[2][5] = skill[1]
  end
  
  def self.weapon_skill
    #[skill_id, hit_anim]
    return [1,112]
  end
  
  #||=========================================================================||
  #|| RANGE    ===============================================================||
  #||=========================================================================||
  
  def self.range(type, switch, x, y = 0, event_id)
    if type == 0      #for self skills
      return true
    elsif type == 1
      if switch == 0
        if range_los(x, $game_player.direction, $game_player.x, $game_player.y, $game_map.events[event_id].x, $game_map.events[event_id].y) == true
          return true
        else
          return false
        end
      elsif switch == 1
        if range_los(x, $game_map.events[event_id].direction, $game_map.events[event_id].x, $game_map.events[event_id].y, $game_player.x, $game_player.y) == true
          return true
        else
          return false
        end
      end
    elsif type == 2
      if switch == 0
        if range_surround(x, y, distance, $game_player.x, $game_player.y, $game_map.events[event_id].x, $game_map.events[event_id].y) == true
          return true
        else
          return false
        end
      elsif switch == 1
        if range_surround(x, y, distance, $game_map.events[event_id].x, $game_map.events[event_id].y, $game_player.x, $game_player.y) == true
          return true
        else
          return false
        end
      end
    end
  end
  
  def self.range_los(dist, d, px, py, ex, ey)
    xx = px - ex; yy = py - ey
    if (d == 4 && py == ey &&  xx >= 0 && xx <= dist) then          # < Left attack
      return true
    elsif (d == 6 && py == ey && xx <= 0 && (xx - (xx + xx)) <= dist) then   # > Right attack
      return true
    elsif (d == 8 && px == ex && yy >= 0 && yy <= dist ) then      # ^ Up attack
      return true
    elsif (d == 2 && px == ex && yy <= 0 && (yy - (yy + yy)) <= dist) then   # v Down attack
      return true
    else
      return false
    end
  end
  
  def self.range_surround(width, height, px, py, ex, ey)
    xx = px - ex; yy = py - ex
    if ((xx < 0 && xx >= (0-width)) || (xx > 0 && xx <= width) || xx == 0)
      if ((yy < 0 && yy >= (0-height)) || (yy > 0 && yy <= height) || yy == 0)
        return true
      else
        return false
      end
    end
  end
    
end

class Scene_Map

  alias fragadagalops_mbs_initialize initialize
  def initialize
    MBS.initial
    fragadagalops_mbs_initialize
  end
  
  alias start_fraga_mbs start
  def start
    start_fraga_mbs
    MBS.update_timers
  end
  
  alias update_fraga_mbs update
  def update
    update_fraga_mbs
	  MBS.update_timers
  end
  
  alias terminate_fraga_mbs pre_terminate
  def pre_terminate
    terminate_fraga_mbs
  end
end
