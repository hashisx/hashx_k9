///////////////////////////////////////////////////////////////////////////////////////
//GLOBALS
//////////////////////////////////////////////////////////////////////////////////////
let resourceName = null;
const Sleep = (ms) => new Promise((resolve, reject) => setTimeout(resolve, ms));

///////////////////////////////////////////////////////////////////////////////////////
//NUI EVENT SORTER
//////////////////////////////////////////////////////////////////////////////////////

$(function () {
    window.addEventListener('message', function (event) {
        switch (event.data.type) {

            case "RESOURCE_NAME":
              resourceName = event.data.name
            break;

            case "OPEN_K9_SPAWNER_DESPAWNER":
              menui.list = [
                {id: 'K9_SPAWN',type: 'default', name: "Fetch K-9", description: "Get your K-9 from the kennel or Animal Hospital."},
                {id: 'K9_DESPAWN',type: 'default', name: "Return K-9", description: "Return your K-9 to the kennel."},
                {id: false,type: 'default', name: "Exit", description: ""}
              ]
              menui.show = true;
            break;

            case "OPEN_K9_OPTIONS":
              menui.name = event.data.k9_name
              menui.list = [
                {id: 'K9_NAME',type: 'input', name: "K-9 Name", description: "Set the name of your K-9."},
                {id: 'K9_VEST',type: 'selector', name: "K-9 Vest", description: "Change the vest of your K-9.", value: event.data.vest},
                {id: 'K9_COLOR',type: 'selector', name: "K-9 Color", description: "Change the fur color of your K-9.", value: event.data.color},
                {id: 'K9_SAVE',type: 'default', name: "Save", description: ""}
              ]
              menui.show = true;
            break;

              case "OPEN_K9_MENU":

              menui.list = [
                {id: 'K9_SIT',type: 'default', name: "Sit", description: "Command your K-9 to sit."},
                {id: 'K9_LAYDOWN',type: 'default', name: "Stay", description: "Command your K-9 to stay."},
                {id: 'K9_VEHICLE_TOGGLE',type: 'default', name: "Vehicle", description: "Tells your K9 to get in or out of a vehicle."},
                {id: 'K9_SEARCH_PERSON',type: 'default', name: "Search Person", description: "Tells your K9 to search the player for drugs."},
                {id: 'K9_SEARCH_VEHICLE',type: 'default', name: "Search Vehicle", description: "Tells your K9 to search a vehicle and it's occupants for drugs."},
                {id: 'K9_SEARCH_AREA',type: 'default', name: "Search Area", description: "Tells your K9 to search an area and track every person within the area."},
                {id: false,type: 'default', name: "Exit", description: ""}

              ]
              menui.show = true;
            break;


            default:
              this.console.log(`some shit broke in the switch.${event.data.type}`)
            break;
        }
    });
});

///////////////////////////////////////////////////////////////////////////////////////
// MAIN FEED
//////////////////////////////////////////////////////////////////////////////////////

let menui = null;
window.addEventListener('load', function () {
//VUE INVENTORY HANDLER
menui = new Vue({
                  el: '#menui',
                  data: {
                    show: false,
                    name: 'Toby',
                    list: [
                    ]
                  }
});

});


function MenuItemDefault(data){

  const id = $(data).data("id");

  $.post('https://'+resourceName+'/MENU_SELECT', JSON.stringify({value: id}));
  exit()
}

function MenuItemSelect(data, type){
  const id = $(data).data("id");
  const value = $(data).data("value");

  console.log(`${id} ${value} ${type}`)
  $.post('https://'+resourceName+'/MENU_UPDATE', JSON.stringify({id: id, value: value, type: type}));
}

function MenuItemInput(data){

  const value = $(data).val();

  $.post('https://'+resourceName+'/MENU_INPUT', JSON.stringify({value: value}));
}

function exit(){
  menui.list = []
  menui.show = false;
  $.post('https://'+resourceName+'/CLOSE_MENU', JSON.stringify());
}

function GetTimestamp(){

  return `${new Date().toISOString().substr(11, 8)}`
};
