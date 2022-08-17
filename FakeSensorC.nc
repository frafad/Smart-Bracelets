generic configuration FakeSensorC() {

	provides interface Read<sensor_read>;

} implementation {

	components MainC, RandomC;
	components new FakeSensorP();
	components new TimerMilliC();
	
	//Connects the provided interface
	Read = FakeSensorP;
	
	//Random interface and its initialization	
	FakeSensorP.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;
	
	//Timer interface	
	FakeSensorP.Timer0 -> TimerMilliC;

}