#include <stdio.h>
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
    uint8_t phase = 0; //0: pairing; 1: waiting for pairing_confirm ack; 2: operational mode

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
                dbg("radio_send", "[%s] PAIRING_CONFIRM --- sent confirmation to mote %d\n", sim_time_string(), paired_device);
                radio_busy = TRUE;
                //dbg_clear("radio_send", " at time %s \n", sim_time_string());
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

            if (call AMSend.send(paired_device, &packet, sizeof(my_msg_t)) == SUCCESS) {
                dbg("radio_send", "[%s] INFO --- sent position (%d, %d) and status %d\n", sim_time_string(), msg->pos_x, msg->pos_y, msg->msg_type);
                radio_busy = TRUE;
                //dbg_clear("radio_send", " at time %s \n", sim_time_string());
            }
        }
        
    }


    //***************** Boot interface ********************//
    event void Boot.booted() {
        dbg("boot","[%s] Application booted.\n", sim_time_string());

        if(TOS_NODE_ID < 3){
            strcpy(key, "sup3r_s3cret-addr3s0");
            dbg("boot","[%s] Assigned key %s to node %d.\n", sim_time_string(), key, TOS_NODE_ID);
        }
        else{
            strcpy(key, "sup3r_s3cret-addr3s1");
            dbg("boot","[%s] Assigned key %s to node %d.\n", sim_time_string(), key, TOS_NODE_ID);
        }

        call AMControl.start();
    }
    

    //***************** AMControl interface ********************//
    event void AMControl.startDone(error_t err){
        if (err == SUCCESS) {
            dbg("radio","[%s] Radio on on node %d!\n", sim_time_string(), TOS_NODE_ID);
            call PairingTimer.startPeriodic(500);
        } else {
            dbgerror("radio","[%s] AMControl failed to start on node %d, retrying...\n", sim_time_string(), TOS_NODE_ID);
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err){
        dbg("boot", "[%s] Radio stopped!\n", sim_time_string());
    }


    //********************* MilliTimer interface ********************//

    event void PairingTimer.fired() {
		
		//dbg("radio_send","Pairing timer fired\n");
		
        if (radio_busy) {
            return;
        } else {

            my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));

            if (msg == NULL) {
			    return;
		    }

            msg->msg_type = PAIRING;
            //strncpy((uint8_t *)msg->data, key,20);
            strncpy(msg->data, key,20);

            if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
                dbg("radio_send", "[%s] PAIRING --- sending broadcast with key %s\n", sim_time_string(), msg->data);
                radio_busy = TRUE;
                //dbg_clear("radio_send", " at time %s \n", sim_time_string());
            }

        }
        
        return;
 
    }


    event void DisconnectionTimer.fired() {
        
        dbg("MISSING ALARM", "[%s] MISSING ALARM --- child bracelet missing, last known position: (%d, %d)\n", sim_time_string(), last_position.x, last_position.y);

    }


    event void InfoTimer.fired() {

        call Read.read();

    }

    //********************* AMSend interface ***********************//

    event void AMSend.sendDone(message_t* buf, error_t err) {
    
    	//dbg("radio_send", "sendDone was called\n");

        if (&packet == buf && err == SUCCESS) {

			my_msg_t* msg = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
			
            radio_busy = FALSE;			
			
			if (msg->msg_type != PAIRING) {
		        
		        if (call PacketAcknowledgements.wasAcked(&packet)) {
		            
		            if (phase == 1) {
		                
		                /* Start Operation Mode */
		                dbg("radio_send","[%s] PAIRING_CONFIRM --- confirmation was acked, starting Operation Mode\n", sim_time_string());
		                if(TOS_NODE_ID % 2 == 0){ //even IDs are childrens
		                    call InfoTimer.startPeriodic(10000);
		                }
		                else{ // odd IDs are parents
		                    call DisconnectionTimer.startPeriodic(60000);
		                }

		                phase = 2;

		            }

		        }
		        else{		            
		            dbg("radio_send", "[%s] Packet in phase %d not acked, retrying...\n", sim_time_string(), phase);				
		            (*function_to_call)();
		        }
			}
        } else {
            dbgerror("radio_send", "[%s] sendDone error on mote %d!\n", sim_time_string(), TOS_NODE_ID);
        }


    }



    //********************* Receive interface *********************//

    event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {

        //dbg("radio_rec", "Receive.receive was called\n");
        
        if (len != sizeof(my_msg_t)) {return buf;}
        else {

            my_msg_t* msg = (my_msg_t*)payload;

            if (msg->msg_type == PAIRING) {
                
                if (strncmp((uint8_t*)msg->data, key,20) == 0) {
                    
                    paired_device = call AMPacket.source(buf);
                    dbg("radio_rec", "[%s] PAIRING --- received matching key from mote %d\n", sim_time_string(), paired_device);
                    
                    phase = 1;
                    
                    function_to_call = &send_pairing_confirm;
                    send_pairing_confirm();

                }

            } else if (msg->msg_type == PAIRING_CONFIRM) {
                dbg("radio_rec", "[%s] PAIRING_CONFIRM --- received\n", sim_time_string());
                call PairingTimer.stop();
            } else if (phase == 2 && (msg->msg_type == WALKING || msg->msg_type == STANDING || msg->msg_type == RUNNING)) {
                last_position.x = msg->pos_x;
                last_position.y = msg->pos_y;
                dbg("radio_rec", "[%s] INFO --- received position: (%d, %d) and status: %d\n", sim_time_string(), last_position.x, last_position.y, msg->msg_type);
                call DisconnectionTimer.stop();
                call DisconnectionTimer.startPeriodic(60000);
            } else if (phase == 2 && msg->msg_type == FALLING) {
            	last_position.x = msg->pos_x;
                last_position.y = msg->pos_y;
                dbg("FALLING ALARM", "[%s] FALLING ALARM --- child is falling at position (%d, %d)\n", sim_time_string(), last_position.x, last_position.y);
                call DisconnectionTimer.stop();
                call DisconnectionTimer.startPeriodic(60000);
            }

        }
        
        return buf;

    }



    //********************* Read interface ************************//

    event void Read.readDone(error_t result, sensor_read data) {

        //Send info to the parent bracelet
        last_data = data;
        function_to_call = &send_info_to_parent;
        send_info_to_parent();   

    }

}
