document.addEventListener("DOMContentLoaded", function(){


  function addStationFilterEventHandler() {

    const stationfilter = document.getElementById('stationfilter');
    const stationlist = document.getElementById('stationlist');

    if (stationfilter && stationlist) {
      stationfilter.oninput = e => {
        const searchString = e.target.value.toLowerCase();
        for (let i = 0; i < stationlist.children.length; i++) {
          const station = stationlist.children[i]
          const title = station.getElementsByClassName('title')[0].innerHTML.toLowerCase();
          station.style.display = title.match(searchString) ? 'block' : 'none';
        }
      };
    }

  };

  addStationFilterEventHandler();

});
