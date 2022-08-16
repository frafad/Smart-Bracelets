#include "SmartBracelets.h"

configuration SmartBraceletsAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, SmartBraceletsC as App;
  
  components new TimerMilliC() as PairingTimer;
  components new TimerMilliC() as InfoTimer;
  components new TimerMilliC() as DisconnectionTimer;
  
  components new FakeSensorC();
  
  components ActiveMessageC;
  
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;
  
  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  
  //Radio Control
  App.AMControl -> ActiveMessageC;
  
  //Interfaces to access package fields
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
 
  //Timer interface
  App.PairingTimer -> PairingTimer;
  App.InfoTimer -> InfoTimer;
  App.DisconnectionTimer -> DisconnectionTimer;
  
  //Fake Sensor read
  App.Read -> FakeSensorC;
  
  //ACK interface
  App.PacketAcknowledgements -> ActiveMessageC;

}

