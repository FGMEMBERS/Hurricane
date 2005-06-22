# $Id$

# ==================================== timer stuff ===========================================

# set the update period

UPDATE_PERIOD = 0.3;

# set the timer for the selected function

registerTimer = func {
    
    settimer(arg[0], UPDATE_PERIOD);

} # end function 

# =============================== end timer stuff ===========================================

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
#				print ("starter running!");
			}
		}
	} else{
		settimer(stopCof, 0.2);
	}
} # end function


stopCof = func {

    min_run = 2;
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
	wheel_pos = getprop("gear/gear/position-norm[0]");
    
    
	if (lever[0] == -1){
     if (lever[1] == -1 ) {
#	    print("levers1: " ,lever[0], lever[1] , " wheel pos: " , wheel_pos); 
        setprop("controls/hydraulic/wheels" , wheel_pos + 0.05);     # lower wheels
        return registerTimer(wheelsMove);                        # run the timer                
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

# =============================== boost stuff =========================================

toggleBoost = func{

    b = getprop("controls/engines/engine/boost");
    if (b == 1) { 
	  b = 0.79; }
	else  {                                    
	  b = 1;
		}
   setprop("controls/engines/engine/boost",b); 	    
#  print("b: " , b );
    
} # end function 

toggleCutout = func{

    c = getprop("controls/engines/engine/cutout");
    c = !c;
    setprop("controls/engines/engine/cutout",c); 	    
#   print("c: " , c );
    
} # end function 

# =============================== end boost cutoff ===========================================

controls.gearDown = func { if (arg[0] != 0) { hydraulicLever(-1, -arg[0]) } }
controls.flapsDown = func { if (arg[0] != 0) { hydraulicLever(1, -arg[0]) } }

# end 
