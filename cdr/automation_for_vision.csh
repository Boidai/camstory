#!/bin/csh 
#
# This script is for full automation using vision300 interface.
# The script opens a window for selecting the jobs to be processed.     
# Automatic setup is performed on all the electrical layers of all selected jobs.
# Required customization:
#    - comment out tables which are not used on site. search for "have_xxx_table".
#    - replace database names according to names defined on site. search for "DATABASE".
#    - define which layers to process (IL, OL or ALL, must be capital letters).
#      search for "layer_to_output".     
#    
# date: 20 aug 2001
#
# updates:
# bina, 11 oct 2001:
#    - modify name of mount point
# zvika, 09 jan 2002
#    - Add the option to select the layers to be processed (IL, OL or ALL)
#===============================================================================

# Set variables
#===============

# Comment out the lines that are not correct
set have_standard_table
set have_wide_table
set have_large_table
set have_xl_table

# Define the layers you want to output (you can define onr of the following options: ALL, OL, IL).
set layer_to_output = IL 

if ($_genesis_edir =~ /* || $_genesis_edir =~ ?:*) then
   set EDIR_PATH = ($_genesis_edir)
else
   set EDIR_PATH = ($_genesis_root/$_genesis_edir)
endif

if (-e $EDIR_PATH/misc/dbutil) then
     alias dbutil $EDIR_PATH/misc/dbutil 
else
   echo Problem with environment vars: $GENESIS_DIR or $GENESIS_EDIR
   exit 1
endif

alias MATH 'set \!:1 = `echo "\!:3-$" | $EDIR_PATH/misc/gbc -l`'

# define the GENESIS_TMP
#========================
if (! $?GENESIS_TMP) then
   set GENESIS_TMP = $_genesis_root/tmp
endif

set guifile = $GENESIS_TMP/gui_win.$$
set tmpfile = $GENESIS_TMP/data_tmp.$$

#
# Use of GUI to define the jobs we are going to run
#===================================================
echo "WIN 200 200"                                    > $guifile
echo "LABEL INSERT THE NAMES OF JOBS TO BE INSPECTED" >> $guifile
echo "LIST job_var 20 m 1"                            >> $guifile
dbutil list jobs | awk '{print($1)}'                  >> $guifile
echo "END"                                            >> $guifile
echo "CLABEL OK"                                      >> $guifile
gui $guifile >! $tmpfile
source $tmpfile
rm -f $tmpfile

#
# the begining of the automation for each job
#=============================================
foreach job ($job_var)
   set JOB = $job
   echo "job = ${JOB}"
   COM info,out_file=$GENESIS_TMP/info.out.$$, \
       args= -t matrix -e $JOB/matrix -d COL -p step_name
   source $GENESIS_TMP/info.out.$$

   set step = ""
   #
   # for each step_name in matrix - look for the panel step
   # (step's name is assumed to be *panel*)
   #=======================================================
   foreach step_name ($gCOLstep_name)

   	   # if the word "panel" occurs in "step_name", 
	   #if ($step_name =~ *panel* && $step_name !~ *subpanel*) then
	   if ($step_name == panel) then
	      set step = $step_name
	   endif
   end

   if ( $step == "" ) continue
   
   echo "step = $step"
  
   #
   # Set "electrical_layers" to electrical layers of job
   #=====================================================
   set electric_layers
   
   COM info,out_file=$GENESIS_TMP/info.out.$$,\
      args= -t matrix -e ${JOB}/matrix
   source $GENESIS_TMP/info.out.$$

   
   @ i = 0
    while ($i < $#gROWname)
      if ($gROWcontext[$i] == "board") then
          if ($gROWlayer_type[$i] == "power_ground" || $gROWlayer_type[$i] == "signal" || $gROWlayer_type[$i] == "mixed") then
             set electric_layers = ($electric_layers $gROWname[$i])
          endif
      endif
      @ i ++
   end
   #
   # Define the layers  to output
   ###############################
   set outputLayers
   set elecLayers = ($electric_layers)
   
   if ($layer_to_output  == OL) then
      set outputLayers = ($elecLayers[1] $elecLayers[$#elecLayers])
   else if ($layer_to_output  == IL) then 
           @ i = 1
           while ($i <= $#elecLayers)
                 if ($i != 1 && $i != $#elecLayers) then
                    set outputLayers = ($outputLayers $elecLayers[$i])
                 endif
                 @ i ++
           end
   else if ($layer_to_output  == ALL) then
           set outputLayers = ($electric_layers)
   endif 
   
   COM cdr_open,job=,interface=v300
   COM check_inout,mode=out,type=job,job=${JOB}
   COM cdr_set_step,job=${JOB},step=$step,set_name=cdr   
   COM open_entity,job=${JOB},type=step,name=${step},iconic=no
   COM units,type=inch
   COM info,out_file=$GENESIS_TMP/info.out.$$, \
       args= -t step -e $JOB/${step} -d PROF_LIMITS
   source $GENESIS_TMP/info.out.$$
   MATH X = $gPROF_LIMITSxmax - $gPROF_LIMITSxmin
   set X = $X:r
   MATH Y = $gPROF_LIMITSymax - $gPROF_LIMITSymin
   set Y = $Y:r
   COM editor_page_close
   
   #
   # changing table to fit the size of panel.
   #=========================================
   unset TABLE
   
   if ($?have_standard_table && (($X <= 24 && $Y <= 30) || ($X <= 30 && $Y <= 24))) then
      set TABLE = "standard"
   else if ($?have_wide_table && (($X <= 27 && $Y <= 30) || ($X <= 30 && $Y <= 27))) then
   	set TABLE = "wide"
   else if ($?have_large_table && (($X <= 27 && $Y <= 35) || ($X <= 35 && $Y <= 27))) then
   	set TABLE = "large"
   else if ($?have_xl_table && (($X <= 27 && $Y <= 57) || ($X <= 57 && $Y <= 27))) then
   	set TABLE = "extra_large"
   endif

   if (! $?TABLE) then
      echo Warning: No table found for step $step - $X X $Y
      continue
   endif
   
   
   COM cdr_autosetup_control,autosetup=Enable,cfg_outer=,cfg_inner=
   COM cdr_table,table=${TABLE},display=hide
   
   #
   # output for each layer
   #=======================
   foreach layer ($outputLayers)
   
      COM cdr_display_layer,name=$layer,type=physical,display=yes
      COM cdr_work_layer,set_name=cdr,layer=$layer
      COM cdr_table,table=${TABLE},display=hide

      #
      # define the DataBase for the output file
      #=========================================
      switch ($TABLE)
         case "standard":
      	  set DATABASE = "STANDARD"
      	  breaksw
         case "wide":
      	  set DATABASE = "WIDE"
      	  breaksw
         case "large":
      	  set DATABASE = "LARGE"
      	  breaksw
         case "extra_large":
      	  set DATABASE = "XL"
      	  breaksw
         default:
      	  set DATABASE = ""
      endsw
           
      COM cdr_target_db,target_db=${DATABASE}
      
      #
      # define the path to the mount point
      # (possible seperate spool directories according to used table)
      #==============================================================
      switch ($TABLE)
         case "standard":
      	  set path = "$_genesis_root/sys/hooks/cdr/aoimnt/spool"
      	  breaksw
         case "wide":
      	  set path = "$_genesis_root/sys/hooks/cdr/aoimnt/spool"
      	  breaksw
         case "large":
      	  set path = "$_genesis_root/sys/hooks/cdr/aoimnt/spool"
      	  breaksw
         case "extra_large":
      	  set path = "$_genesis_root/sys/hooks/cdr/aoimnt/spool"
      	  breaksw
         default:
      	  set path = ""
      endsw
      
      COM cdr_opfx_output,units=inch,\
	  units_factor=0.1,\
	  path=$path,\
	  scale_x=1,\
	  scale_y=1,\
	  anchor_mode=zero,\
	  anchor_x=0,\
	  anchor_y=0,\
	  target_machine=v300,\
	  break_surf=no,\
	  break_arc=no,\
	  break_sr=no,\
	  break_fsyms=no,\
	  min_brush=4
       COM cdr_display_layer,name=$layer,type=physical,display=no
       echo "$layer end = " `date`
    end

    COM save_job,job=${JOB},override=no
    COM check_inout,mode=in,type=job,job=${JOB}
    COM close_job,job=$JOB
    COM close_form,job=$JOB
    COM close_flow,job=$JOB
    COM cdr_close
end
