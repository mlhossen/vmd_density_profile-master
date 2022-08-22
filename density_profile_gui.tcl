#!/usr/bin/env wish# density_profile_gui.tcl --
#
# UI generated by GUI Builder Build 146 on 2012-12-18 18:22:59 from:
#    /home/toni/compile/vmd-utils/vmd_density_profile/density_profile_gui.ui
# This file is auto-generated.  Only the code within
#    '# BEGIN USER CODE'
#    '# END USER CODE'
# and code inside the callback subroutines will be round-tripped.
# The proc names 'ui' and 'init' are reserved.
#

package require Tk 8.4

# Declare the namespace for this dialog
namespace eval density_profile_gui {}

# Source the ui file, which must exist
set density_profile_gui::SCRIPTDIR [file dirname [info script]]
source [file join $density_profile_gui::SCRIPTDIR density_profile_gui_ui.tcl]

# BEGIN USER CODE
# ----------------------------------------
# GUI functions for computing density profiles.
# ----------------------------------------

# This code is a mess because it can be loaded back in guibuilder.
package provide density_profile_gui 1.1

namespace eval density_profile_gui {
    variable already_registered 0
}

# VMD-specific stuff. If invoked from VMD, load the backed functions
# (in package density_profile) and setup some defaults.
set density_profile_gui::in_vmd [string length [info proc vmd_install_extension]]
if { $density_profile_gui::in_vmd } {
    package require density_profile
} else {
    #  Kludge to run outside VMD
    namespace eval ::density_profile:: {}
    array set ::density_profile::dp_args {}
}

# Called right upon menu action
proc density_profile_gui::density_profile_tk {} {
    variable density_profile_window

    if { [winfo exists .density_profile] } {
	wm deiconify $density_profile_window
    } else {
	set density_profile_window [ toplevel ".density_profile" ]
	wm title $density_profile_window "Density Profile Tool"
	density_profile_gui::ui $density_profile_window;
    }
    return $density_profile_window
}

# Register menu if possible
proc density_profile_gui::register_menu {} {
    variable already_registered
    if {$already_registered==0} {
	incr already_registered
	vmd_install_extension density_profile_gui density_profile_gui::density_profile_tk "Analysis/Density Profile Tool"
    }
}
					


# Only enable Z-related controls for electron densities
proc density_profile_gui::update_Zsource_state {} {
    variable ::density_profile::dp_args
    variable density_profile_window
    set rho  $dp_args(rho)
    set state disabled
    if {$rho=="electrons"} {
	set state normal
    }
    $density_profile_window.radiobutton_Zsource_element configure -state $state
    $density_profile_window.radiobutton_Zsource_mass configure -state $state
    $density_profile_window.radiobutton_Zsource_name configure -state $state
    $density_profile_window.radiobutton_Zsource_type configure -state $state
    $density_profile_window.checkbox_Zsource_partial configure -state $state
}



# Return the title to show on the vertical axis. For now simply
# returns rho
proc density_profile_gui::get_title {} {
    set rho $::density_profile::dp_args(rho)
    return $rho
}

# Return the unit to show on the vertical axis
proc density_profile_gui::get_units {} {
    set rho $::density_profile::dp_args(rho)
    array set ylabel {number atoms   mass amu  charge e  electrons el}
    return $ylabel($rho)
}

# Nested list transpose http://wiki.tcl.tk/2748
proc density_profile_gui::transpose {matrix} {
   for {set index 0} {$index < [llength [lindex $matrix 0]]} {incr index} {
       lappend res [lsearch -all -inline -subindices  -index $index $matrix *]
   }
   return $res
}

proc density_profile_gui::help_docs {} {
    vmd_open_url http://multiscalelab.org/utilities/DensityProfileTool
}

proc density_profile_gui::help_about {} {
    variable density_profile_window
    tk_messageBox -title "About" -parent $density_profile_window -message \
"
VMD Density Profile Tool

Version [package versions density_profile]

Toni Giorgino <toni.giorgino isib.cnr.it>
Institute of Biomedical Engineering (ISIB)
National Research Council of Italy (CNR)

Until 2011: 
Computational Biophysics Group
Research Programme on Biomedical Informatics (GRIB-IMIM)
Universitat Pompeu Fabra (UPF)

"
    
}


# Uses density_profile::compute to do the backend computation
proc density_profile_gui::do_plot {} {
    variable ::density_profile::dp_args
    variable density_profile_window

    set selection  $dp_args(selection)
    set axis       $dp_args(axis)
    set resolution $dp_args(resolution)
    set average    $dp_args(average)

    # Make sure pbcs are set or warn
    set area [density_profile::transverse_area]
    if { [llength $area] == 1 && $area == -1 } { 	
	set answer [ tk_messageBox -icon question -message "No periodic cell information. Will compute linear densities instead of volume densities. Continue?" \
			 -type okcancel  -parent $density_profile_window]
	switch -- $answer {
	    ok { set area 1 }
	    cancel { error "Cancelled" }
	}
    } elseif { [llength $area] == 1 && $area == -2 } {
	tk_messageBox -icon error -message "Only orthorombic cells are supported" -title Error  -parent $density_profile_window
	error "Only orthorombic cells are supported"
    }

    
    # Compute
    set lhist [density_profile::compute]

    set framelist [density_profile::get_framelist]
    set values [density_profile::hist_to_values $lhist]

    # breaks -> bin centers
    set xbreaks [density_profile::hist_to_xbreaks $lhist]
    foreach b $xbreaks {
	lappend xcenters [expr $b+0.5*$resolution]
    }

    # Title and Y axis label
    if {$average==1} {
	set title "Average [get_title] density profile (\u00B1 s.d.)"
    } else {
	set title "[string totitle [get_title]] density profile"
    }
    set ylabel [get_units]
    if {$area == 1} { 
	set ylabel "$ylabel/\uc5" 
    } else {
	set ylabel "$ylabel/\uc5\ub3" 
    }
    set xlabel  "Bin center (\u212B)" 

    
    # do plot, average case
    if {$average} {
	set avg [density_profile::average_sublists $values]
	set std [density_profile::stddev_sublists $values]

	set avgpstd [vecadd $avg $std]
	set avgmstd [vecsub $avg $std]
	
	set ph [multiplot -x $xcenters -y $avg \
		    -ylabel $ylabel \
		    -xlabel $xlabel \
		    -title $title \
		    -marker point -radius 2  -fillcolor "#ff0000" -color "#ff0000"  ]
	$ph add $xcenters $avgpstd -dash "," -linecolor  "#000000"
	$ph add $xcenters $avgmstd -dash "," -linecolor  "#000000"
	$ph replot
    } else {
	# Iterate over frames, build a vector, plot it
	set ph [multiplot -title $title \
		          -ylabel $ylabel \
		          -xlabel $xlabel ]
	set values_t [transpose $values]
	foreach tmp $values_t {
	    $ph add $xcenters $tmp  -linecolor  "#000000"
	}
	$ph replot
    }

}
# END USER CODE

# BEGIN CALLBACK CODE
# ONLY EDIT CODE INSIDE THE PROCS.

# density_profile_gui::_checkbutton_2_command --
#
# Callback to handle _checkbutton_2 widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_checkbutton_2_command args {}

# density_profile_gui::_entry_1_invalidcommand --
#
# Callback to handle _entry_1 widget option -invalidcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_1_invalidcommand args {}

# density_profile_gui::_entry_1_validatecommand --
#
# Callback to handle _entry_1 widget option -validatecommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_1_validatecommand args {}

# density_profile_gui::_entry_1_xscrollcommand --
#
# Callback to handle _entry_1 widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_1_xscrollcommand args {}

# density_profile_gui::_entry_2_invalidcommand --
#
# Callback to handle _entry_2 widget option -invalidcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_2_invalidcommand args {}

# density_profile_gui::_entry_2_validatecommand --
#
# Callback to handle _entry_2 widget option -validatecommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_2_validatecommand args {}

# density_profile_gui::_entry_2_xscrollcommand --
#
# Callback to handle _entry_2 widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_2_xscrollcommand args {}

# density_profile_gui::_entry_3_invalidcommand --
#
# Callback to handle _entry_3 widget option -invalidcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_3_invalidcommand args {}

# density_profile_gui::_entry_3_validatecommand --
#
# Callback to handle _entry_3 widget option -validatecommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_3_validatecommand args {}

# density_profile_gui::_entry_3_xscrollcommand --
#
# Callback to handle _entry_3 widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_3_xscrollcommand args {}

# density_profile_gui::_entry_4_invalidcommand --
#
# Callback to handle _entry_4 widget option -invalidcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_4_invalidcommand args {}

# density_profile_gui::_entry_4_validatecommand --
#
# Callback to handle _entry_4 widget option -validatecommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_4_validatecommand args {}

# density_profile_gui::_entry_4_xscrollcommand --
#
# Callback to handle _entry_4 widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_4_xscrollcommand args {}

# density_profile_gui::_entry_5_invalidcommand --
#
# Callback to handle _entry_5 widget option -invalidcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_5_invalidcommand args {}

# density_profile_gui::_entry_5_validatecommand --
#
# Callback to handle _entry_5 widget option -validatecommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_5_validatecommand args {}

# density_profile_gui::_entry_5_xscrollcommand --
#
# Callback to handle _entry_5 widget option -xscrollcommand
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_entry_5_xscrollcommand args {}

# density_profile_gui::_radiobutton_2_command --
#
# Callback to handle _radiobutton_2 widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_radiobutton_2_command args {}

# density_profile_gui::_radiobutton_3_command --
#
# Callback to handle _radiobutton_3 widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_radiobutton_3_command args {}

# density_profile_gui::_radiobutton_4_command --
#
# Callback to handle _radiobutton_4 widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::_radiobutton_4_command args {}

# density_profile_gui::checkbox_Zsource_partial_command --
#
# Callback to handle checkbox_Zsource_partial widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::checkbox_Zsource_partial_command args {}

# density_profile_gui::close_command --
#
# Callback to handle close widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::close_command args {
    wm withdraw .density_profile
}

# density_profile_gui::help_command --
#
# Callback to handle help widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::help_command args {
    help_docs
}

# density_profile_gui::plot_command --
#
# Callback to handle plot widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::plot_command args {
    do_plot
}

# density_profile_gui::radiobutton_atoms_command --
#
# Callback to handle radiobutton_atoms widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_atoms_command args {update_Zsource_state}

# density_profile_gui::radiobutton_charge_command --
#
# Callback to handle radiobutton_charge widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_charge_command args {update_Zsource_state}

# density_profile_gui::radiobutton_electrons_command --
#
# Callback to handle radiobutton_electrons widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_electrons_command args {update_Zsource_state}

# density_profile_gui::radiobutton_mass_command --
#
# Callback to handle radiobutton_mass widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_mass_command args {update_Zsource_state}

# density_profile_gui::radiobutton_Zsource_element_command --
#
# Callback to handle radiobutton_Zsource_element widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_Zsource_element_command args {}

# density_profile_gui::radiobutton_Zsource_mass_command --
#
# Callback to handle radiobutton_Zsource_mass widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_Zsource_mass_command args {}

# density_profile_gui::radiobutton_Zsource_name_command --
#
# Callback to handle radiobutton_Zsource_name widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_Zsource_name_command args {}

# density_profile_gui::radiobutton_Zsource_type_command --
#
# Callback to handle radiobutton_Zsource_type widget option -command
#
# ARGS:
#    <NONE>
#
proc density_profile_gui::radiobutton_Zsource_type_command args {}

# END CALLBACK CODE

# density_profile_gui::init --
#
#   Call the optional userinit and initialize the dialog.
#   DO NOT EDIT THIS PROCEDURE.
#
# Arguments:
#   root   the root window to load this dialog into
#
# Results:
#   dialog will be created, or a background error will be thrown
#
proc density_profile_gui::init {root args} {
    # Catch this in case the user didn't define it
    catch {density_profile_gui::userinit}
    if {[info exists embed_args]} {
	# we are running in the plugin
	density_profile_gui::ui $root
    } elseif {$::argv0 == [info script]} {
	# we are running in stand-alone mode
	wm title $root density_profile_gui
	if {[catch {
	    # Create the UI
	    density_profile_gui::ui  $root
	} err]} {
	    bgerror $err ; exit 1
	}
    }
    catch {density_profile_gui::run $root}
}
density_profile_gui::init .
