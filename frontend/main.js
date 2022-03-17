document.addEventListener("DOMContentLoaded", function(){

  const active = 'active';

  const navlinkRadio = document.querySelector('.navlink.radio');
  const navlinkAlarm = document.querySelector('.navlink.alarm');
  const moduleRadio = document.querySelector('.module.radio');
  const moduleAlarm = document.querySelector('.module.alarm');

  function showModule(moduleName) {
    switch (moduleName) {
      case 'radio':
        navlinkRadio.classList.add(active);
        navlinkAlarm.classList.remove(active);
        moduleRadio.classList.add(active);
        moduleAlarm.classList.remove(active);
        break;
      case 'alarm':
        navlinkRadio.classList.remove(active);
        navlinkAlarm.classList.add(active);
        moduleRadio.classList.remove(active);
        moduleAlarm.classList.add(active);
        break;
      default:
        console.error('Unknown module', moduleName);
    }
  }

  function addNavigationEventHandler() {
    navlinkRadio.addEventListener('click', e => {
      showModule('radio');
      window.location.hash = 'radio';
    });
    navlinkAlarm.addEventListener('click', e => {
      showModule('alarm');
      window.location.hash = 'alarm';
    });
  }

  function addStationFilterEventHandler() {
    const stationfilter = document.getElementById('stationfilter');
    const stationlist = document.getElementById('stationlist');

    if (stationfilter && stationlist) {

      // filter station list as user types
      stationfilter.addEventListener('input', e => {
        const searchString = e.target.value.toLowerCase();
        for (let i = 0; i < stationlist.children.length; i++) {
          const station = stationlist.children[i];
          const title = station.getElementsByClassName('title')[0].innerHTML.toLowerCase();
          station.style.display = title.match(searchString) ? 'block' : 'none';
        }
      });

      // clear focus (to close virtual keyboard) when user is done searching and hits enter
      stationfilter.addEventListener('keyup', e => {
        if (e.key == 'Enter') {
          stationfilter.blur();
        }
      });

    }

  };

  function addStationLinkEventHandler() {
    const startPlaybackForm = document.forms['start_playback_form'];
    const stationInput = document.getElementById('stationinput');
    const stationLinks = document.getElementsByClassName('stationlink');
    for (let i = 0; i < stationLinks.length; i++) {
      const link = stationLinks[i];
      link.addEventListener('click', e => {
        const title = link.getElementsByClassName('title')[0].innerText;
        stationInput.value = title;
        if (!startPlaybackForm.classList.contains('pending'))
          startPlaybackForm.submit();
        startPlaybackForm.classList.add('pending');
      });
    }
  }

  function addSubmitEventHandlers() {
    [
      document.getElementsByClassName('submit'),
      document.querySelectorAll('input[type=submit]'),
    ].forEach(things => {
      for (let i = 0; i < things.length; i++) {
        const thing = things[i];
        const form = thing.closest('form');
        thing.addEventListener('click', e => {
          if (!form.classList.contains('pending'))
            form.submit();
          form.classList.add('pending');
        });
      }
    });
  }

  addStationFilterEventHandler();
  addNavigationEventHandler();
  addStationLinkEventHandler();
  addSubmitEventHandlers();

  if (window.location.hash)
    showModule(window.location.hash.substr(1));

});
