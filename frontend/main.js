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

    onSwipeLeft = () => showModule('alarm');
    onSwipeRight = () => showModule('radio');

    // detect swipe gestures
    (() => {
      const slideArea = document.body;
      let touchstart = { x: 0, y: 0};
      let touchend = { x: 0, y: 0};

      handleGesture = () => {
        const distanceX = Math.abs(touchstart.x - touchend.x);
        const distanceY = Math.abs(touchstart.y - touchend.y);
        const horizontal = distanceX > distanceY;
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
      })

      slideArea.addEventListener('touchend', e => {
        touchend = {
          x: e.changedTouches[0].screenX,
          y: e.changedTouches[0].screenY
        };
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
