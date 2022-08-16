#ifndef SMARTBRACELETS_H
#define SMARTBRACELETS_H

//defines for msg_type
#define PAIRING  0
#define PAIRING_CONFIRM 1
#define WALKING  2
#define STANDING 3
#define RUNNING  4
#define FALLING  5

//payload of the msg
typedef nx_struct my_msg {

	//message type
	nx_uint8_t msg_type;
    
    //pairing key
    nx_uint8_t data[21];
	
	//position
    nx_uint16_t pos_x;
    nx_uint16_t pos_y;    
	
} my_msg_t;


enum{
AM_MY_MSG = 6,
};

#endif