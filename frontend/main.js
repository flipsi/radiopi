document.addEventListener("DOMContentLoaded", function(){

  const active = 'active';

  const navlinkRadio = document.querySelector('.navlink.radio');
  const navlinkAlarm = document.querySelector('.navlink.alarm');
  const navlinkInfo  = document.querySelector('.navlink.info');
  const moduleRadio = document.querySelector('.module.radio');
  const moduleAlarm = document.querySelector('.module.alarm');
  const moduleInfo  = document.querySelector('.module.info');

  function showModule(moduleName) {
    [navlinkRadio, navlinkAlarm, navlinkInfo].forEach(nl => nl.classList.remove(active));
    [moduleRadio, moduleAlarm, moduleInfo].forEach(m => m.classList.remove(active));

    switch (moduleName) {
      case 'radio':
        navlinkRadio.classList.add(active);
        moduleRadio.classList.add(active);
        break;
      case 'alarm':
        navlinkAlarm.classList.add(active);
        moduleAlarm.classList.add(active);
        break;
      case 'info':
        navlinkInfo.classList.add(active);
        moduleInfo.classList.add(active);
        break;
      default:
        console.error('Unknown module', moduleName);
    }
    window.location.hash = moduleName;
  }

  function addNavigationEventHandler() {
    navlinkRadio.addEventListener('click', e => showModule('radio'));
    navlinkAlarm.addEventListener('click', e => showModule('alarm'));
    navlinkInfo.addEventListener('click', e => showModule('info'));

    onSwipeLeft = () => {
      if (navlinkRadio.classList.contains(active)) showModule('alarm');
      else if (navlinkAlarm.classList.contains(active)) showModule('info');
    };
    onSwipeRight = () => {
      if (navlinkInfo.classList.contains(active)) showModule('alarm');
      else if (navlinkAlarm.classList.contains(active)) showModule('radio');
    };

    // detect swipe gestures
    (() => {
      const slideArea = document.body;
      let touchtarget = null;
      let touchstart = { x: 0, y: 0};
      let touchend = { x: 0, y: 0};

      handleGesture = () => {
        const minDistance = 30; // minimal distance (threshold) for a swipe gesture to be detected
        const distanceX = Math.abs(touchstart.x - touchend.x);
        const distanceY = Math.abs(touchstart.y - touchend.y);
        const horizontal = distanceX > distanceY && distanceX > minDistance;
        const left = horizontal && touchend.x < touchstart.x;
        const right = horizontal && touchend.x > touchstart.x;
        if (left && typeof onSwipeLeft == 'function') onSwipeLeft();
        if (right && typeof onSwipeRight == 'function') onSwipeRight();
      };

      slideArea.addEventListener('touchstart', e => {
        touchstart = {
          x: e.changedTouches[0].screenX,
          y: e.changedTouches[0].screenY
        };
        touchtarget = e.target;
      })

      slideArea.addEventListener('touchend', e => {
        touchend = {
          x: e.changedTouches[0].screenX,
          y: e.changedTouches[0].screenY
        };
        if (touchtarget.type != 'range')
          handleGesture();
      })

    })();

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
          const title = station.getElementsByClassName('station')[0].innerHTML.toLowerCase();
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
        const title = link.getElementsByClassName('station')[0].innerText;
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
