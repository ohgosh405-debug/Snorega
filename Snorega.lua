addon.name = 'Snorega';
addon.author = 'Afoofa';
addon.version = '1.0.3';
addon.desc = 'Player-started, display-only Sleepga timer for HorizonXI.';
addon.link = 'https://github.com/ohgosh405-debug/Snorega';

require('common');

local fonts = require('fonts');
local settings = require('settings');

local colors = T{
    idle = 0xFFB7C5D6,
    sleeping = 0xFF55D6FF,
    countdown = 0xFFFFD369,
    nuke = 0xFFFFB347,
    sleep_now = 0xFFFF667A,
    expired = 0xFFFF667A,
};

local defaults = T{
    sleep_duration = 60.0,
    countdown_remaining = 40.0,
    nuke_remaining = 37.0,
    sleep_delay = 5.5,
    font = T{
        visible = true,
        font_family = 'Arial',
        font_height = 16,
        color = colors.idle,
        position_x = 520,
        position_y = 260,
        background = T{
            visible = true,
            color = 0xD9081018,
        },
    },
};

local sn = T{
    config = settings.load(defaults),
    font = nil,
    cycle_end = nil,
    cycle_number = 0,
    nuke_call_at = nil,
    sleep_due_at = nil,
    alerts = T{},
};

local function now()
    return os.clock();
end

local function normalize(value)
    return string.lower(tostring(value or ''));
end

local function chat(message)
    print(string.format('[Snorega] %s', message));
end

local function clear_timer()
    sn.cycle_end = nil;
    sn.nuke_call_at = nil;
    sn.sleep_due_at = nil;
    sn.alerts = T{};
end

local function start_cycle(duration)
    local length = tonumber(duration) or sn.config.sleep_duration;
    if (length < 10.0 or length > 180.0) then
        chat('Duration must be between 10 and 180 seconds.');
        return;
    end

    clear_timer();
    sn.cycle_number = sn.cycle_number + 1;
    sn.cycle_end = now() + length;
    chat(string.format('Manual timer %d started for %.1f seconds.', sn.cycle_number, length));
end

local function start_nuke_timer()
    local current = now();
    sn.nuke_call_at = current;
    sn.sleep_due_at = current + sn.config.sleep_delay;
    sn.alerts.sleep_two = false;
    sn.alerts.sleep_one = false;
    sn.alerts.sleep_now = false;
    chat(string.format('Manual NUKE marker started. Begin Sleepga in %.1f seconds.', sn.config.sleep_delay));
end

local function remaining(current)
    if (sn.cycle_end == nil) then
        return nil;
    end
    return sn.cycle_end - current;
end

local function alert_once(key, condition, message)
    if (condition and not sn.alerts[key]) then
        sn.alerts[key] = true;
        chat(message);
    end
end

local function update_alerts(current)
    local left = remaining(current);
    if (left ~= nil) then
        alert_once('three', left <= sn.config.countdown_remaining, '3');
        alert_once('two', left <= sn.config.countdown_remaining - 1.0, '2');
        alert_once('one', left <= sn.config.countdown_remaining - 2.0, '1');

        if (left <= sn.config.nuke_remaining and not sn.alerts.nuke) then
            sn.alerts.nuke = true;
            chat('>>> NUKE <<<');

            -- This is calculated only from the timer the player started.
            -- No spell, player, party, chat, or packet data is observed.
            if (sn.nuke_call_at == nil) then
                sn.nuke_call_at = current;
                sn.sleep_due_at = current + sn.config.sleep_delay;
            end
        end

        alert_once('expired', left <= 0.0,
            'Timer expired. Start the next timer manually after Sleepga lands.');
    end

    if (sn.sleep_due_at ~= nil) then
        local until_sleep = sn.sleep_due_at - current;
        alert_once('sleep_two', until_sleep <= 2.0, 'Prepare Sleepga - 2');
        alert_once('sleep_one', until_sleep <= 1.0, 'Prepare Sleepga - 1');
        alert_once('sleep_now', until_sleep <= 0.0, '>>> BEGIN SLEEPGA NOW <<<');
    end
end

local function display_state(current)
    local left = remaining(current);

    if (left == nil and sn.sleep_due_at == nil) then
        return 'WAITING', 'Use /sn start after Sleepga lands.', colors.idle;
    end

    if (sn.sleep_due_at ~= nil) then
        local due = sn.sleep_due_at - current;
        if (due <= 0.0) then
            return 'BEGIN SLEEPGA NOW', string.format('Manual timer overdue by %.1fs', math.abs(due)), colors.sleep_now;
        end
        if (due <= 2.0) then
            return 'PREPARE SLEEPGA', string.format('Begin cast in %.1fs', due), colors.sleep_now;
        end
    end

    if (left ~= nil and left <= 0.0) then
        return 'TIMER EXPIRED', 'Manual restart required.', colors.expired;
    end

    if (left ~= nil and left <= sn.config.nuke_remaining) then
        local due = sn.sleep_due_at and math.max(0.0, sn.sleep_due_at - current) or sn.config.sleep_delay;
        return 'NUKE WINDOW', string.format('Begin Sleepga in %.1fs', due), colors.nuke;
    end

    if (left ~= nil and left <= sn.config.countdown_remaining) then
        return 'NUKE COUNTDOWN', string.format('NUKE in %.1fs', math.max(0.0, left - sn.config.nuke_remaining)), colors.countdown;
    end

    return 'MOBS SLEEPING', string.format('NUKE countdown in %.1fs',
        math.max(0.0, (left or 0.0) - sn.config.countdown_remaining)), colors.sleeping;
end

local function status_text(current)
    local left = remaining(current);
    local state, instruction, color = display_state(current);
    local timer_text = left and string.format('%.1fs', math.max(0.0, left)) or '--.-s';

    if (sn.font ~= nil) then
        sn.font.color = color;
    end

    return table.concat(T{
        'SNOREGA  |  MANUAL SLEEP TIMER',
        '--------------------------------',
        string.format('%-18s %8s', state, timer_text),
        instruction,
        'Target the highest-HP mob before sleeping.',
        '--------------------------------',
        'Manual only  |  /sn help  |  by Afoofa',
    }, '\n');
end

local function print_help()
    chat('Every timer requires a player command. Nothing is detected automatically.');
    chat('/sn start [seconds] - start a manual sleep timer (default 60)');
    chat('/sn nuke            - manually start the 5.5s nuke-to-Sleepga timer');
    chat('/sn stop            - stop and clear the timer');
    chat('/sn show | hide     - show or hide the overlay');
    chat('/sn duration <secs> - set the default duration (10-180)');
    chat('/sn delay <seconds> - set the nuke-to-Sleepga delay (1-15)');
    chat('/sn unload          - unload Snorega and remove it from the screen');
end

ashita.events.register('load', 'snorega_load', function()
    sn.font = fonts.new(sn.config.font);
    settings.register('settings', 'snorega_settings', function(updated)
        if (updated ~= nil) then
            sn.config = updated;
            if (sn.font ~= nil) then
                sn.font:apply(sn.config.font);
            end
        end
    end);

    chat('Snorega v1.0.3 loaded - created by Afoofa.');
    chat('Manual timer only: use /sn start after Sleepga lands. /sn help');
end);

ashita.events.register('command', 'snorega_command', function(e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end

    local root = normalize(args[1]);
    if (root ~= '/sn' and root ~= '/snorega') then
        return;
    end
    e.blocked = true;

    local command = normalize(args[2] or 'help');
    if (command == 'start') then
        start_cycle(tonumber(args[3]) or sn.config.sleep_duration);
    elseif (command == 'nuke') then
        start_nuke_timer();
    elseif (command == 'stop' or command == 'reset') then
        clear_timer();
        chat('Timer stopped. The next timer must be started manually.');
    elseif (command == 'show') then
        sn.config.font.visible = true;
        settings.save();
        chat('Overlay shown.');
    elseif (command == 'hide') then
        sn.config.font.visible = false;
        settings.save();
        chat('Overlay hidden. Use /sn show to restore it.');
    elseif (command == 'duration' and tonumber(args[3]) ~= nil) then
        local value = tonumber(args[3]);
        if (value >= 10.0 and value <= 180.0) then
            sn.config.sleep_duration = value;
            settings.save();
            chat(string.format('Default duration set to %.1f seconds.', value));
        else
            chat('Duration must be between 10 and 180 seconds.');
        end
    elseif (command == 'delay' and tonumber(args[3]) ~= nil) then
        local value = tonumber(args[3]);
        if (value >= 1.0 and value <= 15.0) then
            sn.config.sleep_delay = value;
            settings.save();
            chat(string.format('Manual nuke-to-Sleepga delay set to %.1f seconds.', value));
        else
            chat('Delay must be between 1 and 15 seconds.');
        end
    elseif (command == 'unload') then
        chat('Unloading Snorega. Good night! - Afoofa');
        AshitaCore:GetChatManager():QueueCommand(-1, '/addon unload Snorega');
    else
        print_help();
    end
end);

ashita.events.register('d3d_present', 'snorega_present', function()
    if (sn.font == nil) then
        return;
    end

    local current = now();
    update_alerts(current);
    sn.font.text = status_text(current);
    sn.font.visible = sn.config.font.visible;

    if (sn.font.position_x ~= sn.config.font.position_x or
        sn.font.position_y ~= sn.config.font.position_y) then
        sn.config.font.position_x = sn.font.position_x;
        sn.config.font.position_y = sn.font.position_y;
        settings.save();
    end
end);

ashita.events.register('unload', 'snorega_unload', function()
    if (sn.font ~= nil) then
        sn.font:destroy();
        sn.font = nil;
    end
    settings.save();
end);

