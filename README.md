radiopi
=======

radiopi is a small utility to conveniently play some web radio, e.g. on a Raspberry Pi.

Really, it consists of two parts:
* the backend, which is just a glorified bash script for command line usage, as well as
* the frontend, a [Progressive Web App][progressive-web-app] written in good old PHP.


## Get Started / Installation

### Alternative A: Containerized version

* To try it out or for development, run `./run.sh`.

This is useful for frontend development, but a current limitation is that there's no audio from within the container.

TODO: Access audio from within container (container pulseaudio and host pipewire - this may be problematic lol)
TODO: Adjust the Dockerfile for production (copy files instead of mounting volume).

### Alternative B: Direct installation on host system

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
    * In systemd, disable the [private tmp directory][systemd-private-tmp] of the webserver (`PrivateTmp=false` in ` /lib/systemd/system/apache2.service` or `/usr/lib/systemd/system/httpd.service` or `/usr/lib/systemd/system/nginx.service`). Beware that this may be overwritten on system updates.
* Symlink [the frontend](./fontend/) to your webserver's document root


## Usage

For `radio.sh` command line usage, refer to the `--help`.

Progressive web app usage should be self-explanatory once you opened the URL with a browser.


## Radio Stream URLs

You can find web radio stream URLs at these sites:
* https://streamurl.link
* https://www.radio-browser.info/


## Author

Philipp Moers – [Personal Website][philippmoers.de]


## License

This software is provided under the [MIT license](LICENSE.md).

[progressive-web-app]: https://de.wikipedia.org/wiki/Progressive_Web_App
[systemd-private-tmp]: https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateTmp=
[philippmoers.de]: https://philippmoers.de
