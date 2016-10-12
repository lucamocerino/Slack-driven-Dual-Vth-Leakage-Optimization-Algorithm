proc leakage_opt {aT arrivalTime cp criticalPath sw slackWin } {
	
		
	#suppress warning
	suppress_message TIM-104
	suppress_message NLE-019


	if { $aT!="-arrivalTime" || $cp!="-criticalPaths" || $sw!="-slackWin" } {
		puts "Error: invalid operand !"
		set voidList {}
		return $voidList 
		}
		




	#Take initial power consumption
	set report_text ""  	;# Contains the output of the report_power command
	set lnr 3           	;# Leakage info is in the 2nd line from the bottom
	set all 7          	;# Leakage info is the eighth word in the $lnr line 
	redirect -variable report_text {report_power -cell -nosplit}
	set report_text [split $report_text "\n"]
	set to_scan [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $lnr]]] $all]
	scan $to_scan %f%s val uni
	set val_init $val
	set unit_init $uni
	########

	set LVT_lib  "CORE65LPLVT_nom_1.00V_25C.db:CORE65LPLVT/"
	set HVT_lib  "CORE65LPHVT_nom_1.00V_25C.db:CORE65LPHVT/"
	set LL "_LL"
	set LH "_LH"

	set lvh_reqTime [get_attribute [get_timing_path] required ]
	set lvh_arrTime [get_attribute [get_timing_path] required ]
	set left_edge [expr $lvh_reqTime - $arrivalTime]
	set path_slackwin_ini [sizeof_collection [get_timing_paths -slack_greater_than $left_edge -slack_lesser_than [expr $slackWin + $left_edge] -nworst [expr $criticalPath + 1]]]
	
	# check on the number of paths in the slack window
	if { $path_slackwin_ini > $criticalPath } {
		set voidList {}
		return $voidList 
	}
	

	set start [clock clicks -milliseconds] 	;#start time in ms

	# check if the arrival time provided by the user
	# is feasible. 
	if { $lvh_arrTime > $arrivalTime } {
		set voidList {}
		return $voidList 
	
		}

	# get cells number 
	set cell_list [get_cells]

	# change all the cells to HVT
	foreach_in_collection cell $cell_list { 

		set cell_refname [get_attribute $cell ref_name]
		regsub -all $LL $cell_refname $LH cell_refname
		size_cell $cell $HVT_lib$cell_refname
		
	}

	# get the new arrival time 	
	set cpArrivalTime [get_attribute [get_timing_path] arrival]  
	
	 
########
	
	set lvt 0
	set hvt 0 
	set prevIt 0
	while { $cpArrivalTime >= $arrivalTime  } {

		# get the cells of the cp 
		set path_list [get_timing_paths]
		set critical_path_cell_list [list]
		foreach_in_collection timing_points [get_attribute $path_list points] {
			set pin_name [get_attribute [get_attribute $timing_points object] full_name]
			if { [string index $pin_name "0"] == "U" } {
				set cell_name [lindex [split $pin_name '/'] 0]
				if {$cell_name != [lindex $critical_path_cell_list end]} {
					lappend critical_path_cell_list $cell_name
				}		
			}
		}

		#swap HVT -> LVT 
		foreach cell_name $critical_path_cell_list {
			set cell_ref_name [get_attribute $cell_name ref_name]
			# check if the cell is already swapped
			if {[regexp $LL $cell_ref_name] == 0} {			
				regsub -all $LH $cell_ref_name $LL cell_ref_name	
				size_cell $cell_name $LVT_lib$cell_ref_name
			
			}
		}
	# update the arrival time
	set cpArrivalTime [get_attribute [get_timing_path] arrival]
		

	#Recovery mecchanism in case of "local minimum"
	if { $cpArrivalTime == $prevIt } {

		set all_c [get_cells]
		set HVT_list [list]
		set hvt 0

	
		foreach_in_collection c $all_c {
			set cell_ref [get_attribute $c ref_name] 
			if {[regexp $LL $cell_ref] == 0 } { 
				lappend HVT_list $c
			}
		}

		set HVT_dim [llength $HVT_list]
		set HVT_dim_half [expr $HVT_dim / 2 ]
				
		foreach HVT_cell_to_swap $HVT_list {
			if { $HVT_dim_half > 0 } {
				set cell_ref_name [get_attribute $HVT_cell_to_swap ref_name]			
				regsub -all $LH $cell_ref_name $LL cell_ref_name	
				size_cell $HVT_cell_to_swap $LVT_lib$cell_ref_name
			
				
			}
			set HVT_dim_half [expr $HVT_dim_half -  1]
		}

	} else { set prevIt $cpArrivalTime }
	

	# only for debug 142-154
	set numcel [sizeof_collection [get_cells]]
	set all_c [get_cells]
	set lvt 0
	set hvt 0
	foreach_in_collection c $all_c {
		set cell_ref [get_attribute $c ref_name] 
		if {[regexp $LL $cell_ref] == 1} {
			incr lvt
		} else { incr hvt }
	}
	
	}


	#slack wcp
	set pathBound [ expr $criticalPath -1 ]
	set pathsInWindow [get_timing_paths -slack_greater_than $left_edge -slack_lesser_than [expr $slackWin + $left_edge] -nworst $criticalPath ]
	set num_path [sizeof_collection $pathsInWindow]	



	set old_lvt 0

	while { $num_path > $pathBound } {

	
		set path_list [get_timing_paths]
		set critical_path_cell_list [list]
		foreach_in_collection timing_points [get_attribute $path_list points] {
			set pin_name [get_attribute [get_attribute $timing_points object] full_name]
			if { [string index $pin_name "0"] == "U" } {
				set cell_name [lindex [split $pin_name '/'] 0]
				if {$cell_name != [lindex $critical_path_cell_list end]} {
					lappend critical_path_cell_list $cell_name
				}		
			}
		}

		# swap HVT -> LVT
		
		foreach cell_name $critical_path_cell_list {
			set cell_ref_name [get_attribute $cell_name ref_name]
			# check if the cell is already swapped		
			if {[regexp $LL $cell_ref_name] == 0} {			
				regsub -all $LH $cell_ref_name $LL cell_ref_name	
				size_cell $cell_name $LVT_lib$cell_ref_name
			
			}
		}
	
		# update paths in the slack window	
		set pathsInWindow  [get_timing_paths -slack_greater_than $left_edge -slack_lesser_than [expr $slackWin + $left_edge] -nworst $criticalPath ]
		set num_path [sizeof_collection $pathsInWindow]
				

		set new_lvt 0
		set hvt 0 
		set numcell [sizeof_collection [get_cells ]]
		set allc [get_cells]
		foreach_in_collection c $allc {
			set cell_rf [get_attribute $c ref_name]
			if {[regexp "_LL" $cell_rf ] == 1} {
				incr new_lvt
			} else { incr hvt }
		}

		#Recovery mecchanism in case of "local minimum"

		if { $new_lvt == $old_lvt } {
		
		set all_c [get_cells]
		set HVT_list [list]
		set hvt 0

	
		foreach_in_collection c $all_c {
			set cell_ref [get_attribute $c ref_name] 
			if {[regexp $LL $cell_ref] == 0 } { 
				lappend HVT_list $c
			}
		}

		set HVT_dim [llength $HVT_list]
		set HVT_dim_half [expr $HVT_dim / 2 ]
				
		foreach HVT_cell_to_swap $HVT_list {
			if { $HVT_dim_half > 0 } {
				set cell_ref_name [get_attribute $HVT_cell_to_swap ref_name]
				#puts "trovata cella HVT"			
				regsub -all $LH $cell_ref_name $LL cell_ref_name	
				size_cell $HVT_cell_to_swap $LVT_lib$cell_ref_name
			
				
			}
			set HVT_dim_half [expr $HVT_dim_half -  1]
		}

	} else { set old_lvt $new_lvt }





	}

	set pathsInWindow [get_timing_paths -slack_greater_than $left_edge -slack_lesser_than [expr $slackWin + $left_edge] -nworst $criticalPath ]
	set num_path [sizeof_collection $pathsInWindow]
	

##############
	#Take final power
	#set report_text ""  	;# Contains the output of the report_power command
	#set lnr 3           	;# Leakage info is in the 2nd line from the bottom
	#set all 7           	;# Leakage info is the eighth word in the $lnr line
 
	redirect -variable report_text {report_power -cell -nosplit}
	set report_text [split $report_text "\n"]
	set to_scan1 [lindex [regexp -inline -all -- {\S+} [lindex $report_text [expr [llength $report_text] - $lnr]]] $all]
	scan $to_scan1 %f%s dec1 uni1
	set  val_fin $dec1
	set unit_fin $uni1
	

	

	if { $unit_init == $unit_fin } {
	
	set  leakage_power [ expr (($val_fin / $val_init) * 100 ) ]
	
	} elseif { $unit_init == "nW" && $unit_fin=="mW" } {

	set leakage_power [ expr (($val_fin  / ($val_init*1000000) * 100 ) ]
	
	} elseif { $unit_init == "nW" && $unit_fin=="uW" } {

	set leakage_power [ expr (($val_fin / ($val_init *1000)) * 100 ) ]

	} elseif { $unit_init == "nW" && $unit_fin=="W" } {

	set leakage_power [ expr (($val_fin / ($val_init *1000000000)  * 100 ) ]

	} elseif { $unit_init == "mW" && $unit_fin=="nW" } {

	set leakage_power [ expr ((($val_fin*1000000) / $val_init ) * 100 )] 
	
	} elseif { $unit_init == "mW" && $unit_fin=="uW" } {

	set leakage_power [ expr ((($val_fin *1000) / $val_init) * 100 ) ]

	} elseif { $unit_init == "mW" && $unit_fin=="W" } {

	set leakage_power [ expr (($val_fin /($val_init *1000)  * 100 ) ]

	} elseif { $unit_init == "uW" && $unit_fin=="nW" } {

	set leakage_power [ expr (($val_fin / ($val_init*1000)) * 100) ]		

	} elseif { $unit_init == "uW" && $unit_fin=="mW" } {
	
	set leakage_power [ expr ((($val_fin*1000) /$val_init) * 100 ) ]

	} elseif { $unit_init == "uW" && $unit_fin=="W" } {
	
	set leakage_power [ expr (($val_fin/ ($val_init*1000000)) * 100 ) ]
	
	} elseif { $unit_init == "W" && $unit_fin=="nW" } {
	
	set leakage_power [ expr ((($val_fin*1000000000) /$val_init) * 100 ) ]

	} elseif { $unit_init == "W" && $unit_fin=="mW" } {
	
	set leakage_power [ expr ((($val_fin*1000) / $val_init) * 100 ) ]
	
	} elseif { $unit_init == "W" && $unit_fin=="uW" } {
	
	set leakage_power [ expr ((($val_fin*1000000) / $val_init) * 100 ) ]
	
	 }

	set resList [list]
	set leak_op [expr (100 - $leakage_power)/ 100 ]
	lappend resList $leak_op
	
	#Stats
	

	set all_c [get_cells]
	set numce [sizeof_collection $all_c]	
	set LVT 0
	set HVT 0

	#conto numero di lvt e hvt
	foreach_in_collection cell $all_c {
		set cell_refname [get_attribute $cell ref_name]
		if {[regexp $LL $cell_refname] == 1} {
			incr LVT
		} else { incr HVT }
	}
	
	set stop [clock clicks -milliseconds] 
	set exec_time [expr ((1.0*($stop-$start )) / 1000) ]
	lappend resList $exec_time


	set HVT_perc [expr ($HVT.0 / $numce.0)]
	set LVT_perc [expr ($LVT.0  /$numce.0)]	
	lappend resList $LVT_perc
	lappend resList $HVT_perc


	

	return $resList
		

}




