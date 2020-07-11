// the position of the launch pad at the start of the flight
// expected to be Kerbin:GEOPOSITIONLATLNG(-0.0972078529347668,-74.5576977333496)
global pad_position is ship:geoposition.

// the heigh of the terrain above sea level at the launch pad
// expected to be 72.4554207319161
global pad_terrain_heigth is pad_position:terrainheight.

// the altitude of the computer above the ground at the launch pad
// e.g. 30.2009334411705
global controller_ground_altitude is ship:altitude - pad_terrain_heigth.

print "configured starting altitude to " + controller_ground_altitude.
