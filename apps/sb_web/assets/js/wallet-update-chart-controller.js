import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:sbp_channel", {})

let bar_ctx = document.getElementById("walletBarChartElement");

let walletUpdateBarChart = new Chart(bar_ctx, {
        type: 'bar',
        data: {
            labels: [],//["Red", "Blue", "Yellow", "Green", "Purple", "Orange"],
            datasets: [{
                label: 'Wallet info',
                data: [],//[12, 19, 3, 5, 2, 3]
                backgroundColor: [
                    'rgba(255, 99, 132, 0.2)',
                    'rgba(54, 162, 235, 0.2)',
                    'rgba(255, 206, 86, 0.2)',
                    'rgba(75, 192, 192, 0.2)',
                    'rgba(153, 102, 255, 0.2)',
                    'rgba(255, 159, 64, 0.2)'
                ],
                borderColor: [
                    'rgba(255,99,132,1)',
                    'rgba(54, 162, 235, 1)',
                    'rgba(255, 206, 86, 1)',
                    'rgba(75, 192, 192, 1)',
                    'rgba(153, 102, 255, 1)',
                    'rgba(255, 159, 64, 1)'
                ],
                borderWidth: 1
            }]
        },
        options: {
            scales: {
                yAxes: [{
                    ticks: {
                        beginAtZero:true
                    }
                }]
            }
        }
    });


channel.on("wallet_update", payload => {

let message = JSON.parse(payload.body)

//message node_id: 1, utxo: 2

console.log("message received: " + message.node_id)

    labels = walletUpdateBarChart.data.labels
    label_index = 0;
    for( i=0; i< labels.length; ++i) {
        if(labels[i]==message.node_id){
            label_index = i;
        }
    }

    if(i==labels.length){
        label_index = labels.length
        walletUpdateBarChart.data.labels.push(message.node_id);
        walletUpdateBarChart.data.datasets[0].data.push(message.utxo)
    }else{
        walletUpdateBarChart.data.datasets[0].data[label_index] = message.utxo
    }

    walletUpdateBarChart.update();


//
//walletUpdateBarChart.data.datasets[0].data.push(message)
//
//walletUpdateBarChart.update()

});

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })


export default walletUpdateBarChart
