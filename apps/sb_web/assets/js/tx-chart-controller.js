import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:sbp_channel", {})

let chatInput         = document.querySelector("#chat-input")
let messagesContainer = document.querySelector("#messages")


let ctx_bubble = document.getElementById("txBubbleChartElement");

let data = [{
                   // X Value, Sender
                   x: 1,

                   // Y Value, Receiver
                   y: 2,

                   // Bubble radius in pixels (not scaled). Transaction value
                   r: 10
               },
               {
                                  // X Value, Sender
                                  x: 2,

                                  // Y Value, Receiver
                                  y: 4,

                                  // Bubble radius in pixels (not scaled). Transaction value
                                  r: 100
                              },
               {
                                                 // X Value, Sender
                                                 x: 22,

                                                 // Y Value, Receiver
                                                 y: 7,

                                                 // Bubble radius in pixels (not scaled). Transaction value
                                                 r: 5
                                             }
               ];
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
                    data: data
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

var message = JSON.parse(payload.body)
console.log("message received: " + message.x)
  data.push(message)

  console.log("Data after message "+data)

  var txBubbleChart = new Chart(ctx_bubble, {
              type: 'bubble',
              data: {
                  datasets: [{
                      label: 'Transaction Dataset',
                      data: data
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

})


channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })



export default txBubbleChart
