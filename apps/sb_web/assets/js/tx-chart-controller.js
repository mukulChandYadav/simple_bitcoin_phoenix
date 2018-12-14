import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:sbp_channel", {})

let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")


let ctx_bubble = document.getElementById("txBubbleChartElement");

/*[{
                          x: -10,
                          y: 0
                      }, {
                          x: 0,
                          y: 10
                      }, {
                          x: 10,
                          y: 5
                      }]
*/

let txBubbleChart = new Chart(ctx_bubble, {
            type: 'bubble',
            data: {
                datasets: [{
                    label: 'Transaction Dataset',
                    data: []
                }]
            },
            options: {
                scales: {
                    xAxes: [{
                        type: 'linear',
                        position: 'bottom'
                    }]
                }
            }
        });



channel.on("new_tx", payload => {

let message = JSON.parse(payload.body)
console.log("message received: sender-" + message.sender+" receiver-"+message.receiver+ " amount-"+ message.amount)

let data = {x:  message.sender, y: message.receiver, r: message.amount}
  txBubbleChart.data.datasets[0].data.push(data)
  txBubbleChart.update()

})


channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })



export default txBubbleChart
