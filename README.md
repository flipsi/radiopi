radiopi
=======

radiopi is a small utility to conveniently play some web radio, e.g. on a Raspberry Pi.
It offers a bash script for command line usage and a PHP/JS frontend for the web.

## Installation

* Make sure to install dependencies:
    * ALSA sound system (probably already installed)
    * vlc
    * fzf (optionally)
    * Webserver with PHP (for the frontend)
* Clone this repository
* Configure [radio.sh](./radio.sh) to your needs:
    * Extend $RADIO_STATION_LIST
    * Adjust $VLC_GAIN
    * Set (fallback) $ALSA_DEVICE
* Configure [frontend](./fontend/index.php):
    * Set PATH_TO_RADIO_SCRIPT to correct script path of `radio.sh`
* Configure webserver to be able to access system audio (i.e. add webserver user to `audio` group)
* If you want to use the scheduled alarm feature:
    * Install a cron service and create a crontab for the webserver user
    * In systemd, disable the [private tmp directory][systemd-private-tmp] of the webserver
* Symlink [the frontend](./fontend/) to your webserver's document root


## Usage

For `radio.sh` command line usage, refer to the `--help`.

For webserver usage, open the frontend in a browser and click buttons to start or stop the radio.


## Author

Philipp Moers – [@soziflip](https://twitter.com/soziflip)


## License

This software is provided under the [MIT license](LICENSE.md).


[systemd-private-tmp] https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateTmp=
