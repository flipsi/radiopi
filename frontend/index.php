<?php

/////////////////////////////////////
// CONFIGURATION BLOCK STARTS HERE //
/////////////////////////////////////

// Path to backend (radio.sh script)
define("PATH_TO_RADIO_SCRIPT", "/home/sflip/bin/radio");

// On some hosts, volume should be managed separately from this application.
// This is especially relevant until https://github.com/sflip/radiopi/issues/2 is fixed.
define("NO_VOLUME_HOSTS", ["idefix"]);


// NOTE that the webserver user needs permissions to access audio, e.g. on Arch Linux be part of the `audio` group.

// NOTE that for using the real /tmp, we would have to add `PrivateTmp=no` to /usr/lib/systemd/system/nginx.service.
// Otherwise a magically created systemd directory /tmp/systemd-private-*-httpd.service-* is used.
// See https://stackoverflow.com/questions/55014399/why-doesnt-php-7-2-fopen-tmp-a-write-to-the-file/55016941#55016941
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
    $radio_status = array();
    foreach ($radio_status_output as $line) {
        $split = explode(': ', $line, 2);
        $radio_status[$split[0]] = $split[1];
    }
    return $radio_status;
}


if (!empty($_POST['action'])) {
    switch ($_POST['action']) {
        case 'start_playback':
            $station = $_POST['station'];
            exec_radio_script("--non-interactive start '$station' >/dev/null", $action_output, $action_exit_code);
            break;
        case 'stop_playback':
            exec_radio_script('stop', $action_output, $action_exit_code);
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
            exec_radio_script("enable $hour $minute $duration", $action_output, $action_exit_code);
            break;
        case 'disable_alarm':
            exec_radio_script("disable", $action_output, $action_exit_code);
            break;
        default:
    }
    // prevent form resubmission with PRG pattern
    if (empty($errors)) {
        unset($_POST);
        header('Location: ' . $_SERVER['PHP_SELF']);
        exit;
    }
}


exec_radio_script('status', $radio_status_output, $radio_status_exit_code);
$radio_status = parse_radio_status($radio_status_output);

$default_module = $radio_status['Status'] == 'off' && $radio_status['Alarm'] == 'enabled' ? 'alarm' : 'radio';

header("Cache-Control: no-cache, no-store, must-revalidate"); // HTTP 1.1.
header("Pragma: no-cache"); // HTTP 1.0.
header("Expires: 0"); // Proxies.

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
                <div class="label">
                    Radio
                </div>
            </span>
            <span class="navlink alarm <?php echo $default_module === 'alarm' ? 'active' : ''; ?>">
                <span class="material-icons">alarm</span>
                <div class="label">
                    Alarm
                </div>
            </span>
        </nav>

        <main>

        <div class="module radio <?php echo $default_module === 'radio' ? 'active' : ''; ?>">

        <?php

            if ($radio_status['Status'] === 'on') {

        ?>

            <div class="block radiostatus">
                Currently playing:
                <div class="title"><?php echo $radio_status['Station']; ?></div>
            </div>
            <div class="block equaliser-container">
            <?php for ($i = 0; $i < 9; $i++) { ?>
                <ol class="equaliser-column">
                    <li class="colour-bar"></li>
                </ol>
            <?php } ?>
            </div>
            <div class="block radiocontrols">
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
                <form class="inline" name="volume_down_form" action="" method="post">
                    <input type="hidden" name="action" value="volume_down" />
                    <span class="submit">
                        <span class="material-icons playbackbutton">volume_down</span>
                        down
                    </span>
                </form>
                <form class="inline" name="volume_up_form" action="" method="post">
                    <input type="hidden" name="action" value="volume_up" />
                    <span class="submit">
                        <span class="material-icons playbackbutton">volume_up</span>
                        up
                    </span>
                </form>
            </div>
            <div class="block timer">
                <div class="block title">
                    Sleep Timer
                </div>

                <form name="timer_form" action="" method="post">

                <?php if ($radio_status['Timer'] === 'enabled') { ?>

                    <div class="block">
                        Radio stops at
                        <span class="time"><?php echo $radio_status['Timer set to']; ?></span>.
                    </div>
                    <div class="submit">
                        <input type="hidden" name="action" value="disable_timer" />
                        <span class="material-icons playbackbutton">close</span>
                        Disable timer
                    </div>

                <?php } else { ?>

                    <div class="block spread">
                        <label for="alarmtime">Duration in minutes:</label>
                        <input type="number" min="1" max="250" id="timerduration" name="timerduration" value="30" />
                    </div>
                    <div class="submit">
                        <input type="hidden" name="action" value="enable_timer" />
                        <span class="material-icons playbackbutton">done</span>
                        Set timer
                    </div>

                <?php } ?>

                </form>

            </div>

        <?php

            } else {

                exec_radio_script('list', $radio_station_list, $radio_station_list_exit_code);

        ?>

            <div class="block radiostatus">
                Radio stations:
            </div>
            <div class="block">
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
                            <span class="title"><?php echo $station; ?></span>
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

        <div class="module alarm <?php echo $default_module === 'alarm' ? 'active' : ''; ?>">
        <form name="alarm_form" action="" method="post">

        <?php if ($radio_status['Alarm'] === 'enabled') { ?>

            <div class="block status">
                Alarm is set to
                <span class="time"><?php echo $radio_status['Alarm time']; ?></span>.
            </div>
            <div class="block">
                <input type="hidden" name="action" value="disable_alarm" />
                <div class="submit">
                    <span class="material-icons playbackbutton">close</span>
                    Disable alarm
                </div>
            </div>

        <?php } else { ?>

            <div class="block status">
                Alarm is disabled.
            </div>
            <div class="block spread">
                <label for="alarmtime">Alarm time:</label>
                <input type="time" id="alarmtime" name="alarmtime" value="08:00" />
            </div>
            <div class="block spread">
                <label for="alarmduration">Duration in minutes:</label>
                <input type="number" min="1" max="150" id="alarmduration" name="alarmduration" value="60" />
            </div>
            <div class="block">
                <div class="submit">
                    <input type="hidden" name="action" value="enable_alarm" />
                    <span class="material-icons playbackbutton">done</span>
                    Set alarm
                </div>
            </div>

        <?php } ?>

            <div class="block">
                <p>
                The alarm will start at low volume, which will increase over time.
                </p><p>
                The alarm will start with a random radio station. Picking a certain one is currently not supported.
                </p>
            </div>

        </form>
        </div>

        </main>

        <footer>
            <span>
                <em><a href="https://github.com/sflip/radiopi">radiopi</a></em>
                made by
                <a href="https://philippmoers.de">Flipsi</a>
            </span>
            <span>
                hosted on <em><?php echo $hostname; ?></em>
            </span>
        </footer>

    </body>
</html>


<?php

fclose($logfile_handler);

?>
