#include "SmartBracelets.h"

generic module FakeSensorP() {

	provides interface Read<sensor_read>;
	
	uses interface Random;
	uses interface Timer<TMilli> as Timer0;

} implementation {

	//***************** Boot interface ********************//
	command error_t Read.read(){
		call Timer0.startOneShot( 10 );
		return SUCCESS;
	}

	//***************** Timer0 interface ********************//
	event void Timer0.fired() {

        sensor_read result;

        result.x = call Random.rand16();
        result.y = call Random.rand16();

        uint16_t probability = call Random.rand16() % 10;

        if (probability < 3) {
            result.status = STANDING; 
        } else if (probability < 6) {
            result.status = WALKING;
        } else if (probability < 9) {
            result.status = RUNNING;
        } else {
            result.status = FALLING;
        }
        
		signal Read.readDone( SUCCESS, result);
	}
}