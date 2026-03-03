document.addEventListener("DOMContentLoaded", function(){

  const active = 'active';

  const navlinkRadio = document.querySelector('.navlink.radio');
  const navlinkAlarmList = document.querySelector('.navlink.alarm_list');
  const navlinkAlarmAdd = document.querySelector('.navlink.alarm_add');
  const navlinkInfo  = document.querySelector('.navlink.info');
  const moduleRadio = document.querySelector('.module.radio');
  const moduleAlarmList = document.querySelector('.module.alarm_list');
  const moduleAlarmAdd = document.querySelector('.module.alarm_add');
  const moduleInfo  = document.querySelector('.module.info');

  const navlinks = [navlinkRadio, navlinkAlarmList, navlinkAlarmAdd, navlinkInfo];
  const modules = [moduleRadio, moduleAlarmList, moduleAlarmAdd, moduleInfo];
  const moduleNames = ['radio', 'alarm_list', 'alarm_add', 'info'];

  function showModule(moduleName) {
    navlinks.forEach(nl => nl.classList.remove(active));
    modules.forEach(m => m.classList.remove(active));

    const index = moduleNames.indexOf(moduleName);
    if (index !== -1) {
      navlinks[index].classList.add(active);
      modules[index].classList.add(active);
    } else if (moduleName === 'alarm') { // Compatibility
        navlinkAlarmList.classList.add(active);
        moduleAlarmList.classList.add(active);
    } else {
        console.error('Unknown module', moduleName);
    }
    window.location.hash = moduleName;
  }

  function addNavigationEventHandler() {
    navlinkRadio.addEventListener('click', e => showModule('radio'));
    navlinkAlarmList.addEventListener('click', e => showModule('alarm_list'));
    navlinkAlarmAdd.addEventListener('click', e => showModule('alarm_add'));
    navlinkInfo.addEventListener('click', e => showModule('info'));

    onSwipeLeft = () => {
      const current = moduleNames.find(name => document.querySelector(`.module.${name}`).classList.contains(active));
      const index = moduleNames.indexOf(current);
      if (index < moduleNames.length - 1) showModule(moduleNames[index + 1]);
    };
    onSwipeRight = () => {
      const current = moduleNames.find(name => document.querySelector(`.module.${name}`).classList.contains(active));
      const index = moduleNames.indexOf(current);
      if (index > 0) showModule(moduleNames[index - 1]);
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
    const stationList = document.getElementById('stationlist');
    if (stationList) {
      stationList.addEventListener('click', e => {
        const link = e.target.closest('.stationlink');
        if (link) {
          const title = link.querySelector('.station').innerText;
          stationInput.value = title;
          if (!startPlaybackForm.classList.contains('pending')) {
            startPlaybackForm.submit();
            startPlaybackForm.classList.add('pending');
          }
        }
      });
    }
  }

  function addSubmitEventHandlers() {
    document.body.addEventListener('click', e => {
      const thing = e.target.closest('.submit') || e.target.closest('input[type=submit]');
      if (thing) {
        const form = thing.closest('form');
        if (form && !form.classList.contains('pending')) {
          form.submit();
          form.classList.add('pending');
        }
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
