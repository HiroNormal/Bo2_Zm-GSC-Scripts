#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;

#define DVAR_PROTECT        1
#define DVAR_PROTECT_LOWER  2
#define DVAR_PROTECT_HIGHER 3

#define FEATURE_FIRSTBOX 1

#define RNG_ROUND 11

#define WEAPON_NAME_MK1  "ray_gun_zm"
#define WEAPON_NAME_MK2  "raygun_mark2_zm"
#define WEAPON_NAME_MONK "cymbal_monkey_zm"
#define WEAPON_NAME_EMP  "emp_grenade_zm"

#define COL_RED    "^1"
#define COL_YELLOW "^3"
#define COL_WHITE  "^7"
#define COLOR_TXT(__txt, __color) __color + __txt + COL_WHITE

#define LEVEL_ENDON         level endon("end_game");
#define PLAYER_ENDON        LEVEL_ENDON self endon("disconnect");
#define MS_TO_SECONDS(__ms) int(__ms / 1000)
#define CLEAR(__var)        __var = undefined;

init()
{
    if (!isdefined(level.b2t_sniff))
        level.b2t_sniff = 0;

    thread protect_file();
    thread on_player_connected();
    init_b2t_dvars();

    thread post_init();
}

post_init()
{
    LEVEL_ENDON

    flag_wait("initial_blackscreen_passed");

    thread create_timers();
    thread timers_main_loop();
    init_b2_box();
}

on_player_connected()
{
    LEVEL_ENDON

    while (true)
    {
        level waittill("connected", player);
        player thread on_player_spawned();
    }
}

on_player_spawned()
{
    PLAYER_ENDON

    self waittill("spawned_player");


    if (!did_game_just_start())
        self waittill_any_array(array("spawned_player", "start_of_round"));

    flag_wait("initial_players_connected");
}

init_b2t_dvars()
{
    LEVEL_ENDON

    dvars = dvar_config();
    for (i = 0; i < dvars.size; i++)
        set_dvar_internal(dvars[i]);

    thread dvar_scanner(dvars);
}

dvar_config()
{
    dvars = [];

    dvars[dvars.size] = register_dvar("sv_cheats",                   "0",     DVAR_PROTECT,       false);
    dvars[dvars.size] = register_dvar("g_speed",                     "190",   DVAR_PROTECT,       false);
    dvars[dvars.size] = register_dvar("con_gameMsgWindow0MsgTime",   "5",     DVAR_PROTECT_LOWER, false);
    dvars[dvars.size] = register_dvar("sv_endGameIfISuck",           "0",     false,              false);
    dvars[dvars.size] = register_dvar("sv_patch_zm_weapons",         "1",     false,              false);
    dvars[dvars.size] = register_dvar("r_dof_enable",                "0",     false,              true);

#if FEATURE_FIRSTBOX == 1

    dvars[dvars.size] = register_dvar("fb",                          "",      false,              false,     ::firstbox_input);
#endif

    return dvars;
}

register_dvar(dvar, set_value, protected, init_only, on_change)
{
    dvar_data = [];
    dvar_data["name"]         = dvar;
    dvar_data["start_value"]  = set_value;
    dvar_data["is_init_only"] = init_only;
    dvar_data["is_protected"] = protected;
    dvar_data["on_change"]    = on_change;
    return dvar_data;
}

set_dvar_internal(dvar)
{
    if (!isdefined(dvar))
        return;
    if (dvar["is_init_only"] && getdvar(dvar["name"]) != "")
        return;
    setdvar(dvar["name"], dvar["start_value"]);
}

dvar_scanner(dvars)
{
    LEVEL_ENDON

    flag_wait("initial_blackscreen_passed");

    state = [];
    for (i = 0; i < dvars.size; i++)
    {
        if (dvars[i]["is_protected"] || isdefined(dvars[i]["on_change"]))
        {
            if (dvars[i]["is_protected"])
                setdvar(dvars[i]["name"], dvars[i]["start_value"]);

            enabledvarchangednotify(dvars[i]["name"]);
            state[dvars[i]["name"]] = dvars[i]["start_value"];
        }
    }

    while (true)
    {
        for (i = 0; i < dvars.size; i++)
        {
            if (!dvars[i]["is_protected"] && !isdefined(dvars[i]["on_change"]))
                continue;

            current_state = getdvar(dvars[i]["name"]);

            if (isdefined(dvars[i]["on_change"]) && state[dvars[i]["name"]] != current_state)
            {
                callback = dvars[i]["on_change"];
                reset = [[callback]](current_state, dvars[i]["name"]);
                if (reset)
                {
                    setdvar(dvars[i]["name"], dvars[i]["start_value"]);
                    current_state = dvars[i]["start_value"];
                }
            }
            else if (dvars[i]["is_protected"])
            {
                dvar_violation(current_state, state[dvars[i]["name"]], dvars[i]["name"], dvars[i]["is_protected"], dvars[i]["start_value"]);
            }

            state[dvars[i]["name"]] = current_state;
        }
        wait 0.1;
    }
}

dvar_violation(new_value, old_value, dvar, protection_mode, start_value)
{
    if (protection_mode == DVAR_PROTECT_HIGHER)
    {
        norm = normalize_both(new_value, start_value);
        if (norm[0] > norm[1])
            setcheatstate();
    }
    else if (protection_mode == DVAR_PROTECT_LOWER)
    {
        norm = normalize_both(new_value, start_value);
        if (norm[0] < norm[1])
            setcheatstate();
    }
    else if (protection_mode == DVAR_PROTECT && new_value != old_value)
    {
        setcheatstate();
    }
}

normalize_both(numeric1, numeric2, factor)
{
    if (!isdefined(factor))
        factor = 100000;

    number1 = float(numeric1);
    number2 = float(numeric2);

    if (int(number1 * factor) < number1 || int(number2 * factor) < number2)
        return normalize_both(numeric1, numeric2, int(factor / 2));

    return array(int(number1 * factor), int(number2 * factor));
}

protect_file()
{
    wait 0.05;
    level thread sniff();
}

sniff()
{
    LEVEL_ENDON

    level.b2t_sniff++;

    flag_wait("initial_blackscreen_passed");

    if (isdefined(level.b2t_sniff) && level.b2t_sniff > 1)
        duplicate_file();

    CLEAR(level.b2t_sniff)
}

duplicate_file()
{
    iprintln("ONLY ONE ^1B2T ^7SCRIPT CAN RUN AT A TIME!");
    if (level.round_number <= 10)
        level notify("end_game");
}

create_timers()
{
    level.timer_hud = createserverfontstring("big", 1.3);
    level.timer_hud setpoint("TOPRIGHT", "TOPRIGHT", 60, -20);
    level.timer_hud.alpha = 1;
    level.timer_hud settimerup(0);

    level.round_hud = createserverfontstring("big", 1.3);
    level.round_hud setpoint("TOPRIGHT", "TOPRIGHT", 60, -8);
    level.round_hud.alpha = 1;
    level.round_hud settext("0:00");
}

timers_main_loop()
{
    LEVEL_ENDON

    game_start = gettime();

    while (true)
    {
        level waittill("start_of_round");
        round_start = gettime();

        if (isdefined(level.round_hud))
            level.round_hud settimerup(0);

        level waittill("end_of_round");
        round_duration = gettime() - round_start;

        if (isdefined(level.round_hud))
            level.round_hud thread keep_displaying_old_time(round_duration);

        thread show_split(game_start);
    }
}

keep_displaying_old_time(time)
{
    LEVEL_ENDON
    level endon("start_of_round");

    while (true)
    {
        self settimer(MS_TO_SECONDS(time) - 0.1);
        wait 0.25;
    }
}

show_split(start_time)
{
    LEVEL_ENDON

    if (level.round_number % 10 && level.round_number != 255)
        return;

    wait MS_TO_SECONDS(round_pulses());

    timestamp = convert_time(MS_TO_SECONDS((gettime() - start_time)));
    print_scheduler("Round " + level.round_number + " time: ^1" + timestamp);
}

round_pulses()
{
    round_pulse_times = ceil(2 + (1 - min(level.round_number, 100) / 100) * 5);
    time = 500;
    time += (500 * 2) * (round_pulse_times - 1);
    time += 500 + 1000;
    time += 1000;
    return time;
}

print_scheduler(content, player, custom_length)
{
    if (!isdefined(custom_length))
        custom_length = 0;

    if (isdefined(player))
    {
        if (isplayer(player))
        {
            player thread player_print_scheduler(content, custom_length);
            return;
        }
        return;
    }
    foreach (player in level.players)
        player thread player_print_scheduler(content, custom_length);
}

player_print_scheduler(content, custom_length)
{
    self endon("disconnect");
    level endon("end_game");

    for (max_waits = 100; isdefined(self.scheduled_prints) && self.scheduled_prints >= getdvarint("con_gameMsgWindow0LineCount") && max_waits; max_waits--)
        wait 0.05;

    if (isdefined(self.scheduled_prints))
        self.scheduled_prints++;
    else
        self.scheduled_prints = 1;

    self iprintln(content);
    wait getdvarfloat("con_gameMsgWindow0FadeInTime") + getdvarfloat("con_gameMsgWindow0MsgTime") + getdvarfloat("con_gameMsgWindow0FadeOutTime");

    if (isdefined(self.scheduled_prints))
    {
        self.scheduled_prints--;
        if (self.scheduled_prints <= 0)
            self.scheduled_prints = undefined;
    }
}

convert_time(seconds)
{
    hours = 0;
    minutes = 0;

    if (!isdefined(seconds))
        seconds = int(gettime() / 1000);

    seconds = int(seconds);
    hours    = int(seconds / 3600);
    seconds  = seconds % 3600;
    minutes  = int(seconds / 60);
    seconds  = seconds % 60;

    str_hours = hours;
    if (hours < 10)
        str_hours = "0" + hours;

    str_minutes = minutes;
    if (minutes < 10)
        str_minutes = "0" + minutes;

    str_seconds = seconds;
    if (seconds < 10)
        str_seconds = "0" + seconds;

    if (hours == 0)
        return str_minutes + ":" + str_seconds;
    else
        return str_hours + ":" + str_minutes + ":" + str_seconds;
}

init_b2_box()
{
    if (!has_magic())
        return;

    LEVEL_ENDON

    while (!isdefined(level.chests))
    {
        if (!did_game_just_start())
            return;
        wait 0.05;
    }

    level.total_box_hits = 0;
    flag_init("b2_fb_locked");

    array_thread(level.chests, ::watch_box_state);

#if FEATURE_FIRSTBOX == 1
    thread first_box();
#endif
}

watch_box_state()
{
    LEVEL_ENDON

    while (!isdefined(self.zbarrier))
        wait 0.05;

    while (true)
    {
        while (self.zbarrier getzbarrierpiecestate(2) != "opening")
            wait 0.05;

        level.total_box_hits++;

        self.zbarrier waittill("randomization_done");
        wait 0.05;
        level notify("b2_box_restore");
    }
}

first_box()
{
    LEVEL_ENDON

    level.b2_rigged_hits = 0;

    while (!is_round(RNG_ROUND) && !is_true(level.zombie_vars["zombie_powerup_fire_sale_on"]))
        wait 0.1;

    level notify("b2_box_restore");
    flag_set("b2_first_box_terminated");
}

firstbox_input(value, key)
{
    if (!isdefined(level.b2_rigged_hits))
        return true;

    if (value == "" || value == " ")
        return true;

    player = gethostplayer();
    thread rig_box(strtok(value, "|"), player);

    return true;
}

rig_box(guns, player)
{
    LEVEL_ENDON

    if (flag("b2_first_box_terminated"))
        return;

    weapon_key = get_weapon_key(guns[0], ::box_weapon_verification);

    if (level.players.size == 1)
        weapon_key = gethostplayer() player_box_weapon_verification(weapon_key);
    else
        weapon_key = server_box_weapon_verification(weapon_key);

    if (weapon_key == "")
    {
        if (guns.size > 1 && isdefined(level.total_box_hits))
            rig_box(array_shift(guns), player);
        return;
    }

    print_scheduler(COLOR_TXT(player.name, COL_YELLOW) + " set box to: " + COLOR_TXT(weapon_display_wrapper(weapon_key), COL_YELLOW));
    level.b2_rigged_hits++;

    saved_check = level.special_weapon_magicbox_check;
    removed_guns = [];

    flag_set("b2_fb_locked");

    level.special_weapon_magicbox_check = undefined;
    foreach (weapon in getarraykeys(level.zombie_weapons))
    {
        if ((weapon != weapon_key) && is_true(level.zombie_weapons[weapon].is_in_box))
        {
            removed_guns[removed_guns.size] = weapon;
            level.zombie_weapons[weapon].is_in_box = 0;
        }
    }

    level waittill("b2_box_restore");
    wait 0.1;

    level.special_weapon_magicbox_check = saved_check;

    foreach (rweapon in removed_guns)
        level.zombie_weapons[rweapon].is_in_box = 1;

    if (guns.size > 1 && isdefined(level.total_box_hits))
        rig_box(array_shift(guns), player);

    flag_clear("b2_fb_locked");
}

box_weapon_verification(weapon_key)
{
    if (!is_true(level.zombie_weapons[weapon_key].is_in_box))
        return "";
    return weapon_key;
}

player_box_weapon_verification(weapon_key)
{
    if (self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade(weapon_key))
        return "";
    if (!maps\mp\zombies\_zm_weapons::limited_weapon_below_quota(weapon_key, self, getentarray("specialty_weapupgrade", "script_noteworthy")))
        return "";

    switch (weapon_key)
    {
        case WEAPON_NAME_MK1:
            if (self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade(WEAPON_NAME_MK2))
                return "";
        case WEAPON_NAME_MK2:
            if (self maps\mp\zombies\_zm_weapons::has_weapon_or_upgrade(WEAPON_NAME_MK1))
                return "";
    }

    return weapon_key;
}

server_box_weapon_verification(weapon_key)
{
    if (!maps\mp\zombies\_zm_weapons::limited_weapon_below_quota(weapon_key, undefined, getentarray("specialty_weapupgrade", "script_noteworthy")))
        return "";
    return weapon_key;
}

weapon_display_wrapper(weapon_key)
{
    if (weapon_key == WEAPON_NAME_EMP)
        return "Emp Grenade";
    if (weapon_key == WEAPON_NAME_MONK)
        return "Cymbal Monkey";
    return maps\mp\zombies\_zm_weapons::get_weapon_display_name(weapon_key);
}

get_weapon_key(weapon_str, verifier)
{
    switch(weapon_str)
    {
        case "mk1":       key = WEAPON_NAME_MK1; break;
        case "mk2":       key = WEAPON_NAME_MK2; break;
        case "monk":      key = WEAPON_NAME_MONK; break;
        case "emp":       key = WEAPON_NAME_EMP; break;
        case "time":      key = "time_bomb_zm"; break;
        case "sliq":      key = "slipgun_zm"; break;
        case "blunder":   key = "blundergat_zm"; break;
        case "paralyzer": key = "slowgun_zm"; break;
        case "ak47":      key = "ak47_zm"; break;
        case "an94":      key = "an94_zm"; break;
        case "barret":    key = "barretm82_zm"; break;
        case "b23r":      key = "beretta93r_zm"; break;
        case "b23re":     key = "beretta93r_extclip_zm"; break;
        case "dsr":       key = "dsr50_zm"; break;
        case "evo":       key = "evoskorpion_zm"; break;
        case "57":        key = "fiveseven_zm"; break;
        case "257":       key = "fivesevendw_zm"; break;
        case "fal":       key = "fnfal_zm"; break;
        case "galil":     key = "galil_zm"; break;
        case "mtar":      key = "tar21_zm"; break;
        case "hamr":      key = "hamr_zm"; break;
        case "m27":       key = "hk416_zm"; break;
        case "exe":       key = "judge_zm"; break;
        case "kap":       key = "kard_zm"; break;
        case "bk":        key = "knife_ballistic_zm"; break;
        case "ksg":       key = "ksg_zm"; break;
        case "wm":        key = "m32_zm"; break;
        case "mg":        key = "mg08_zm"; break;
        case "lsat":      key = "lsat_zm"; break;
        case "dm":        key = "minigun_alcatraz_zm"; break;
        case "mp40":      key = "mp40_stalker_zm"; break;
        case "pdw":       key = "pdw57_zm"; break;
        case "pyt":       key = "python_zm"; break;
        case "rnma":      key = "rnma_zm"; break;
        case "type":      key = "type95_zm"; break;
        case "rpd":       key = "rpd_zm"; break;
        case "s12":       key = "saiga12_zm"; break;
        case "scar":      key = "scar_zm"; break;
        case "m1216":     key = "srm1216_zm"; break;
        case "tommy":     key = "thompson_zm"; break;
        case "chic":      key = "qcw05_zm"; break;
        case "rpg":       key = "usrpg_zm"; break;
        case "m8":        key = "xm8_zm"; break;
        case "m16":       key = "m16_zm"; break;
        case "remington": key = "870mcs_zm"; break;
        case "oly":
        case "olympia":   key = "rottweil72_zm"; break;
        case "mp5":       key = "mp5k_zm"; break;
        case "ak74":      key = "ak74u_zm"; break;
        case "m14":       key = "m14_zm"; break;
        case "svu":       key = "svu_zm"; break;
        default:          key = weapon_str; break;
    }

    if (!isdefined(verifier))
        verifier = ::default_weapon_verification;

    key = [[verifier]](key);
    return key;
}

default_weapon_verification(weapon_key)
{
    weapon_key = maps\mp\zombies\_zm_weapons::get_base_weapon_name(weapon_key, 1);
    if (!maps\mp\zombies\_zm_weapons::is_weapon_included(weapon_key))
        return "";
    return weapon_key;
}

array_shift(arr)
{
    new_arr = [];
    if (arr.size < 2)
        return new_arr;

    first = true;
    foreach (value in arr)
    {
        if (!first)
            new_arr[new_arr.size] = value;
        first = false;
    }
    return new_arr;
}

has_magic()
{
    return is_true(level.enable_magic);
}

is_mob()
{
    return level.script == "zm_prison";
}

did_game_just_start()
{
    return !isdefined(level.start_round) || !is_round(level.start_round + 2);
}

is_round(rnd)
{
    return rnd <= level.round_number;
}
