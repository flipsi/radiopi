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
          const station = stationlist.children[i]
          const title = station.getElementsByClassName('title')[0].innerHTML.toLowerCase();
          station.style.display = title.match(searchString) ? 'block' : 'none';
        }
      });
    }

  };

  addStationFilterEventHandler();
  addNavigationEventHandler();

});
