document.addEventListener("DOMContentLoaded", function(){

  const active = 'active';

  function addNavigationEventHandler() {
    const navlinkRadio = document.querySelector('.navlink.radio');
    const navlinkAlarm = document.querySelector('.navlink.alarm');
    const moduleRadio = document.querySelector('.module.radio');
    const moduleAlarm = document.querySelector('.module.alarm');

    navlinkRadio.addEventListener('click', e => {
      navlinkRadio.classList.add(active);
      navlinkAlarm.classList.remove(active);
      moduleRadio.classList.add(active);
      moduleAlarm.classList.remove(active);
    });
    navlinkAlarm.addEventListener('click', e => {
      navlinkRadio.classList.remove(active);
      navlinkAlarm.classList.add(active);
      moduleRadio.classList.remove(active);
      moduleAlarm.classList.add(active);
    });
  }

  function addStationFilterEventHandler() {
    const stationfilter = document.getElementById('stationfilter');
    const stationlist = document.getElementById('stationlist');

    if (stationfilter && stationlist) {
      stationfilter.addEventListener('input', e => {
        const searchString = e.target.value.toLowerCase();
        for (let i = 0; i < stationlist.children.length; i++) {
          const station = stationlist.children[i];
          const title = station.getElementsByClassName('title')[0].innerHTML.toLowerCase();
          station.style.display = title.match(searchString) ? 'block' : 'none';
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
    const things = document.getElementsByClassName('submit');
    for (let i = 0; i < things.length; i++) {
      const thing = things[i];
      const form = thing.closest('form');
      thing.addEventListener('click', e => {
        if (!form.classList.contains('pending'))
          form.submit();
        form.classList.add('pending');
      });
    }
  }

  addStationFilterEventHandler();
  addNavigationEventHandler();
  addStationLinkEventHandler();
  addSubmitEventHandlers();

});
