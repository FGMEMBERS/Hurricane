# $Id$

# ==================================== timer stuff ===========================================

# set the update period

UPDATE_PERIOD = 0.3;

# set the timer for the selected function

registerTimer = func {
	
	settimer(arg[0], UPDATE_PERIOD);

} # end function 

# =============================== end timer stuff ===========================================

# =============================== Boost Controller stuff======================================

BOOST_CONTROL_AUTHORITY = 0.99; # How much can it move the throttle?
#BOOST_CONTROL_RANGE = 1;         When does it start to engage? (psig)
BOOST_CONTROL_LIMIT_RATED = 11.9;       # Maximum MP (psig)
BOOST_CONTROL_LIMIT_COMBAT = 18;    # Combat limit (5 mins)

boost_control = props.globals.getNode("/controls/engines/engine/boost-control", 1);
boost_pressure = props.globals.getNode("/engines/engine/boost-gauge-inhg", 1);
boost_pressure_psi = props.globals.getNode("/engines/engine/boost-gauge-psi", 1);
boost_control_damp = props.globals.getNode("/controls/engines/engine/boost-control-damp", 1);
boost_control_range = props.globals.getNode("/controls/engines/engine/boost-control-range", 1);
boost_control_cutout = props.globals.getNode("/controls/engines/engine/boost-control-cutout", 1);
mp_inhg = props.globals.getNode("/engines/engine/mp-inhg", 1);

boost_control.setDoubleValue(1); 
boost_pressure.setDoubleValue(0); 
boost_pressure_psi.setDoubleValue(0); 
boost_control_damp.setDoubleValue(0.015); 
boost_control_range.setDoubleValue(0.5); 
boost_control_cutout.setBoolValue(0); 
mp_inhg.setDoubleValue(0);


damp = 0;

toggleBoost = func{
	b = getprop("controls/engines/engine/boost");

	if (b == 1) {
	    b = 0.79; }
	else  {
	    b = 1;
		}

   setprop("controls/engines/engine/boost",b);
#  print("b: " , b );

} # end function toggleBoost

toggleCutout = func{
	var c = boost_control_cutout.getValue();
	
	c = !c;
	boost_control_cutout.setBoolValue(c);
			
#	print("c: " , c );
	
} # end function toggleCutout

updateBoostControl = func {
		var n = boost_control_damp.getValue(); 
		var BOOST_CONTROL_RANGE = boost_control_range.getValue();
		var mp = (mp_inhg.getValue() * 0.491154077497) - 14.6959487755 ;
		var cutout = boost_control_cutout.getValue();
		var val = 0;
		
		if(! cutout){		
			val = (mp - BOOST_CONTROL_LIMIT_RATED) / BOOST_CONTROL_RANGE;
		} else {
			val = (mp - BOOST_CONTROL_LIMIT_COMBAT) / BOOST_CONTROL_RANGE;
		}	
			
		var in = val;
			
		if (val < 0  ) {
				val = 0;                             # Can't increase throttle
		} elsif (val < -BOOST_CONTROL_AUTHORITY) {
				val = -BOOST_CONTROL_AUTHORITY        # limit by authority
		} else {
				val = -val;
		}
			
		damp = (val * n) + (damp * (1 - n)); # apply low pass filter
	  
#  print(sprintf("mp=%0.5f, in=%0.5f, raw=%0.5f, out=%0.5f", mp, in, val, damp));
				boost_pressure_psi.setDoubleValue(mp);
		boost_control.setDoubleValue(damp);
				boost_control_cutout.setBoolValue(cutout);
		settimer(updateBoostControl, 0.1);
}

updateBoostControl();


# ======================================= end Boost Controller f ============================



# =============================== set the aircraft type =====================================

spitfireIIa = 0;

type = getprop("sim/aircraft");

if (type == "spitfireIIa") {spitfireIIa = 1;}

print ("type: " , type );
# ============================= Coffman starter stuff =======================================


nowN       = props.globals.getNode("/sim/time/elapsed-sec", 1);
starterN   = props.globals.getNode("controls/engines/engine/starter", 1);
primerN    = props.globals.getNode("controls/engines/engine/primer", 1);
cartridgeN = props.globals.getNode("controls/engines/engine/coffman-starter/index");
LastStartTime = 0;
LastCartridge = -1;
Start = 0;		# stopCof needs this, too


indexCof = func{
	pull=arg[0];
	if(pull) {
#        i = getprop("controls/engines/engine/coffman-starter/index");
		i = cartridgeN.getValue();
		i = i - 1;
		if (i == -1) {
			i = 5;
		}
		setprop("controls/engines/engine/coffman-starter/index",i);
		setprop("controls/engines/engine/coffman-starter/index-pull-norm",1)
	}else{
		setprop("controls/engines/engine/coffman-starter/index-pull-norm",0)
		}

} # end function


startCof = func{
	Start = arg[0];
	max_run = 4;
	
	if (Start) {
		LastStartTime = nowN.getValue();
		if (!starterN.getValue()) { 			# not started yet: do it now
			setprop("controls/engines/engine/coffman-starter/starter-push-norm", 1);
			
			ready = !hurricane.spitfireIIa;		# seafires are always ready

			if (!ready) {						# must be a spitfire
				LastCartridge = cartridgeN.getValue();
				j = "controls/engines/engine/coffman-starter/cartridge[" ~ LastCartridge ~ "]";
				if (ready = getprop(j)) {
					setprop(j, 0);
#					print("max run: " , max_run);
					settimer(func {             # nameless out-of-gas watcher
								starterN.setValue(0);
								primerN.setValue(0);
								print ("starter stopping, out of gas!"); 
								}, max_run)};
			}

			if (ready) {
				primerMixture(primerN.getValue());
				starterN.setValue(1);
#				print ("starter running!", primerN.getValue());
			}
		}
	} else{
		settimer(stopCof, 0.2);
	}
} # end function


stopCof = func {

	min_run = 1.0;
	if (!Start and starterN.getValue()) {
		if (nowN.getValue() - LastStartTime < min_run) {
			settimer(stopCof, 0.2);			# too soon; let's try again later
#			print ("too soon! min run: " , min_run);

	} else {
			primerN.setValue(0);
			starterN.setValue(0);
			setprop("controls/engines/engine/coffman-starter/starter-push-norm", 0);
#			print ("starter stopping!");
		}
	}
} # end function

# ============================ end Coffman starter stuff =====================================

# ================================= priming pump stuff =======================================

pumpPrimer = func{
	
	push = arg[0];
	
	if (push){
		pump = getprop("controls/engines/engine/primer") + 1;
		setprop("controls/engines/engine/primer", pump);
		setprop("controls/engines/engine/primer-pump",1);
		}
	else
		{
		setprop("controls/engines/engine/primer-pump",0);
	}

} # end function

primerMixture = func{
	
	mixture = 0;
	primer = arg[0];
	
	if(primer >3 and primer <7) {
		mixture = 1;
	}
	
	return mixture;
	   
} # end function

# ================================== end priming pump stuff =================================

# ================================= magneto stuff ===========================================

setMagnetos = func{     # set the magneto value according to the switch positions

	right = getprop("controls/engines/engine/mag-switch-right");
	left = getprop("controls/engines/engine/mag-switch-left");
	if (left and right){                                 # both
		setprop("controls/engines/engine/magnetos",3); 
		}
		elsif (left and !right) {                         # left
			setprop("controls/engines/engine/magnetos",1)
		}
		elsif (!left and right) {                         # right
			setprop("controls/engines/engine/magnetos",2)
		}
	else{    
		setprop("controls/engines/engine/magnetos",0); # none
		}
	
} # end function

setleftMagswitch = func{
	
	left = arg[0];
	setprop("controls/engines/engine/mag-switch-left",left);
	hurricane.setMagnetos();

} # end function


setrightMagswitch = func{
	
	right = arg[0];
	setprop("controls/engines/engine/mag-switch-right",right);
	hurricane.setMagnetos();

} # end function


toggleleftMagswitch = func{
	
	left = getprop("controls/engines/engine/mag-switch-left");
	left = !left;
	setprop("controls/engines/engine/mag-switch-left",left);
	hurricane.setMagnetos();

} # end function

togglerightMagswitch = func{
	
	right = getprop("controls/engines/engine/mag-switch-right");
	right = !right;
	setprop("controls/engines/engine/mag-switch-right",right);
	hurricane.setMagnetos();

} # end function

# =============================== end magneto stuff =========================================

# ====================================== door and canopy stuff ==============================

openDoor = func{ # open the door if canopy is open
	
	dooropen = arg[0];
	canopyopen = getprop("gear/canopy/position-norm");
	if (canopyopen) {
		setprop("controls/flight/door-position-norm",dooropen)
	}
	
} # end function

toggleDoor = func{ # toggle the door if canopy is open
	
	dooropen = getprop("controls/flight/door-position-norm");
	canopyopen = getprop("gear/canopy/position-norm");
	if (canopyopen) {
		dooropen = !dooropen;
		setprop("controls/flight/door-position-norm",dooropen);
	}
	
} # end function

openCanopy = func{ # open the canopy if door is closed
	
	canopyopen = arg[0];
	dooropen = getprop("controls/flight/door-position-norm");
	if (!dooropen) {
		setprop("controls/flight/canopy-slide",canopyopen)
	}

} # end function

# ==================================== end door and canopy ===================================

# ======================================== Cutoff ============================================

pullCutoff = func{

	pull=arg[0];
	mixturelever = getprop("controls/engines/engine/mixture-lever");
	
	if(pull) {
		setprop("controls/engines/engine/cutoff-pull-norm",1);
		setprop("controls/engines/engine/cutoff",0);
		#setprop("controls/engines/engine/mixture",0);
		if (getprop("engines/engine/rpm") < 100) {setprop("engines/engine/running",0)}
	}else{
		setprop("controls/engines/engine/cutoff-pull-norm",0);
		setprop("controls/engines/engine/cutoff",1);
		#setprop("controls/engines/engine/mixture",mixturelever)
		}

} # end function

# =================================== end Cutoff ============================================



# ======================================= fuel tank stuff ===================================

# fuel gauge

setTankContents=func{

	tank=getprop("controls/switches/fuel-gauge-sel");
	contents=getprop("consumables/fuel/tank[" ~ tank ~ "]/level-gal_us");
	setprop("instrumentation/fuel/contents-gal_us",contents);
#	print("contents: " , contents, " tank: " , tank);
	registerTimer(setTankContents);
	
}#end func

registerTimer(setTankContents);

# operate fuel cocks

openCock=func{

	cock=getprop("controls/engines/engine/fuel-cock/lever");
   
	if (cock < 2){
		cock = cock +1;
		setprop("controls/engines/engine/fuel-cock/lever",cock);
		adjustCock()
		}
		
}#end func

closeCock=func{

	cock=getprop("controls/engines/engine/fuel-cock/lever");
   
	if (cock > 0){
		cock = cock - 1;
		setprop("controls/engines/engine/fuel-cock/lever",cock);
		adjustCock()
		}
		
}#end func


# adjust fuel cocks

adjustCock=func{

	lever=getprop("controls/engines/engine/fuel-cock/lever");
	
	if (lever == 0){
		setprop("consumables/fuel/tank[0]/selected",0);
		setprop("consumables/fuel/tank[1]/selected",0);
		setprop("consumables/fuel/tank[2]/selected",0);
		}
		elsif (lever == 1){
		setprop("consumables/fuel/tank[0]/selected",1);
		setprop("consumables/fuel/tank[1]/selected",1);
		setprop("consumables/fuel/tank[2]/selected",0);
		}
		else {
		setprop("consumables/fuel/tank[0]/selected",0);
		setprop("consumables/fuel/tank[1]/selected",0);
		setprop("consumables/fuel/tank[2]/selected",1);
	}
	
}#end func

# ========================== end fuel stuff ======================================


# =========================== hydraulic stuff =========================================

controls.gearDown = func(x) { if (x) { hydraulicLever(-1, -x) } }
controls.flapsDown = func(x) { if (x) { hydraulicLever(1, -x) } }

hydraulicLever = func{             #sets the lever up-down, right-left or neutral

	right = arg[0]; 
	up = arg[1];
	lever=[0,1];
	
#	print("input: ",right,up);
	
	lever[0]= getprop("controls/hydraulic/lever[0]"); #right/left
	lever[1]= getprop("controls/hydraulic/lever[1]"); #up/down
	
#	print ("lever in: ", lever[0],lever[1]);
		
	if ( lever[0] == 0 or lever[0] == right) {     #
		if (up == 1  and lever[1] < 1){
			lever[1] = lever[1] + 1;
		}
		elsif ( up == -1  and lever[1] > -1){
			lever[1] = lever[1] - 1;
		}
		elsif (up == 0) {
			lever[1] = 0;
		}
		
		if (lever[1] == 0) {
			lever[0] = 0;
		} else {
			lever[0] = right;
		}
	}
	
#	print ("lever out: ", lever[0],lever[1]);
	
	setprop("controls/hydraulic/lever[1]",lever[1]);
	setprop("controls/hydraulic/lever[0]",lever[0]);
	
	if (lever[0] == 1 and lever[1] == -1) 
		{ registerTimer (flapBlowin)}   # run the timer 
		
	if (lever[0] == -1 and lever[1] != 0) 
		{ registerTimer (wheelsMove)}   # run the timer                    
		
} # end function 

flapBlowin = func{
	flap = 0;
	lever=[0,1];
	lever[0] = getprop("controls/hydraulic/lever[0]");
	lever[1] = getprop("controls/hydraulic/lever[1]");
	airspeed = getprop("velocities/airspeed-kt");
	flap_pos = getprop("surface-positions/flap-pos-norm");

#    print("lever: " , lever[1] , " airspeed (kts): " , airspeed , " flap pos: " , flap_pos);
	
	if (lever[0] == 1){
	 if (lever[1] == -1 and airspeed < 105) { 
		setprop("controls/flight/flaps" , flap_pos + 0.05);    # increase the flap
		return registerTimer(flapBlowin);                      # run the timer                
		}
		elsif (lever[1] == -1 and airspeed >= 110 and airspeed <= 120) {
			flap = -0.08*airspeed + 9.4;
			if(flap_pos < flap)
				{
				setprop("controls/flight/flaps" , flap_pos + 0.05); # flap partially blown in 
				} 
			return registerTimer(flapBlowin);                    # run the timer                        
		}
		elsif (lever[1] == -1 and airspeed > 120) {
			flap = 0.2;
			if(flap_pos < flap)
				{
				setprop("controls/flight/flaps" , flap_pos + 0.05); # flap partially blown in 
				} 
			return registerTimer(flapBlowin);                  # run timer
		}                    
	if ( lever[1] == 1) {
			setprop("controls/flight/flaps" , flap_pos - 0.05);
		return registerTimer(flapBlowin); 
		}
	}
	 
	if (flap_pos != 0 and airspeed < 110){
			return registerTimer(flapBlowin);
		}
		elsif( flap_pos != 0 and airspeed >= 110 and airspeed <= 120) {
			flap = -0.08 * airspeed + 9.4;
			if (flap_pos > flap){
#            	print("flap: " , "flap 1");
				setprop("controls/flight/flaps", flap);    		# flap partially blown in
			}  
			return registerTimer(flapBlowin);
		}
		elsif (flap_pos != 0 and airspeed > 120) {
			flap = 0.2;
			if (flap_pos > flap){
#            	print("flap: " , "flap 2");
				setprop("controls/flight/flaps", flap);       # flap blown in                                         
			}
#			print("flap: " , "flap 2");
			return registerTimer(flapBlowin);                  # run the timer
		}                    
	else
		{                    # stop flap movement, don't run the timer                    
		return;
		}   
} # end function

wheelsMove = func{
		
	lever=[0,1];
	lever[0] = getprop("controls/hydraulic/lever[0]");
	lever[1] = getprop("controls/hydraulic/lever[1]");
	wheel_pos = getprop("gear/gear[1]/position-norm[0]");
	
	
	if (lever[0] == -1){
	 if (lever[1] == -1 ) {
#	    print("levers1: " ,lever[0], lever[1] , " wheel pos: " , wheel_pos); 
			setprop("controls/hydraulic/wheels" , wheel_pos + 0.05);     # lower wheels
			return registerTimer(wheelsMove);                            # run the timer                
		}
	 elsif ( lever[1] == 1) {
#		print("levers2: " ,lever[0], lever[1] , " wheel pos: " , wheel_pos);
		setprop("controls/hydraulic/wheels" , wheel_pos - 0.05); # raise wheels
		return registerTimer(wheelsMove); 
		}
	else
		{                    # stop wheel movement, don't run the timer                    
		return;
		}
	}   
} # end function  

# =============================== end flap stuff =========================================

# =========================== gear warning stuff =========================================

toggleGearWarn = func{                                         # toggle the gear warning

	cancel = getprop("sim/alarms/gear-warn");
	cancel = !cancel;
#   print("cancel :", cancel);
	setprop("sim/alarms/gear-warn",cancel);
	if (cancel) {registerTimer(resetWarn)}                    # run the timer
		
} # end function 

resetWarn = func{

	throttle = getprop("controls/engines/engine/throttle");
	gearwarn = getprop("sim/alarms/gear-warn");
#   print("throttle " , throttle , " gearwarn: " , gearwarn);
	if (gearwarn and throttle >= 0.25 ) { 
		setprop("sim/alarms/gear-warn",0);                    # reset the gear warning
		}
		else
		{
		return registerTimer(resetWarn);                      # run the timer                
		}
		
} # end function 


# =========================== end gear warning stuff =========================================

# =============================== -ve g cutoff stuff =========================================

negGCutoff = func{

	g = getprop("accelerations/pilot-g");
	if (g == nil) { g = 0 };
	mixture = getprop("controls/engines/engine/mixture-lever");
	if (spitfireIIa) {
		if (g > 0.75) {
				return  mixture;                    # mixture set by lever
			}
			elsif (g <= 0.75 and g >= 0)  {            # mixture set by - ve g
				mixture = g * 4/3;
			}
			else  {                                    # mixture set by - ve g
				mixture = 0;
		}
	} 
		
#    print("g: " , g , " mixture: " , mixture);
	
	return mixture;

} # end function 

# =============================== end -ve g cutoff ===========================================

# =============================== Pilot G stuff======================================

pilot_g = props.globals.getNode("accelerations/pilot-g", 1);
timeratio = props.globals.getNode("accelerations/timeratio", 1);
pilot_g_damped = props.globals.getNode("accelerations/pilot-g-damped", 1);

pilot_g.setDoubleValue(0);
pilot_g_damped.setDoubleValue(0); 
timeratio.setDoubleValue(0.03); 

g_damp = 0;

updatePilotG = func {
		var n = timeratio.getValue(); 
		var g = pilot_g.getValue() ;
		#if (g == nil) { g = 0; }
		g_damp = ( g * n) + (g_damp * (1 - n));
		
		pilot_g_damped.setDoubleValue(g_damp);

# print(sprintf("pilot_g_damped in=%0.5f, out=%0.5f", g, g_damp));
		
		settimer(updatePilotG, 0.1);

} #end updatePilotG()

updatePilotG();

# headshake - this is a modification of the original work by Josh Babcock

# Define some stuff with global scope

xConfigNode = '';
yConfigNode = '';
zConfigNode = '';

xAccelNode = '';
yAccelNode = '';
zAccelNode = '';

var xDivergence_damp = 0;
var yDivergence_damp = 0;
var zDivergence_damp = 0;

var last_xDivergence = 0;
var last_yDivergence = 0;
var last_zDivergence = 0;

# Make sure that some vital data exists and set some default values
enabledNode = props.globals.getNode("/sim/headshake/enabled", 1);
enabledNode.setBoolValue(1);

xMaxNode = props.globals.getNode("/sim/headshake/x-max-m",1);
xMaxNode.setDoubleValue( 0.025 );

xMinNode = props.globals.getNode("/sim/headshake/x-min-m",1);
xMinNode.setDoubleValue( -0.05 );
	
yMaxNode = props.globals.getNode("/sim/headshake/y-max-m",1);
yMaxNode.setDoubleValue( 0.025 );

yMinNode = props.globals.getNode("/sim/headshake/y-min-m",1);
yMinNode.setDoubleValue( -0.025 );
	
zMaxNode = props.globals.getNode("/sim/headshake/z-max-m",1);
zMaxNode.setDoubleValue( 0.025 );

zMinNode = props.globals.getNode("/sim/headshake/z-min-m",1);
zMinNode.setDoubleValue( -0.05 );

view_number_Node = props.globals.getNode("/sim/current-view/view-number",1);
view_number_Node.setDoubleValue( 0 );

time_ratio_Node = props.globals.getNode("/sim/headshake/time-ratio",1);
time_ratio_Node.setDoubleValue( 0.003 );

seat_vertical_adjust_Node = props.globals.getNode("/controls/seat/vertical-adjust",1);
seat_vertical_adjust_Node.setDoubleValue( 0 );

xThresholdNode = props.globals.getNode("/sim/headshake/x-threshold-m",1);
xThresholdNode.setDoubleValue( 0.02 );

yThresholdNode = props.globals.getNode("/sim/headshake/y-threshold-m",1);
yThresholdNode.setDoubleValue( 0.02 );

zThresholdNode = props.globals.getNode("/sim/headshake/z-threshold-m",1);
zThresholdNode.setDoubleValue( 0.02 );

# We will use these later
xConfigNode = props.globals.getNode("/sim/view/config/z-offset-m");
yConfigNode = props.globals.getNode("/sim/view/config/x-offset-m");
zConfigNode = props.globals.getNode("/sim/view/config/y-offset-m");
	
xAccelNode = props.globals.getNode("/accelerations/pilot/x-accel-fps_sec",1);
xAccelNode.setDoubleValue( 0 );
yAccelNode = props.globals.getNode("/accelerations/pilot/y-accel-fps_sec",1);
yAccelNode.setDoubleValue( 0 );
zAccelNode = props.globals.getNode("/accelerations/pilot/z-accel-fps_sec",1);
zAccelNode.setDoubleValue(-32 );
   

headShake = func {

	# First, we don't shake outside the vehicle. Inside, we boogie down.
	# There are two coordinate systems here, one used for accelerations, and one used for the viewpoint.
	# We will be using the one for accelerations.
	var enabled = enabledNode.getValue();
	var view_number= view_number_Node.getValue();
	var n = timeratio.getValue(); 
	var seat_vertical_adjust = seat_vertical_adjust_Node.getValue();
	

	if ( (enabled) and ( view_number == 0)) {
	
	var xConfig = xConfigNode.getValue();
		var yConfig = yConfigNode.getValue();
		var zConfig = zConfigNode.getValue();

		var xMax = xMaxNode.getValue();
		var xMin = xMinNode.getValue();
		var yMax = yMaxNode.getValue();
		var yMin = yMinNode.getValue();
		var zMax = zMaxNode.getValue();
		var zMin = zMinNode.getValue();

	#work in G, not fps/s
		var xAccel = xAccelNode.getValue()/32;
		var yAccel = yAccelNode.getValue()/32;
		var zAccel = (zAccelNode.getValue() + 32)/32; # We aren't counting gravity
 
	var xThreshold =  xThresholdNode.getValue();
	var yThreshold =  yThresholdNode.getValue();
	var zThreshold =  zThresholdNode.getValue();
		
		# Set viewpoint divergence and clamp
		# Note that each dimension has it's own special ratio and +X is clamped at 1cm
		# to simulate a headrest.

	#y = -0.0005x3 - 0.005x2 - 0.0089x - 0.0045
	# -0.0004x3 + 0.0042x2 - 0.0084x + 0.0048
	# -0.0004x3 - 0.0042x2 - 0.0084x - 0.0048
		if (xAccel < -5 ) {
		xDivergence = -0.03;
	} elsif ((xAccel < -0.5) and (xAccel >= -5)) {
			xDivergence = ((( -0.0005 * xAccel ) - ( 0.0036 )) * xAccel - ( 0.001 )) * xAccel - 0.0004;
		} elsif ((xAccel > 1) and (xAccel <= 6)) {
				xDivergence = ((( -0.0004 * xAccel ) + ( 0.0031 )) * xAccel - ( 0.0016 )) * xAccel + 0.0002;
	} elsif (xAccel > 5) {
		xDivergence = 0.02;
	} else {
		xDivergence = 0;
		}

#       These equations shape the output and convet from G number to divergence left/right in meters
#	y = -0.0005x3 - 0.0036x2 + 0.0001x + 0.0004
#	y = -0.013x3 + 0.125x2 - 0.1202x + 0.0272
		
	if (yAccel < -5 ) {
		yDivergence = -0.03;
	} elsif ((yAccel < -0.5) and (yAccel >= -5)) {
			yDivergence = ((( -0.005 * yAccel ) - ( 0.0036 )) * yAccel - (  0.0001 )) * yAccel - 0.0004;
		} elsif ((yAccel > 0.5) and (yAccel <= 5)) {
			yDivergence = ((( -0.013 * yAccel ) + ( 0.125 )) * yAccel - (  0.1202 )) * yAccel + 0.0272;
		} elsif (yAccel > 5) {
		yDivergence = 0.03;
	}else {
		yDivergence = 0;
	}

#        setprop("/sim/current-view/x-offset-m", (yConfig + yDivergence));	
# y = -0.0005x3 - 0.0036x2 + 0.0001x + 0.0004
# y = -0.0004x3 + 0.0031x2 - 0.0016x + 0.0002
	if (zAccel < -5 ) {
		zDivergence = -0.03;
	} elsif ((zAccel < -0.5) and (zAccel >= -5)) {
			zDivergence = ((( -0.0005 * zAccel ) - ( 0.0036 )) * zAccel - ( 0.001 )) * zAccel - 0.0004;
		} elsif ((zAccel > 0.5) and (zAccel <= 5)) {
				zDivergence = ((( -0.0004 * zAccel ) + ( 0.0031 )) * zAccel - ( 0.0016 )) * zAccel + 0.0002;
	} elsif (zAccel > 5) {
		zDivergence = 0.02;
	} else {
		zDivergence = 0;
		}
		# 
	   
	xDivergence_total = (xDivergence * 0.75) + (zDivergence * 0.25);

		if (xDivergence_total > xMax){xDivergence_total = xMax;}
		if (xDivergence_total < xMin){xDivergence_total = xMin;}
	
	if (abs(last_xDivergence - xDivergence_total) <= xThreshold){
			xDivergence_damp = ( xDivergence_total * n) + ( xDivergence_damp * (1 - n));
	#	print ("x low pass");
	} else {
		xDivergence_damp = xDivergence_total;
	#	print ("x high pass");
	}
		
	last_xDivergence = xDivergence_damp;

# print (sprintf("x-G=%0.5fx, total=%0.5f, x div damped=%0.5f",xAccel, xDivergence_total, xDivergence_damp));	

	yDivergence_total = yDivergence;
		if (yDivergence_total >= yMax){yDivergence_total = yMax;}
		if (yDivergence_total <= yMin){yDivergence_total = yMin;}

	if (abs(last_yDivergence - yDivergence_total) <= yThreshold){
		yDivergence_damp = ( yDivergence_total * n) + ( yDivergence_damp * (1 - n));
		# 	print ("y low pass");
	} else {
		yDivergence_damp = yDivergence_total;
	#	print ("y high pass");
	}

	last_yDivergence = yDivergence_damp;

#print (sprintf("y=%0.5f, y total=%0.5f, y min=%0.5f, y div damped=%0.5f",yDivergence, yDivergence_total, yMin , yDivergence_damp));
	
	zDivergence_total =  (xDivergence * 0.25 ) + (zDivergence * 0.75);

	if (zDivergence_total >= zMax){zDivergence_total = zMax;}
		if (zDivergence_total <= zMin){zDivergence_total = zMin;}
	   
	if (abs(last_zDivergence - zDivergence_total) <= zThreshold){ 
			zDivergence_damp = ( zDivergence_total * n) + ( zDivergence_damp * (1 - n));
	#print ("z low pass");
	} else {
		zDivergence_damp = zDivergence_total;
	#print ("z high pass");
	}
	

#	last_zDivergence = zDivergence_damp;

#print (sprintf("z-G=%0.5f, z total=%0.5f, z div damped=%0.5f",zAccel, zDivergence_total,zDivergence_damp));

	setprop("/sim/current-view/z-offset-m", xConfig + xDivergence_damp );
		setprop("/sim/current-view/x-offset-m", yConfig + yDivergence_damp );
	setprop("/sim/current-view/y-offset-m", zConfig + zDivergence_damp + seat_vertical_adjust );
	}
	settimer(headShake,0 );

}

headShake();

# ======================================= end Pilot G stuff ============================

# ================================== Steering ==========================================

aircraft.steering.init();


# ==================================  Engine Hobbs Meter ================================

var hobbs_engine = aircraft.timer.new("sim/time/hobbs/engine[0]", 60, 0);
var engine_running_Node = props.globals.initNode("engines/engine[0]/running", 1, "BOOL");

hobbs_engine.reset();

updateHobbs = func{
	var running = engine_running_Node.getValue();

	if(running){
		hobbs_engine.start();
	} else {
		hobbs_engine.stop();
	}

	settimer(updateHobbs,0)
}

updateHobbs();

# ================================== End Engine Hobbs Meter ================================

# ==================================  Tyresmoke /Spray ================================
var run_tyresmoke0 = 0;
var run_tyresmoke1 = 0;
var run_tyresmoke2 = 0;

var tyresmoke_0 = aircraft.tyresmoke.new(0);
var tyresmoke_1 = aircraft.tyresmoke.new(1);
var tyresmoke_2 = aircraft.tyresmoke.new(2);

# =============================== listeners ===============================
#

setlistener( "controls/lighting/nav-lights", func {
	var nav_lights_node = props.globals.getNode("controls/lighting/nav-lights", 1);
	var generic_node = props.globals.getNode("sim/multiplay/generic/int[0]", 1);
	generic_node.setIntValue(nav_lights_node.getValue());
	print("nav_lights ", nav_lights_node.getValue(), "generic_node ", generic_node.getValue());
	}
); 

setlistener("gear/gear[0]/position-norm", func {
	var gear = getprop("gear/gear[0]/position-norm");
	
	if (gear == 1 ){
		run_tyresmoke0 = 1;
	}else{
		run_tyresmoke0 = 0;
	}

	},
	1,
	0);

setlistener("gear/gear[1]/position-norm", func {
	var gear = getprop("gear/gear[1]/position-norm");
	
	if (gear == 1 ){
		run_tyresmoke1 = 1;
	}else{
		run_tyresmoke1 = 0;
	}

	},
	1,
	0);

setlistener("gear/gear[2]/position-norm", func {
	var gear = getprop("gear/gear[2]/position-norm");
	
	if (gear == 1 ){
		run_tyresmoke2 = 1;
	}else{
		run_tyresmoke2 = 0;
	}

	},
	1,
	0);

#============================ Tyre Smoke ===================================

var tyresmoke = func {

#print ("run_tyresmoke ",run_tyresmoke0,run_tyresmoke1,run_tyresmoke2);

	if (run_tyresmoke0)
		tyresmoke_0.update();

	if (run_tyresmoke1)
		tyresmoke_1.update();

	if (run_tyresmoke2)
		tyresmoke_2.update();

	settimer(tyresmoke, 0);
}# end tyresmoke

# == fire it up ===

tyresmoke();

#============================ Rain ===================================

aircraft.rain.init();

var rain = func {
	var running = engine_running_Node.getValue();
	aircraft.rain.update();
#	print("running ", running);

	if(running){
		setprop("sim/model/rain/flow-threshold-kt", 0);
	} else {
		setprop("sim/model/rain/flow-threshold-kt", 15);
	}
	
	settimer(rain, 0);
}

# == fire it up ===
rain()

# end 
