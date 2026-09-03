addon.name = 'Snorega';
addon.author = 'Afoofa';
addon.version = '1.0.0';
addon.desc = 'RDM sleep-cycle and BLM nuke timing assistant for HorizonXI.';
addon.link = '';

require('common');

local fonts = require('fonts');
local settings = require('settings');

local defaults = T{
    enabled = true,
    sleep_duration = 60.0,
    countdown_remaining = 40.0,
    nuke_remaining = 37.0,
    sleep_delay = 5.5,
    late_limit = 4.0,
    blm_names = T{},
    font = T{
        visible = true,
        font_family = 'Consolas',
        font_height = 15,
        color = 0xFF65D9FF,
        position_x = 520,
        position_y = 260,
        background = T{
            visible = true,
            color = 0xE0203850,
        },
    },
    info_font = T{
        visible = true,
        can_focus = false,
        locked = true,
        font_family = 'Consolas',
        font_height = 15,
        color = 0xFF67E88A,
        position_x = 520,
        position_y = 280,
        background = T{
            visible = true,
            can_focus = false,
            locked = true,
            color = 0xDC101820,
        },
    },
    timer_font = T{
        visible = true,
        can_focus = false,
        locked = true,
        font_family = 'Consolas',
        font_height = 15,
        color = 0xFFFFFFFF,
        position_x = 520,
        position_y = 300,
        background = T{
            visible = true,
            can_focus = false,
            locked = true,
            color = 0xDC101820,
        },
    },
    action_font = T{
        visible = true,
        can_focus = false,
        locked = true,
        font_family = 'Consolas',
        font_height = 15,
        color = 0xFFFFD75F,
        position_x = 520,
        position_y = 320,
        background = T{
            visible = true,
            can_focus = false,
            locked = true,
            color = 0xE0182028,
        },
    },
    hint_font = T{
        visible = true,
        can_focus = false,
        locked = true,
        font_family = 'Consolas',
        font_height = 15,
        color = 0xFF9AA7B3,
        position_x = 520,
        position_y = 340,
        background = T{
            visible = true,
            can_focus = false,
            locked = true,
            color = 0xDC101820,
        },
    },
};

local sw = T{
    config = settings.load(defaults),
    font = nil,
    info_font = nil,
    timer_font = nil,
    action_font = nil,
    hint_font = nil,
    cycle_end = nil,
    cycle_number = 0,
    nuke_call_at = nil,
    sleep_due_at = nil,
    latest_blm = nil,
    blm_casts = T{},
    alerts = T{},
    sleep_casting = false,
    last_packet_key = nil,
    last_packet_at = 0,
};

local BLM_JOB_ID = 4;
local HASTE_BUFF_ID = 33;
local ACTION_PACKET = 0x028;
local SPELL_FINISH = 4;
local SPELL_BEGIN_OR_INTERRUPT = 8;
local ACTION_BEGIN = 24931;
local ACTION_INTERRUPT = 28787;

local function now()
    return os.clock();
end

local function chat(message)
    print(string.format('[Snorega] %s', message));
end

local function has_haste()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return false;
    end

    local buffs = player:GetBuffs();
    if (buffs == nil) then
        return false;
    end

    for _, buff in pairs(buffs) do
        if (buff == HASTE_BUFF_ID) then
            return true;
        end
    end
    return false;
end

local function normalize_name(name)
    if (name == nil) then
        return '';
    end
    return string.lower(tostring(name));
end

local function configured_blm_name(name)
    local wanted = normalize_name(name);
    for _, configured in ipairs(sw.config.blm_names) do
        if (normalize_name(configured) == wanted) then
            return true;
        end
    end
    return false;
end

local function get_party_member(actor_id)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return nil;
    end

    for slot = 0, 17 do
        local server_id = party:GetMemberServerId(slot);
        if (server_id ~= nil and server_id ~= 0 and server_id == actor_id) then
            return T{
                id = server_id,
                name = party:GetMemberName(slot) or ('Party slot ' .. tostring(slot)),
                main_job = party:GetMemberMainJob(slot),
                slot = slot,
            };
        end
    end
    return nil;
end

local function get_own_id()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return 0;
    end
    return party:GetMemberServerId(0) or 0;
end

local function get_blm_count()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return 0;
    end

    local count = 0;
    local seen = T{};
    for slot = 0, 17 do
        local id = party:GetMemberServerId(slot);
        local name = party:GetMemberName(slot);
        if id ~= nil and id ~= 0 and not seen[id] and
            (party:GetMemberMainJob(slot) == BLM_JOB_ID or configured_blm_name(name)) then
            seen[id] = true;
            count = count + 1;
        end
    end
    return count;
end

local function get_spell_name(spell_id)
    if (spell_id == nil) then
        return nil;
    end
    local spell = AshitaCore:GetResourceManager():GetSpellById(spell_id);
    if (spell == nil or spell.Name == nil) then
        return nil;
    end
    return spell.Name[1];
end

local function is_sleepga(name)
    local value = normalize_name(name);
    return value == 'sleepga' or value == 'sleepga ii';
end

-- Deliberately excludes enfeebles, cures, drains, and buffs. This prevents a
-- BLM casting Stun/Drain/Refresh from shifting the RDM's sleep recommendation.
local function is_elemental_nuke(name)
    local value = normalize_name(name);
    if (value == '') then
        return false;
    end

    local prefixes = T{
        'fire', 'firaga', 'blizzard', 'blizzaga', 'aero', 'aeroga',
        'stone', 'stonega', 'thunder', 'thundaga', 'water', 'waterga',
    };
    for _, prefix in ipairs(prefixes) do
        if (value:sub(1, #prefix) == prefix) then
            return true;
        end
    end

    return value == 'flare' or value == 'freeze' or value == 'tornado' or
        value == 'quake' or value == 'burst' or value == 'flood';
end

-- Minimal parser for the fields used from the standard FFXI 0x028 action
-- packet. Parsing the packet avoids dependence on chat filters or language.
local function parse_action_packet(e)
    if (e == nil or e.data_raw == nil) then
        return nil;
    end

    local offset = 40;
    local function unpack(length)
        local value = ashita.bits.unpack_be(e.data_raw, 0, offset, length);
        offset = offset + length;
        return value;
    end

    local packet = T{};
    packet.actor_id = unpack(32);
    local target_count = unpack(6);
    offset = offset + 4;
    packet.category = unpack(4);
    packet.param = unpack(32);
    offset = offset + 32;

    if (target_count > 0) then
        packet.first_target_id = unpack(32);
        local action_count = unpack(4);
        if (action_count > 0) then
            unpack(5);  -- reaction
            unpack(12); -- animation
            unpack(7);  -- special effect
            unpack(3);  -- knockback
            packet.action_param = unpack(17);
            packet.action_message = unpack(10);
        end
    end
    return packet;
end

local function clear_timing(keep_cycle)
    if (not keep_cycle) then
        sw.cycle_end = nil;
    end
    sw.nuke_call_at = nil;
    sw.sleep_due_at = nil;
    sw.latest_blm = nil;
    sw.blm_casts = T{};
    sw.alerts = T{};
    sw.sleep_casting = false;
end

local function start_cycle(duration)
    local length = tonumber(duration) or sw.config.sleep_duration;
    if (length < 10 or length > 180) then
        chat('Sleep duration must be between 10 and 180 seconds.');
        return;
    end

    clear_timing(false);
    sw.cycle_number = sw.cycle_number + 1;
    sw.cycle_end = now() + length;
    chat(string.format('Sleep cycle %d started (%.1fs). Countdown begins at %.1fs remaining.',
        sw.cycle_number, length, sw.config.countdown_remaining));
end

local function start_nuke_call(call_time)
    if (sw.nuke_call_at ~= nil) then
        return;
    end
    sw.nuke_call_at = call_time or now();
    sw.sleep_due_at = sw.nuke_call_at + sw.config.sleep_delay;
    chat(string.format('NUKE — begin Sleepga in %.1f seconds.', sw.config.sleep_delay));
end

local function observe_blm_cast(member, spell_name, observed_at)
    if (not sw.config.enabled or member == nil or not is_elemental_nuke(spell_name)) then
        return;
    end
    if (member.main_job ~= BLM_JOB_ID and not configured_blm_name(member.name)) then
        return;
    end

    local t = observed_at or now();
    if (sw.cycle_end ~= nil) then
        local remaining = sw.cycle_end - t;
        -- A qualifying nuke before the NUKE call is probably unrelated. A
        -- small tolerance handles frame and network ordering at the boundary.
        if (remaining > (sw.config.nuke_remaining + 0.75) or remaining < 18) then
            return;
        end
    elseif (sw.nuke_call_at == nil) then
        -- Allows use after loading mid-pull: the first observed BLM nuke arms it.
        sw.nuke_call_at = t;
        sw.sleep_due_at = t + sw.config.sleep_delay;
        chat('No sleep cycle was active; timing from the first observed BLM nuke.');
    end

    if (sw.nuke_call_at == nil) then
        start_nuke_call(t);
    end

    local key = normalize_name(member.name);
    if (sw.blm_casts[key] ~= nil) then
        return;
    end
    sw.blm_casts[key] = t;
    sw.latest_blm = member.name;

    local latest_allowed = sw.nuke_call_at + sw.config.late_limit;
    local adjusted_start = math.min(t, latest_allowed);
    local adjusted_due = adjusted_start + sw.config.sleep_delay;
    if (adjusted_due > sw.sleep_due_at) then
        sw.sleep_due_at = adjusted_due;
    end

    local late = math.max(0, t - sw.nuke_call_at);
    chat(string.format('%s starts %s%s — Sleepga in %.1fs.', member.name, spell_name,
        late >= 0.5 and string.format(' (%.1fs late)', late) or '',
        math.max(0, sw.sleep_due_at - t)));
end

local function cycle_remaining(t)
    if (sw.cycle_end == nil) then
        return nil;
    end
    return sw.cycle_end - t;
end

local function threshold_once(key, condition, message)
    if (condition and not sw.alerts[key]) then
        sw.alerts[key] = true;
        chat(message);
    end
end

local function update_alerts(t)
    local remaining = cycle_remaining(t);
    if (remaining ~= nil) then
        threshold_once('three', remaining <= sw.config.countdown_remaining, '3');
        threshold_once('two', remaining <= sw.config.countdown_remaining - 1, '2');
        threshold_once('one', remaining <= sw.config.countdown_remaining - 2, '1');

        if (remaining <= sw.config.nuke_remaining and sw.nuke_call_at == nil) then
            start_nuke_call(t);
        end

        if (remaining <= 0) then
            threshold_once('expired', true, 'WARNING: original sleep duration has expired.');
        end
    end

    if (sw.sleep_due_at ~= nil and not sw.sleep_casting) then
        local until_sleep = sw.sleep_due_at - t;
        threshold_once('sleep_two', until_sleep <= 2.0, 'Prepare Sleepga — 2');
        threshold_once('sleep_one', until_sleep <= 1.0, 'Prepare Sleepga — 1');
        threshold_once('sleep_now', until_sleep <= 0, '>>> CAST SLEEPGA NOW <<<');
    end
end

local COLOR = T{
    cyan = 0xFF65D9FF,
    green = 0xFF67E88A,
    white = 0xFFFFFFFF,
    yellow = 0xFFFFD75F,
    orange = 0xFFFFA94D,
    red = 0xFFFF6262,
    gray = 0xFF9AA7B3,
};

local PANEL_WIDTH = 38;

local function panel_line(value)
    local text = tostring(value or '');
    if (#text > PANEL_WIDTH) then
        text = text:sub(1, PANEL_WIDTH);
    end
    return text .. string.rep(' ', PANEL_WIDTH - #text);
end

local function status_rows(t)
    local hasted = has_haste();
    local remaining = cycle_remaining(t);
    local observed = 0;
    for _ in pairs(sw.blm_casts) do
        observed = observed + 1;
    end
    local expected = get_blm_count();

    local rows = T{
        header = panel_line('[ SNOREGA ]  Created by Afoofa'),
        info = '',
        timer = '',
        action = '',
        hint = panel_line('Target: highest-HP mob before Sleepga'),
        info_color = hasted and COLOR.green or COLOR.red,
        timer_color = COLOR.white,
        action_color = COLOR.cyan,
    };

    if (not sw.config.enabled) then
        rows.info = panel_line('STATUS: OFF');
        rows.timer = panel_line('Timer paused');
        rows.action = panel_line('Use /sn on to enable');
        rows.info_color = COLOR.gray;
        rows.timer_color = COLOR.gray;
        rows.action_color = COLOR.yellow;
        return rows;
    end

    rows.info = panel_line(string.format('HASTE: %-7s  BLM: %d/%d',
        hasted and 'ON' or 'MISSING', observed, expected));

    if (remaining ~= nil) then
        rows.timer = panel_line(string.format('SLEEP REMAINING: %5.1fs', math.max(0, remaining)));
        if (remaining <= sw.config.countdown_remaining) then
            rows.timer_color = COLOR.yellow;
        end
        if (remaining <= 0) then
            rows.timer_color = COLOR.red;
        end
    else
        rows.timer = panel_line('SLEEP TIMER: waiting for Sleepga');
        rows.timer_color = COLOR.gray;
    end

    if (sw.sleep_casting) then
        rows.action = panel_line('CASTING: Sleepga...');
        rows.action_color = COLOR.green;
    elseif (sw.sleep_due_at ~= nil) then
        local due = sw.sleep_due_at - t;
        if (due > 2) then
            rows.action = panel_line(string.format('BEGIN SLEEPGA IN: %.1fs', due));
            rows.action_color = COLOR.yellow;
        elseif (due > 0) then
            rows.action = panel_line(string.format('PREPARE SLEEPGA: %.1fs', due));
            rows.action_color = COLOR.orange;
        else
            rows.action = panel_line(string.format('>>> CAST SLEEPGA NOW <<<  +%.1fs', math.abs(due)));
            -- Flash red/yellow so the instruction is difficult to miss.
            rows.action_color = (math.floor(t * 4) % 2 == 0) and COLOR.red or COLOR.yellow;
        end
    elseif (remaining ~= nil and remaining > sw.config.nuke_remaining) then
        rows.action = panel_line(string.format('NUKE CALL IN: %.1fs', remaining - sw.config.nuke_remaining));
        rows.action_color = COLOR.cyan;
    else
        rows.action = panel_line('WATCHING BLM CASTS...');
        rows.action_color = COLOR.yellow;
    end

    return rows;
end

local function print_help()
    chat('Commands:');
    chat('/sn start [seconds]  - manually start a sleep cycle (default 60)');
    chat('/sn nuke             - manually mark the NUKE call now');
    chat('/sn reset            - clear the current cycle');
    chat('/sn delay <seconds>  - set BLM-start to Sleepga-start delay (default 5.5)');
    chat('/sn duration <secs>  - set the default sleep duration');
    chat('/sn add <name>       - force-track a BLM name; /sn remove <name>');
    chat('/sn blms             - list detected/configured BLMs');
    chat('/sn on | off | help  - older commands remain compatibility aliases');
end

local function list_blms()
    local party = AshitaCore:GetMemoryManager():GetParty();
    local found = T{};
    if (party ~= nil) then
        for slot = 0, 17 do
            local id = party:GetMemberServerId(slot);
            local name = party:GetMemberName(slot);
            if id ~= nil and id ~= 0 and
                (party:GetMemberMainJob(slot) == BLM_JOB_ID or configured_blm_name(name)) then
                found:append(string.format('%s%s', name,
                    party:GetMemberMainJob(slot) == BLM_JOB_ID and ' (BLM)' or ' (manual)'));
            end
        end
    end
    chat(#found > 0 and ('Tracked: ' .. found:concat(', ')) or 'No BLMs detected. Use /sn add Name if needed.');
end

local function ensure_panel_settings(config)
    -- Preserve the user's saved position while migrating the original single
    -- Arial block to the compact v1.1 panel style.
    config.font.font_family = 'Consolas';
    config.font.font_height = 15;
    config.font.background.visible = true;
    config.font.background.color = 0xE0203850;
    config.info_font = config.info_font or defaults.info_font;
    config.timer_font = config.timer_font or defaults.timer_font;
    config.action_font = config.action_font or defaults.action_font;
    config.hint_font = config.hint_font or defaults.hint_font;
    return config;
end

ashita.events.register('load', 'snorega_load', function()
    sw.config = ensure_panel_settings(sw.config);
    sw.font = fonts.new(sw.config.font);
    sw.info_font = fonts.new(sw.config.info_font);
    sw.timer_font = fonts.new(sw.config.timer_font);
    sw.action_font = fonts.new(sw.config.action_font);
    sw.hint_font = fonts.new(sw.config.hint_font);
    settings.register('settings', 'snorega_settings', function(s)
        if (s ~= nil) then
            sw.config = ensure_panel_settings(s);
            if (sw.font ~= nil) then
                sw.font:apply(sw.config.font);
                sw.info_font:apply(sw.config.info_font);
                sw.timer_font:apply(sw.config.timer_font);
                sw.action_font:apply(sw.config.action_font);
                sw.hint_font:apply(sw.config.hint_font);
            end
        end
    end);
    chat('Snorega v1.0.0 loaded - Created by Afoofa.');
    chat('Sleepga completions start the 60s cycle automatically. /sn help');
end);

ashita.events.register('packet_in', 'snorega_packet_in', function(e)
    if (not sw.config.enabled or e.id ~= ACTION_PACKET) then
        return;
    end

    local ok, packet = pcall(parse_action_packet, e);
    if (not ok or packet == nil) then
        return;
    end

    local t = now();
    local packet_key = string.format('%u:%u:%u:%u', packet.actor_id or 0,
        packet.category or 0, packet.param or 0, packet.action_param or 0);
    if (packet_key == sw.last_packet_key and (t - sw.last_packet_at) < 0.2) then
        return;
    end
    sw.last_packet_key = packet_key;
    sw.last_packet_at = t;

    local own_id = get_own_id();
    if (packet.category == SPELL_BEGIN_OR_INTERRUPT and packet.param == ACTION_BEGIN) then
        local spell_name = get_spell_name(packet.action_param);
        if (packet.actor_id == own_id and is_sleepga(spell_name)) then
            sw.sleep_casting = true;
            sw.sleep_due_at = nil;
            chat('Sleepga cast started.');
            return;
        end

        local member = get_party_member(packet.actor_id);
        observe_blm_cast(member, spell_name, t);
        return;
    end

    if (packet.category == SPELL_BEGIN_OR_INTERRUPT and packet.param == ACTION_INTERRUPT and
        packet.actor_id == own_id and sw.sleep_casting) then
        sw.sleep_casting = false;
        chat('Sleepga interrupted — timing cycle was not restarted.');
        return;
    end

    if (packet.category == SPELL_FINISH and packet.actor_id == own_id) then
        local spell_name = get_spell_name(packet.param);
        if (is_sleepga(spell_name)) then
            sw.sleep_casting = false;
            start_cycle(sw.config.sleep_duration);
        end
    end
end);

ashita.events.register('command', 'snorega_command', function(e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end
    local root = normalize_name(args[1]);
    if (root ~= '/sn' and root ~= '/snorega' and root ~= '/ns' and root ~= '/nukeandsnooze' and root ~= '/sw' and root ~= '/sleepwatch') then
        return;
    end
    e.blocked = true;

    local command = normalize_name(args[2] or 'help');
    if (command == 'start') then
        start_cycle(tonumber(args[3]) or sw.config.sleep_duration);
    elseif (command == 'nuke') then
        start_nuke_call(now());
    elseif (command == 'reset') then
        clear_timing(false);
        chat('Cycle cleared.');
    elseif (command == 'on') then
        sw.config.enabled = true;
        settings.save();
        chat('Enabled.');
    elseif (command == 'off') then
        sw.config.enabled = false;
        clear_timing(false);
        settings.save();
        chat('Disabled.');
    elseif (command == 'delay' and tonumber(args[3]) ~= nil) then
        local value = tonumber(args[3]);
        if (value >= 1 and value <= 15) then
            sw.config.sleep_delay = value;
            settings.save();
            chat(string.format('BLM-to-Sleepga delay set to %.1fs.', value));
        else
            chat('Delay must be between 1 and 15 seconds.');
        end
    elseif (command == 'duration' and tonumber(args[3]) ~= nil) then
        local value = tonumber(args[3]);
        if (value >= 10 and value <= 180) then
            sw.config.sleep_duration = value;
            settings.save();
            chat(string.format('Default sleep duration set to %.1fs.', value));
        else
            chat('Duration must be between 10 and 180 seconds.');
        end
    elseif (command == 'add' and args[3] ~= nil) then
        if (not configured_blm_name(args[3])) then
            sw.config.blm_names:append(args[3]);
            settings.save();
        end
        chat(args[3] .. ' added to manual BLM tracking.');
    elseif (command == 'remove' and args[3] ~= nil) then
        local wanted = normalize_name(args[3]);
        for index = #sw.config.blm_names, 1, -1 do
            if (normalize_name(sw.config.blm_names[index]) == wanted) then
                table.remove(sw.config.blm_names, index);
            end
        end
        settings.save();
        chat(args[3] .. ' removed from manual BLM tracking.');
    elseif (command == 'blms') then
        list_blms();
    else
        print_help();
    end
end);

ashita.events.register('d3d_present', 'snorega_present', function()
    if (sw.font == nil or sw.info_font == nil or sw.timer_font == nil or
        sw.action_font == nil or sw.hint_font == nil) then
        return;
    end

    local t = now();
    if (sw.config.enabled) then
        update_alerts(t);
    end
    local rows = status_rows(t);
    local x = sw.font.position_x;
    local y = sw.font.position_y;
    local visible = sw.config.font.visible;

    sw.font.text = rows.header;
    sw.font.color = COLOR.cyan;
    sw.font.visible = visible;

    sw.info_font.position_x = x;
    sw.info_font.position_y = y + 20;
    sw.info_font.text = rows.info;
    sw.info_font.color = rows.info_color;
    sw.info_font.visible = visible;

    sw.timer_font.position_x = x;
    sw.timer_font.position_y = y + 40;
    sw.timer_font.text = rows.timer;
    sw.timer_font.color = rows.timer_color;
    sw.timer_font.visible = visible;

    sw.action_font.position_x = x;
    sw.action_font.position_y = y + 60;
    sw.action_font.text = rows.action;
    sw.action_font.color = rows.action_color;
    sw.action_font.visible = visible;

    sw.hint_font.position_x = x;
    sw.hint_font.position_y = y + 80;
    sw.hint_font.text = rows.hint;
    sw.hint_font.color = COLOR.gray;
    sw.hint_font.visible = visible;

    if (sw.font.position_x ~= sw.config.font.position_x or
        sw.font.position_y ~= sw.config.font.position_y) then
        sw.config.font.position_x = sw.font.position_x;
        sw.config.font.position_y = sw.font.position_y;
        settings.save();
    end
end);

ashita.events.register('unload', 'snorega_unload', function()
    local font_keys = T{'font', 'info_font', 'timer_font', 'action_font', 'hint_font'};
    for _, key in ipairs(font_keys) do
        if (sw[key] ~= nil) then
            sw[key]:destroy();
            sw[key] = nil;
        end
    end
    settings.save();
end);
