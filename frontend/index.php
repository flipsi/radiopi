<?php

define("PATH_TO_RADIO_SCRIPT", "/home/sflip/bin/radio");


// NOTE that the webserver user needs permissions to access audio, e.g. on Arch Linux be part of the `audio` group.

// NOTE that for using the real /tmp, we would have to add `PrivateTmp=no` to /usr/lib/systemd/system/nginx.service.
// Otherwise a magically created systemd directory /tmp/systemd-private-*-httpd.service-* is used.
// See https://stackoverflow.com/questions/55014399/why-doesnt-php-7-2-fopen-tmp-a-write-to-the-file/55016941#55016941
define("LOGFILE", "/tmp/radiopi_frontend.log");


$logfile_handler = fopen(LOGFILE, 'a'); // 'a' means append mode

$volume_step = 10;


function write_log($log_msg) {
    global $logfile_handler;
    fwrite($logfile_handler, date('[d-M-Y H:i:s]') . ' ' . $log_msg . "\n");
}

function exec_radio_script($arguments, &$output, &$exit_code) {
    $cmd = PATH_TO_RADIO_SCRIPT . ' ' . $arguments . ' 2>&1';
    write_log("Executing command: $cmd");
    exec($cmd, $output, $exit_code);
    write_log("... exit code was: " . $exit_code);
    write_log("... output was: " . print_r($output, true));
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
        default:
    }
}

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

        <link rel="icon" type="image/png" href="radio-icon.png"/>

        <link rel="preconnect" href="https://fonts.gstatic.com">
        <link href="https://fonts.googleapis.com/css2?family=Krona+One&display=swap" rel="stylesheet">
        <link href="https://fonts.googleapis.com/css?family=Material+Icons" rel="stylesheet">
        <link rel="stylesheet" href="./style.css">

        <script type="text/javascript" src="./main.js"></script>

        <title>radiopi</title>

    </head>
    <body>

        <main>

        <?php

            exec_radio_script('status', $radio_status, $radio_status_exit_code);

            if ($radio_status_exit_code === 0) {

        ?>

            <div class="radiostatus">
            <?php
                foreach ($radio_status as $line) {
                    echo "<span>$line</span>";
                }
            ?>
            </div>
            <div class="radiocontrols">
                <form name="stop_playback_form" action="" method="post">
                    <input type="hidden" name="action" value="stop_playback" />
                    <div class="touchable" onClick="document.forms['stop_playback_form'].submit();;">
                        <span class="material-icons">stop</span>
                        Stop playback
                    </div>
                </form>
            </div>
            <div class="radiocontrols">
                Volume:
                <form class="inline" name="volume_down_form" action="" method="post">
                    <input type="hidden" name="action" value="volume_down" />
                    <span class="touchable" onClick="document.forms['volume_down_form'].submit();;">
                        <span class="material-icons">volume_down</span>
                        down
                    </span>
                </form>
                <form class="inline" name="volume_up_form" action="" method="post">
                    <input type="hidden" name="action" value="volume_up" />
                    <span class="touchable" onClick="document.forms['volume_up_form'].submit();;">
                        <span class="material-icons">volume_up</span>
                        up
                    </span>
                </form>
                </form>
            </div>
            <div class="equaliser-container">
            <?php
                for ($i = 0; $i < 5; $i++) {
                    echo '
                        <ol class="equaliser-column">
                            <li class="colour-bar"></li>
                        </ol>
                    ';
                }
            ?>
            </div>

        <?php

            } else {

                exec_radio_script('list', $radio_station_list, $radio_station_list_exit_code);

        ?>

            <h1>
                Choose a station:
            </h1>
                <?php if ($radio_station_list_exit_code > 0 || sizeof($radio_station_list) === 0) {
                    echo "Sorry, could not get any station.";
                } else { ?>
                    <input type="text" id="stationfilter" name="filter" placeholder="Search" />
                    <form name="start_playback_form" action="" method="post">
                        <input type="hidden" name="action" value="start_playback" />
                        <input type="hidden" name="station" />
                        <ul id='stationlist'>
                        <?php foreach ($radio_station_list as $station) { ?>
                        <li class="touchable" onClick="document.forms['start_playback_form'].station.value = '<?php echo $station; ?>'; document.forms['start_playback_form'].submit();">
                            <span class="material-icons">play_circle_outline</span>
                            <span class="title"><?php echo $station; ?></span>
                        </li>
                        <?php } ?>
                        </ul>
                        </form>
                <?php } ?>

        <?php

            }

        ?>

        </main>

        <footer>

            <em><a href="https://github.com/sflip/radiopi">radiopi</a></em>
            made by
            <a href="https://philippmoers.de">Flipsi</a>
        </footer>

    </body>
</html>


<?php

fclose($logfile_handler);

?>
