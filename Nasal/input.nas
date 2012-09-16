#function to simulate airspeed effects on control surfaces 
#it reduces effective input by a factor proportional to the square of the speed
#©2010-2012 Huminiuc Emilian
#License: GPL v2.0

setlistener("/sim/signals/fdm-initialized", func {
	print("Control filter for YASim ---INITIALIZED");
	control_loop_yasim();
});

var control_loop_yasim = func {
	var  airspeed = getprop("/velocities/airspeed-kt");
	var ail_input = getprop("/controls/flight/aileron");
	var comp_factor = 1.0;

	if (airspeed > 122.0){
		if (airspeed <= 330.0){
		  comp_factor = 0.575 + 0.425 * math.cos(( airspeed - 122.0 ) * 3.14 / 208.0 );
		} else {
		  comp_factor = 0.15;
		};
	};

	setprop("/controls/flight/aileron-norm", ail_input * comp_factor);
	settimer(control_loop_yasim, 0);
};
