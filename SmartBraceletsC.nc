#include "SmartBracelets.h"
#include "Timer.h"

module SmartBraceletsC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
    interface SplitControl as AMControl;
	interface Packet;
    interface AMSend;
    interface Receive;

	//interfaces for timer
	interface Timer<TMilli> as PairingTimer;
    interface Timer<TMilli> as InfoTimer;
    interface Timer<TMilli> as DisconnectionTimer;

    //ACK interface
	interface PacketAcknowledgements;

	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t>;
  }

} implementation {

    uint8_t key[20];

    void sendReq();
    void sendResp();

    //***************** Boot interface ********************//
    event void Boot.booted() {
        dbg("boot","Application booted.\n");

        if(TOS_NODE_ID % 2 = 0){
            strcpy(key, "sup3r_s3cret-addr30");
            dbg("boot","Assigned key %s to node %d.\n",key, TOS_NODE_ID);
        }
        else{
            strcpy(key, "sup3r_s3cret-addr31");
            dbg("boot","Assigned key %s to node %d.\n", key, TOS_NODE_ID);
        }
        call AMControl.start();
    }

    //***************** AMControl interface ********************//
    event void AMControl.startDone(error_t err){
        if (err == SUCCESS) {
            dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
            //TODO
        } else {
            dbgerror("radio","AMControl failed to start on node %d, retrying...\n", TOS_NODE_ID);
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err){
        dbg("boot", "Radio stopped!\n");
    }

    //********************* MilliTimer interface ********************//



    //********************* AMSend interface ***********************//



    //********************* Receive interface *********************//



    //********************* Read interface ************************//

}