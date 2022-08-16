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

    uint8_t key[21];

    am_addr_t paired_device;

    bool radio_busy = FALSE;
    message_t packet;

    void sendMsg();

    //***************** Auxiliary functions **************//

    /* 
    void sendMsg(am_addr_t addr) {
        if (call AMSend.send(addr, &packet, sizeof(my_msg_t)) == SUCCESS) {
            dbg("radio_send", "Mote %d sending PAIRING packet", TOS_NODE_ID);
            radio_busy = TRUE;
            dbg_clear("radio_send", " at time %s \n", sim_time_string());
        }
    }
    */



    //***************** Boot interface ********************//
    event void Boot.booted() {
        dbg("boot","Application booted.\n");

        if(TOS_NODE_ID % 2 = 0){
            strcpy(key, "sup3r_s3cret-addr3s0");
            dbg("boot","Assigned key %s to node %d.\n",key, TOS_NODE_ID);
        }
        else{
            strcpy(key, "sup3r_s3cret-addr3s1");
            dbg("boot","Assigned key %s to node %d.\n", key, TOS_NODE_ID);
        }

        call AMControl.start();
    }

    //***************** AMControl interface ********************//
    event void AMControl.startDone(error_t err){
        if (err == SUCCESS) {
            dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
            call PairingTimer.startPeriodic(500);
        } else {
            dbgerror("radio","AMControl failed to start on node %d, retrying...\n", TOS_NODE_ID);
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err){
        dbg("boot", "Radio stopped!\n");
    }

    //********************* MilliTimer interface ********************//

    event void PairingTimer.fired() {

        if (radio_busy) {
            return;
        } else {

            my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

            if (msg == NULL) {
			    return;
		    }

            msg->msg_type = PAIRING;
            msg->data = key;

            if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
                dbg("radio_send", "Mote %d sending PAIRING packet", TOS_NODE_ID);
                radio_busy = TRUE;
                dbg_clear("radio_send", " at time %s \n", sim_time_string());
            }

        }

    }


    //********************* AMSend interface ***********************//

    event void AMSend.sendDone(message_t* buf, error_t err) {

        if (&packet == buf && err == SUCCESS) {

            radio_busy = FALSE;

            dbg("radio_send", "Packet sent...");
		    dbg_clear("radio_send", " at time %s \n", sim_time_string());
            
            //TODO ACKs for other operation modes

        } else {
            dbgerror("radio_send", "sendDone error!");
        }


    }



    //********************* Receive interface *********************//

    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

        if (len != sizeof(my_msg_t)) {return buf;}
        else {

            my_msg_t* msg = (my_msg_t*)payload;

            if (msg->msg_type == PAIRING) {
                dbg("radio_rec", "Mote %d received packet at time %s with key %s\n", TOS_NODE_ID, sim_time_string(), msg->data);
                if (strcmp(msg->data, key) == 0) {
                    paired_device = call AMPacket.source(bufPtr);
                    dbg("radio_rec", "Mote %d has the same key as mote %d", TOS_NODE_ID, paired_device);
                    
                    if (radio_busy) {
                        return;
                    } else {

                        my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

                        if (msg == NULL) {
                            return;
                        }

                        msg->msg_type = PAIRING_CONFIRM;

                        if (call AMSend.send(paired_device, &packet, sizeof(my_msg_t)) == SUCCESS) {
                            dbg("radio_send", "Mote %d sending PAIRING_CONFIRM packet to mote %d", TOS_NODE_ID, paired_device);
                            radio_busy = TRUE;
                            dbg_clear("radio_send", " at time %s \n", sim_time_string());
                        }

                    }

                }
            } else if (msg->msg_type == PAIRING_CONFIRM) {
                dbg("radio_rec", "Mote %d received PAIRING_CONFIRM message");
                call PairingTimer.stop();
                //TODO start next phase
            }

        }

    }



    //********************* Read interface ************************//

}