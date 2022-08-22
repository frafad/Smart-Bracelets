#include "SmartBracelets.h"
#include "Timer.h"


module SmartBraceletsC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
    interface SplitControl as AMControl;
	interface Packet;
    interface AMPacket;
    interface AMSend;
    interface Receive;

	//interfaces for timer
	interface Timer<TMilli> as PairingTimer;
    interface Timer<TMilli> as InfoTimer;
    interface Timer<TMilli> as DisconnectionTimer;

    //ACK interface
	interface PacketAcknowledgements;

	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<sensor_read>;
  }

} implementation {

    uint8_t key[KEY_LENGTH];
    uint8_t phase = 0; //0: pairing, 1: finishing pairing, 2: operational mode

    position last_position;
    sensor_read last_data;

    bool radio_busy = FALSE;

    am_addr_t paired_device;
    message_t packet;

    void (*function_to_call)(void);


    void send_pairing_confirm();
    void send_info_to_parent();

    //***************** Auxiliary functions **************//

    void send_pairing_confirm() {
        if (radio_busy) {
            return;
        } else {

            my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

            if (msg == NULL) {
                return;
            }

            msg->msg_type = PAIRING_CONFIRM;

            call PacketAcknowledgements.requestAck(&packet);

            if (call AMSend.send(paired_device, &packet, sizeof(my_msg_t)) == SUCCESS) {
                dbg("radio_send", "Mote %d sending PAIRING_CONFIRM packet to mote %d", TOS_NODE_ID, paired_device);
                radio_busy = TRUE;
                dbg_clear("radio_send", " at time %s \n", sim_time_string());
            }

        }
    }
    
    
    void send_info_to_parent() {

        if(radio_busy) {
		    return;
	    }
        else {
            my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
            
            if (msg == NULL) {
                return;
            }

            msg->msg_type = last_data.status;
            msg->pos_x = last_data.x;
            msg->pos_y = last_data.y;
            strncpy((uint8_t *) msg->data, key ,20);
            
            call PacketAcknowledgements.requestAck(&packet);

            if (call AMSend.send(1, &packet, sizeof(my_msg_t)) == SUCCESS) {
                dbg("radio_send", "Mote %d sending INFO packet with position (%d, %d) and status %d", TOS_NODE_ID, msg->pos_x, msg->pos_y, msg->msg_type);
                radio_busy = TRUE;
                dbg_clear("radio_send", " at time %s \n", sim_time_string());
            }
        }
        
    }


    //***************** Boot interface ********************//
    event void Boot.booted() {
        dbg("boot","Application booted.\n");

        if(TOS_NODE_ID < 2){
            strncpy(key, "sup3r_s3cret-addr3s0",KEY_LENGTH);
            dbg("boot","Assigned key %s to node %d.\n",key, TOS_NODE_ID);
        }
        else{
            strncpy(key, "sup3r_s3cret-addr3s1",KEY_LENGTH);
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
            strncpy(msg->data, key,20);

            if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
                dbg("radio_send", "Mote %d sending PAIRING packet", TOS_NODE_ID);
                radio_busy = TRUE;
                dbg_clear("radio_send", " at time %s \n", sim_time_string());
            }

        }

    }


    event void DisconnectionTimer.fired() {
        
        dbg("MISSING ALARM", "Child bracelet missing, last known position: (%d, %d)", last_position.x, last_position.y);

    }


    event void InfoTimer.fired() {

        call Read.read();

    }

    //********************* AMSend interface ***********************//

    event void AMSend.sendDone(message_t* buf, error_t err) {

        if (&packet == buf && err == SUCCESS) {

            radio_busy = FALSE;

            dbg("radio_send", "Packet sent...");
		    dbg_clear("radio_send", " at time %s \n", sim_time_string());

            if (call PacketAcknowledgements.wasAcked(&packet)) { //TODO check for pairing messages
                
                if (phase == 1) {
                    
                    /* Start Operation Mode */
                    if(TOS_NODE_ID % 2 == 0){ //even IDs are childrens
                        call InfoTimer.startPeriodic(10000);
                    }
                    else{ // odd IDs are parents
                        call DisconnectionTimer.startPeriodic(60000);
                    }

                    phase = 2;

                }

                if (phase == 2){
                    dbg("radio send" , "INFO packet acked correctly");
                }

            }
            else{
                
                dbg("radio send", "Packet in phase %d not acked, retrying...", phase);

                (*function_to_call)();

            }

        } else {
            dbgerror("radio_send", "sendDone error!");
        }


    }



    //********************* Receive interface *********************//

    event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {

        if (len != sizeof(my_msg_t)) {return buf;}
        else {

            my_msg_t* msg = (my_msg_t*)payload;

            if (phase == 0 && msg->msg_type == PAIRING) {
                
                dbg("radio_rec", "Mote %d received packet at time %s with key %s\n", TOS_NODE_ID, sim_time_string(), msg->data);
                
                if (strncmp((uint8_t*)msg->data, key,20) == 0) {
                    
                    paired_device = call AMPacket.source(buf);
                    dbg("radio_rec", "Mote %d has the same key as mote %d", TOS_NODE_ID, paired_device);
                    
                    phase = 1;
                    function_to_call = &send_pairing_confirm;
                    send_pairing_confirm();

                }

            } else if (phase == 1 && msg->msg_type == PAIRING_CONFIRM) {
                dbg("radio_rec", "Mote %d received PAIRING_CONFIRM message");
                call PairingTimer.stop();
            } else if (phase == 2 && (msg->msg_type == WALKING || msg->msg_type == STANDING || msg->msg_type == RUNNING)) {
                last_position.x = msg->pos_x;
                last_position.y = msg->pos_y;
                dbg("radio_rec", "INFO -- position: (%d, %d)  status: %d", last_position.x, last_position.y, msg->msg_type);
                call DisconnectionTimer.stop();
                call DisconnectionTimer.startPeriodic(60000);
            } else if (phase == 2 && msg->msg_type == FALLING) {
                dbg("FALLING ALARM", "");
                call DisconnectionTimer.stop();
                call DisconnectionTimer.startPeriodic(60000);
            }

        }

    }



    //********************* Read interface ************************//

    event void Read.readDone(error_t result, sensor_read data) {

        //Send info to the parent bracelet
        last_data = data;
        function_to_call = &send_info_to_parent;
        send_info_to_parent();   

    }

}