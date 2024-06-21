radiopi
=======

radiopi is a small utility to conveniently play some web radio, e.g. on a Raspberry Pi.
It offers a bash script for command line usage and a [Progressive Web App](https://de.wikipedia.org/wiki/Progressive_Web_App) as a frontend.

## Installation

* Make sure to install dependencies:
    * ALSA sound system (probably already installed)
    * pulseaudio
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
    * Set NO_VOLUME_HOSTS if you want to disable volume controls
* Configure webserver to be able to access system audio (i.e. add webserver user to `audio` group via `sudo usermod -aG audio www-data`)
* If you want to use the scheduled alarm feature:
    * Install a cron service and create a crontab for the webserver user (e.g. `sudo -u www-data crontab -e`)
    * In systemd, disable the [private tmp directory][systemd-private-tmp] of the webserver (e.g. in ` /lib/systemd/system/apache2.service` or `/usr/lib/systemd/system/httpd.service` or `/usr/lib/systemd/system/nginx.service`).
* Symlink [the frontend](./fontend/) to your webserver's document root


## Usage

For `radio.sh` command line usage, refer to the `--help`.

Progressive web app usage should be self-explanatory once you opened the URL with a browser.


## Radio Stream URLs

You can find web radio stream URLs at these sites:
* https://streamurl.link
* https://www.radio-browser.info/


## Author

Philipp Moers – [@soziflip](https://twitter.com/soziflip)


## License

This software is provided under the [MIT license](LICENSE.md).


[systemd-private-tmp]: https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateTmp=
