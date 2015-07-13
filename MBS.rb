=begin
MBS.battle(Enemy_Num, Enemy_ID, Hit_animation, Attack_Animation, $game_map.map_id, @event_id)
=end

  MEM_VARIABLE      = 203
  HIT_ANIMATION     = 112
  PLAYER_COOLDOWN   = 60
  MAX_AGILITY       = 250
  DANGER_IMAGE      = "low_health"
  DANGER_SOUND      = "Audio/BGS/heartbeat"
  VICTORY_FANFARE   = "Audio/ME/Fanfare1"
  # Max enemies allowed on map. Each zero is an enemy MAX = 20
  MAX_ENEMIES     = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
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
      $enemies = MAX_ENEMIES
      $enemies.each_index {|x| $enemies[x] = [0,0,0,0,0,0,0,0,0]}
      $skills = [0,0,0,0,0]
      $skills.each_index {|x| $skills[x] = [0,0,0,0,0,0,0]}
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
    
    if alive?(enemy_num) == false
      start(enemy_num, enemy_id, hit_anim, atk_anim, map_id, event_id, actor_id)
    end
    
    # Player attack
    if range($skills[0][1],0,$skills[0][2],$skills[0][3],event_id)
      if $skills[0][6] == 0 then
        if Input.trigger?(Input::C) then
          attack(enemy_num, enemy_id, event_id)
        end
      end
    end
	
    #Player Skill Use [id, range, distance/width, height, cooldown, animation, timer]
    if Input.trigger?(Input::L)
      use_player_skill(1, enemy_num, enemy_id, event_id)
    end
    if Input.trigger?(Input::R)
      use_player_skill(2, enemy_num, enemy_id, event_id)
    end
    if Input.trigger?(Input::X)
      use_player_skill(3, enemy_num, enemy_id, event_id)
    end
    
    # Enemy Attacking
    if range(1,1,1,0,event_id) #enemy_attack_radius?(event_id, $game_player.x, $game_player.y, $game_map.events[event_id].x, $game_map.events[event_id].y) then
      enemy_attack(enemy_num, enemy_id, event_id, actor_id)
    end
    
    #Enemy deaths
    enemy_death_check(enemy_num, enemy_id, map_id, event_id) #Check if enemy is dead
    # victory - all enemies are dead
    if all_dead? == true
      Audio.me_play(VICTORY_FANFARE, 80, 100)
      $game_map.autoplay
    end
  end # <= End of Battle
  
  #||=========================================================================||
  #|| BATTLE SYSTEM   ========================================================||
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
    i = 0
    $enemies.each_index {|x| (i += 1) if alive?(x)}
    if i == 0
    #if $enemies[0][4] == 0 && $enemies[1][4] == 0 && $enemies[2][4] == 0 && $enemies[3][4] == 0 && $enemies[4][4] == 0 && $enemies[5][4] == 0 && $enemies[6][4] == 0 && $enemies[7][4] == 0 && $enemies[8][4] == 0 && $enemies[9][4] == 0
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
  
  def self.update
    low_health_danger
    #Player Item Use
    if Input.trigger?(Input::Y)
      SceneManager.call(Scene_Item)
    end
    #player death
    if $game_actors[$game_party.leader.id].hp == 0
      actor = $game_party.leader.id
      $game_party.members.each_index {|x| actor = (x+1) if $game_actors[x+1].hp != 0}
      if actor != $game_party.leader.id
        $game_party.swap_order(0, $game_actors[actor].index)
        if MAP_HUD then
          ADIK::MAP_HUD.change_actor($game_party.leader.id)
        end
      else
        if MAP_ENEMY_HP_GAUGE
          $enemy_hp_window.close
        end
        $game_actors[$game_party.leader.id].set_graphic("Damage1", 4, "Actor4", 4)
        $game_player.refresh
        Audio.se_play("Audio/SE/Collapse3", 80, 100)
        tone = Tone.new(0,0,0,255)
        $game_map.screen.start_tone_change(tone, 1)
        SceneManager.call(Scene_Gameover)
      end
    end
    #set skills
    set_attack_skill
    set_skill(1, $skills[1][0])
    set_skill(2, $skills[2][0])
    set_skill(3, $skills[3][0])
    # update timers
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
  
  def self.low_health_danger
    actor_id = $game_party.leader.id
    health = $game_actors[actor_id].hp
    max_health = $game_actors[actor_id].mhp
    screen = $game_map.screen
    if health <  (max_health / 5)
      screen.pictures[100].show(DANGER_IMAGE, 1, 320, 240, 100, 100, 200, 0)
      Audio.bgs_play(DANGER_SOUND, 80, 100)
    else
      Audio.bgs_fade(500)
      screen.pictures[100].erase
    end
  end
  
  #||=========================================================================||
  #|| DAMAGE   ===============================================================||
  #||=========================================================================||
  
  def self.attack(enemy_num, enemy_id, event_id)
    enemy_agility = $data_enemies[enemy_id].params[6]
    enemy_cooldown = calc_cooldown(enemy_agility)
    attack_animation
    $skills[0][6] = calc_cooldown($game_actors[$game_party.leader.id].agi)
    calc_damage(0, enemy_num, enemy_id)
    $enemies[enemy_num][5] += enemy_cooldown / 3
    $enemies[enemy_num][5] = enemy_cooldown if $enemies[enemy_num][5] > enemy_cooldown
    # Event move away from player
    if $enemies[enemy_num][0] <= 0
      move_route = RPG::MoveRoute.new; move_route.repeat = false; move_route.skippable = true
      m = RPG::MoveCommand.new; m.code = 11; move_route.list.insert(0, m)
      $game_map.events[event_id].force_move_route(move_route) # For Events
    end
  end
  
  def self.enemy_attack(enemy_num, enemy_id, event_id, actor_id)
    if $enemies[enemy_num][5] == 0
      color = Color.new(200,20,20,110)
      $game_map.screen.start_flash(color, 20)
      pcool = calc_cooldown($game_actors[actor_id].agi)
      $skills[0][6] += pcool / 3
      $skills[0][6] = pcool if $skills[0][6] > pcool
      $enemies[enemy_num][5] = calc_cooldown($data_enemies[enemy_id].params[6])
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
    #a.remove_state(Put the State ID here);
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
    skill_scope = $data_skills[skill_id].scope
    player_mp = $game_actors[actor_id].mp
    if (switch == 0 && skill_cost <= player_mp) || (switch == 1 && skill_cost <= $enemies[enemy_num][1])
      if skill_type == 0 #"None"
        
      elsif skill_type == 1 #"HP Damage"
        if switch == 0
          if skill_scope == 2
            $game_player.animation_id = $skills[skill][5]
            $enemies.each_index {|x| $enemies[x][0] -= calc_player_formula(skill_id, $enemies[x][8]) if $enemies[x][4] == 1}
          else
            $enemies[enemy_num][0] -= calc_player_formula(skill_id, enemy_id)
          end
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
        if switch == 0 && $game_actors[actor_id].mp != $game_actors[actor_id].mmp
          $game_player.animation_id = $skills[skill][5]
          $game_actors[actor_id].mp += calc_player_formula(skill_id, 0)
        elsif switch == 1
          $game_map.events[$enemies[enemy_num][8]].animation_id = $enemies[enemy_num][2]
          $enemies[enemy_num][1] += calc_enemy_formula(skill_id, enemy_id)
        end
      elsif skill_type == 5 #"HP Drain"
        
      elsif skill_type == 6 #"MP Drain"
      
      end
      if switch == 0
        $game_map.events[$enemies[enemy_num][8]].animation_id = $skills[skill][5] if skill_type != 3 && skill_type != 4 && skill_scope != 2
        $game_actors[actor_id].mp -= skill_cost
      elsif switch == 1
        $game_player.animation_id = $enemies[enemy_num][2] if skill_type != 3 && skill_type != 4
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
      elsif skill_id == 68
        $skills[equip_slot] = [skill_id, 0, 0, 0, 600, 74, 0]
      end
    end
  end
  
  def self.set_attack_skill
    skill = weapon_skill
    set_skill(0, skill[0])
    $skills[0][4] = calc_cooldown($game_actors[$game_party.leader.id].agi)
    $skills[0][5] = skill[1]
  end
  
  def self.weapon_skill
    #[skill_id, hit_anim]
    return [1,112]
  end
  
  def self.use_player_skill(skill, enemy_num, enemy_id, event_id)
    if $skills[skill][6] == 0 && $skills[skill][0] != 0 && $data_skills[$skills[skill][0]].mp_cost <= $game_actors[$game_party.leader.id].mp
      if range($skills[skill][1],0,$skills[skill][2],$skills[skill][3],event_id)
        calc_damage(skill, enemy_num, enemy_id)
        color = Color.new(20,20,200,100)
        $game_map.screen.start_flash(color, 15)
        $skills.each_index {|x| $skills[x][6] = 40 if $skills[x][6] < 40}
        $skills[skill][6] = $skills[skill][4]
      end
    end
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
    MBS.update
  end
  
  alias update_fraga_mbs update
  def update
    update_fraga_mbs
	  MBS.update
  end
  
  alias terminate_fraga_mbs pre_terminate
  def pre_terminate
    terminate_fraga_mbs
  end
end
