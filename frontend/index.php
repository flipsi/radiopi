<?php

/////////////////////////////////////
// CONFIGURATION BLOCK STARTS HERE //
/////////////////////////////////////

// Path to backend (radio.sh script)
define("PATH_TO_RADIO_SCRIPT", "/opt/radio");

// On some hosts, volume should be managed separately from this application.
// This is especially relevant until https://github.com/sflip/radiopi/issues/2 is fixed.
define("NO_VOLUME_HOSTS", ["idefix"]);


// NOTE that the webserver user needs permissions to access audio, e.g. on Arch Linux be part of the `audio` group.

// NOTE that this may be a private tmp dir of the webserver (see README)
define("LOGFILE", "/tmp/radiopi_frontend.log");

$volume_step = 10;


///////////////////////////////////
// CONFIGURATION BLOCK ENDS HERE //
///////////////////////////////////


$logfile_handler = fopen(LOGFILE, 'a'); // 'a' means append mode

$hostname = gethostname();

$hide_volume_controls = in_array($hostname, NO_VOLUME_HOSTS);


function write_log($log_msg) {
    global $logfile_handler;
    fwrite($logfile_handler, date('[d-M-Y H:i:s]') . ' ' . $log_msg . "\n");
}

$errors = array();

function exec_radio_script($arguments, &$output, &$exit_code) {
    global $errors;
    $cmd = PATH_TO_RADIO_SCRIPT . ' ' . $arguments . ' 2>&1';
    write_log("Executing command: $cmd");
    exec($cmd, $output, $exit_code);
    write_log("... exit code was: " . $exit_code);
    write_log("... output was: " . print_r($output, true));
    if ($exit_code > 0) {
        $errors = array_merge($errors, $output);
    }
}

function parse_radio_status($radio_status_output) {
    $radio_status = array(
        'Status' => 'off',
        'Alarm' => 'disabled',
        'Timer' => 'disabled',
        'Volume' => '100',
        'Alarm list' => array(),
    );
    foreach ($radio_status_output as $line) {
        $split = explode(': ', $line, 2);
        if (count($split) === 2) {
            $key = $split[0];
            $value = $split[1];
            if (strpos($key, 'Alarm ID') === 0) {
                // value looks like: "7:0 (1-5) Station: random"
                preg_match('/(.*) Station: (.*)/', $value, $matches);
                $radio_status['Alarm list'][] = array(
                    'id' => substr($key, 9),
                    'status' => $matches[1],
                    'station' => $matches[2]
                );
                $radio_status['Alarm'] = 'enabled';
            } else {
                $radio_status[$key] = $value;
            }
        }
    }
    return $radio_status;
}

header("Cache-Control: no-cache, no-store, must-revalidate"); // HTTP 1.1.
header("Pragma: no-cache"); // HTTP 1.0.
header("Expires: 0"); // Proxies.


if (!empty($_POST['action'])) {
    $action = $_POST['action'];
    switch ($action) {
        case 'start_playback':
            $station = $_POST['station'];
            exec_radio_script("--non-interactive start '$station' >/dev/null", $action_output, $action_exit_code);
            break;
        case 'stop_playback':
            exec_radio_script('stop', $action_output, $action_exit_code);
            break;
        case 'volume_set':
            $volume_value = $_POST['volume_value'];
            exec_radio_script("volume $volume_value >/dev/null", $action_output, $action_exit_code);
            break;
        case 'volume_down':
            exec_radio_script("volume -$volume_step >/dev/null", $action_output, $action_exit_code);
            break;
        case 'volume_up':
            exec_radio_script("volume +$volume_step >/dev/null", $action_output, $action_exit_code);
            break;
        case 'enable_timer':
            preg_match('/(\d+)/', $_POST['timerduration'], $timerduration_matches);
            $duration = $timerduration_matches[1];
            exec_radio_script("sleep $duration", $action_output, $action_exit_code);
            break;
        case 'disable_timer':
            exec_radio_script("nosleep", $action_output, $action_exit_code);
            break;
        case 'enable_alarm':
            preg_match('/(\d\d):(\d\d)/', $_POST['alarmtime'], $alarmtime_matches);
            preg_match('/(\d+)/', $_POST['alarmduration'], $alarmduration_matches);
            $hour = $alarmtime_matches[1];
            $minute = $alarmtime_matches[2];
            $duration = $alarmduration_matches[1];
            $days = '*';
            if (!empty($_POST['alarmdays'])) {
                if (count($_POST['alarmdays']) < 7) {
                    $days = implode(',', $_POST['alarmdays']);
                }
            }
            $station = isset($_POST['alarmstation']) ? $_POST['alarmstation'] : '';
            exec_radio_script("enable $hour $minute $duration '$days' '$station'", $action_output, $action_exit_code);
            break;
        case 'disable_alarm':
            $id = isset($_POST['id']) ? $_POST['id'] : '';
            exec_radio_script("disable $id", $action_output, $action_exit_code);
            break;
        default:
    }
    // prevent form resubmission with PRG pattern
    if (empty($errors)) {
        unset($_POST);
        $fragment = '';
        if ($action === 'enable_alarm' || $action === 'disable_alarm') {
            $fragment = '#alarm_list';
        }
        header('Location: ' . $_SERVER['PHP_SELF'] . $fragment);
        exit;
    }
}


exec_radio_script('status', $radio_status_output, $radio_status_exit_code);
$radio_status = parse_radio_status($radio_status_output);

$default_module = $radio_status['Status'] == 'off' && $radio_status['Alarm'] == 'enabled' ? 'alarm_list' : 'radio';

?>

<!DOCTYPE html>
<html>
    <head>

        <meta charset="UTF-8" />
        <meta http-equiv="content-type" content="text/html; charset=utf-8">
        <meta name="author" content="sflip">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">

        <link rel="manifest" href="radiopi.webmanifest">

        <link rel="icon" type="image/png" href="radiopi-icon-64.png"/>

        <link rel="preconnect" href="https://fonts.gstatic.com">
        <link href="https://fonts.googleapis.com/css2?family=Krona+One&display=swap" rel="stylesheet">
        <link href="https://fonts.googleapis.com/css?family=Material+Icons" rel="stylesheet">
        <link rel="stylesheet" href="./style.css">
        <link rel="stylesheet" href="./colors.css">

        <script type="text/javascript" src="./main.js"></script>

        <title>radiopi</title>

    </head>
    <body>

        <?php if (!empty($errors)) { ?>
            <div class="errors">
                <div>A server error occurred!</div>
                <?php foreach ($errors as $error) {
                    echo "<div>$error</div>";
                } ?>
            </div>
        <?php } ?>

        <nav>
            <span class="navlink radio <?php echo $default_module === 'radio' ? 'active' : ''; ?>">
                <span class="material-icons">radio</span>
                <div class="label">Radio</div>
            </span>
            <span class="navlink alarm_list <?php echo $default_module === 'alarm' ? 'active' : ''; ?>">
                <span class="material-icons">alarm_on</span>
                <div class="label">Alarms</div>
            </span>
            <span class="navlink alarm_add">
                <span class="material-icons">alarm_add</span>
                <div class="label">Add</div>
            </span>
            <span class="navlink info">
                <span class="material-icons">info</span>
                <div class="label">Info</div>
            </span>
        </nav>

        <main>

        <div class="module radio <?php echo $default_module === 'radio' ? 'active' : ''; ?>">

        <?php

            if ($radio_status['Status'] === 'on') {

        ?>

            <div class="block currently_playing">
                <h2>Currently playing:</h2>
                <div class="station"><?php echo $radio_status['Station']; ?></div>
            </div>
            <div class="block equaliser-container">
            <?php for ($i = 0; $i < 24; $i++) { ?>
                <ol class="equaliser-column">
                    <li class="colour-bar"></li>
                </ol>
            <?php } ?>
            </div>
            <div class="block radiocontrols align-right">
                <form name="stop_playback_form" action="" method="post">
                    <input type="hidden" name="action" value="stop_playback" />
                    <div class="submit">
                        <span class="material-icons playbackbutton">stop</span>
                        Stop playback
                    </div>
                </form>
            </div>
            <div class="block spread radiocontrols <?php echo $hide_volume_controls ? "hidden" : ""; ?>">
                Volume:
                <div class="slidecontainer">
                    <form class="inline" name="volume_slider_form" action="" method="post">
                        <input type="hidden" name="action" value="volume_set" />
                        <input type="range"
                            name="volume_value"
                            min="0"
                            max="200"
                            step="<?php echo $volume_step; ?>"
                            value="<?php echo $radio_status['Volume']; ?>"
                            onmouseup="this.form.submit()"
                            onkeyup="this.form.submit()"
                            ontouchend="this.form.submit()">
                    </form>
                </div>
            </div>
            <div class="block timer">

                <h2>Sleep Timer</h2>

                <form name="timer_form" action="" method="post">

                <?php if ($radio_status['Timer'] === 'enabled') { ?>

                    <div class="block">
                        Radio stops at
                        <span class="time"><?php echo $radio_status['Timer set to']; ?></span>.
                    </div>
                    <div class="align-right">
                        <div class="submit">
                            <input type="hidden" name="action" value="disable_timer" />
                            <span class="material-icons playbackbutton">close</span>
                            Disable timer
                        </div>
                    </div>

                <?php } else { ?>

                    <div class="block spread">
                        <label for="alarmtime">Duration in minutes:</label>
                        <input type="number" min="1" max="250" id="timerduration" name="timerduration" value="30" />
                    </div>
                    <div class="align-right">
                        <div class="submit">
                            <input type="hidden" name="action" value="enable_timer" />
                            <span class="material-icons playbackbutton">done</span>
                            Set timer
                        </div>
                    </div>

                <?php } ?>

                </form>

            </div>

        <?php

            } else {

                exec_radio_script('list', $radio_station_list, $radio_station_list_exit_code);

        ?>

            <div class="block radiostatus">

                <h2>Radio stations:</h2>

                <?php if ($radio_station_list_exit_code > 0 || sizeof($radio_station_list) === 0) {
                    echo "Sorry, could not get any station.";
                } else { ?>
                    <form onsubmit="return false;">
                        <input type="text" name="filter" id="stationfilter" placeholder="Search" />
                    </form>
                    <form name="start_playback_form" action="" method="post">
                        <input type="hidden" name="action" value="start_playback" />
                        <input type="hidden" name="station" id="stationinput" />
                        <ul id='stationlist'>
                        <?php foreach ($radio_station_list as $station) { ?>
                        <li class="stationlink">
                            <span class="material-icons playbackbutton">play_circle_outline</span>
                            <span class="station"><?php echo $station; ?></span>
                        </li>
                        <?php } ?>
                        </ul>
                    </form>
                <?php } ?>
            </div>
        <?php

            }

        ?>

        </div>

        <div class="module alarm_list <?php echo $default_module === 'alarm' ? 'active' : ''; ?>">

        <?php if ($radio_status['Alarm'] === 'enabled') { ?>

            <h2>Active Alarms</h2>

            <?php
                $days_map = array(
                    '1' => 'Mon', '2' => 'Tue', '3' => 'Wed', '4' => 'Thu', '5' => 'Fri', '6' => 'Sat', '0' => 'Sun', '*' => 'Every day'
                );

                foreach ($radio_status['Alarm list'] as $alarm) {
                    // $alarm['status'] looks like "7:0 (1-5)"
                    preg_match('/(.*) \((.*)\)/', $alarm['status'], $matches);
                    $time = $matches[1];
                    $days_raw = $matches[2];
                    $days_formatted = array();
                    foreach (explode(',', $days_raw) as $part) {
                        if (isset($days_map[$part])) {
                            $days_formatted[] = $days_map[$part];
                        } else {
                            $days_formatted[] = $part; // Fallback for ranges like 1-5
                        }
                    }
                    $days_str = implode(', ', $days_formatted);
            ?>
                <form class="active-alarm" name="alarm_disable_form_<?php echo $alarm['id']; ?>" action="" method="post">
                    <input type="hidden" name="action" value="disable_alarm" />
                    <input type="hidden" name="id" value="<?php echo $alarm['id']; ?>" />
                    <div class="block spread active-alarm-row">
                        <div class="status">
                            <span class="time"><?php echo $time; ?></span>
                            <div class="days-label"><?php echo $days_str; ?></div>
                            <div class="station-label">Station: <?php echo $alarm['station']; ?></div>
                        </div>
                        <div class="submit">
                            <span class="material-icons playbackbutton">close</span>
                            Disable
                        </div>
                    </div>
                </form>
            <?php } ?>

            <div class="block disable-all-container align-right">
                <form name="disable_all_alarms_form" action="" method="post">
                    <input type="hidden" name="action" value="disable_alarm" />
                    <div class="submit">
                        <span class="material-icons playbackbutton">delete_sweep</span>
                        Disable all alarms
                    </div>
                </form>
            </div>

        <?php } else { ?>

            <div class="block status">
                No alarms set.
            </div>

        <?php } ?>
        </div>

        <div class="module alarm_add">

        <h2>Add new alarm</h2>

        <form name="alarm_form" action="" method="post">
            <div class="block spread">
                <label for="alarmtime">Alarm time:</label>
                <input type="time" id="alarmtime" name="alarmtime" value="08:00" />
            </div>
            <div class="block spread">
                <label for="alarmduration">Duration in minutes:</label>
                <input type="number" min="1" max="150" id="alarmduration" name="alarmduration" value="60" />
            </div>
            <div class="block spread">
                <label for="alarmstation">Station:</label>
                <select id="alarmstation" name="alarmstation">
                    <option value="">Random</option>
                    <?php
                        exec_radio_script('list', $stations_for_alarm, $stations_exit_code);
                        foreach ($stations_for_alarm as $station) {
                            echo "<option value='$station'>$station</option>";
                        }
                    ?>
                </select>
            </div>
            <div class="block">
                <label>Days:</label>
                <div class="day-selectors">
                    <?php
                        $days_map = array(
                            '1' => 'Mon',
                            '2' => 'Tue',
                            '3' => 'Wed',
                            '4' => 'Thu',
                            '5' => 'Fri',
                            '6' => 'Sat',
                            '0' => 'Sun'
                        );
                        foreach ($days_map as $value => $label) {
                            echo "<div class='day-selector'><label for='day$value'>$label</label><input type='checkbox' id='day$value' name='alarmdays[]' value='$value' checked /></div>";
                        }
                    ?>
                </div>
            </div>
            <div class="block align-right">
                <div class="submit">
                    <input type="hidden" name="action" value="enable_alarm" />
                    <span class="material-icons playbackbutton">done</span>
                    Set alarm
                </div>
            </div>

            <div class="block">
                <p>
                The alarm will start at low volume, which will increase over time.
                </p><p>
                The alarm will start with the specified radio station, or a random one if "Random" is selected.
                </p>
            </div>

        </form>
        </div>

        <div class="module info">
            <div class="info-module">
                <h2>radiopi</h2>
                <p>
                    <em>
                        <a href="https://github.com/flipsi/radiopi">radiopi</a>
                    </em>
                    can play web radio.
                </p>
                <p>
                    Made with love by <a href="https://philippmoers.de">Flipsi</a>.
                </p>
                <p>
                    Hosted on <em><?php echo $hostname; ?></em>.
                </p>
            </div>
        </div>

        </main>

        <footer></footer>

    </body>
</html>


<?php

fclose($logfile_handler);

?>
