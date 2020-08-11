#
# This script is for installing the checklists which are required by (vision) CDR interface.
# A job (cdr_checklist) which contains the checklists is imported, and the checklists
# are copied to the local genesislib. 
# 
# date: 20 aug 2001
#
# updates:
# zvika, 24 set 2002:
# - enable the script to work on an NT platform by adding "uname -s".
#
# ===============================================================================



# define the Genesis system environment
#=======================================

if ($?GENESIS_DIR) then 
   set _genesis_root = $GENESIS_DIR 
endif 

if ($?GENESIS_EDIR) then 
   set _genesis_edir = $GENESIS_EDIR 
endif 

if (! $?GENESIS_TMP) then
   set GENESIS_TMP = $_genesis_root/tmp
endif

if ($_genesis_edir =~ /* || $_genesis_edir =~ ?:*) then 
   set PATH = ($_genesis_edir/) 
else 
   set PATH = ($_genesis_root/$_genesis_edir/) 
endif 

set guifile = $GENESIS_TMP/gui_win.$$
set tmpfile = $GENESIS_TMP/data_tmp.$$
set CURRENT_OS = `uname -s`

#
# find the database were the genesislib is defined.
#==================================================

switch ($CURRENT_OS) 
        case "SunOS" 
            set a = `$PATH/misc/dbutil list jobs genesislib`
            set AWK = "nawk" 
            breaksw 
        case "WINDOWS_NT" 
            set a = `$PATH/misc/dbutil.exe list jobs genesislib`
            set AWK = "gawk.exe" 
            set suffix = ".exe" 
            breaksw 
        case "HP-UX" 
            set a = `$PATH/misc/dbutil list jobs genesislib`
            set AWK = "awk" 
            breaksw 
        case "Linux"
            set a = `$PATH/misc/dbutil list jobs genesislib`
            set AWK = "awk" 
            breaksw  
        default: 
            set a = `$PATH/misc/dbutil list jobs genesislib`
            set AWK = "awk" 
    endsw  
    
set b = ($a)
set database_name = $b[4]

#
# check if we have the two checklist in are genesislib.
#======================================================
COM check_inout,mode=out,type=job,job=genesislib
COM open_job,job=genesislib

COM info,out_file=$GENESIS_TMP/info.out.$$, \
   args= -t check -e genesislib/checklib/cdr_clr_nfp_chk -d exists
source $GENESIS_TMP/info.out.$$
set nfp_chk = $gEXISTS
COM info,out_file=$GENESIS_TMP/info.out.$$, \
   args= -t check -e genesislib/checklib/cdr_signal_lyr_chk -d exists
source $GENESIS_TMP/info.out.$$
set signal_lyr_chk = $gEXISTS

if (($signal_lyr_chk == yes) || ($nfp_chk == yes)) then 
	
	#
	# Use of GUI to report that checklist exsits.
	#============================================
	echo "WIN 200 200"                                   		> $guifile
	echo "LABEL one or two of the checklists needed are allready" 	>> $guifile
	echo "LABEL existing if you want to install new checklists" 	>> $guifile 
	echo "LABEL you need to manually remove the ones that are" 	>> $guifile
	echo "LABEL allready installed" 				>> $guifile
	echo "END"					      		>> $guifile
	gui $guifile >! $tmpfile
	source $tmpfile
	rm -f $tmpfile

	echo " one or two of the checklist all ready extist and if you want to install new checklists you need to manually remove the ones that are there allready"
else

	#
	# check if we don't have allready a job with this name.
	#======================================================
	COM info,out_file=$GENESIS_TMP/info.out.$$, \
	   args= -t job -e cdr_checklist -d exists
	source $GENESIS_TMP/info.out.$$
	echo $gEXISTS
	set job_exists = $gEXISTS
	echo $job_exists
	if ($job_exists == yes) then 
		COM rename_entity,job=,is_fw=no,type=job,fw_type=form,name=cdr_checklist,new_name=cdr_checklist.orig
	endif
	
	#
	# Import job cdr_checklist to Genesis.
	#=====================================
	COM import_job,db=$database_name,path=$GENESIS_DIR/sys/hooks/cdr/cdr_checklist.tgz,name=cdr_checklist

	#
	# open job cdr_checklist and copy the two checklists to genesislib.
	#==================================================================
	COM open_job,job=cdr_checklist
	COM open_entity,job=cdr_checklist,type=step,name=chklists,iconic=no
	COM units,type=inch
	COM chklist_to_lib,chklist=cdr_clr_nfp_chk
	COM chklist_to_lib,chklist=cdr_signal_lyr_chk

	#
	# remove job cdr_checklist.
	#==========================
	COM delete_entity,job=,type=job,name=cdr_checklist
	COM close_form,job=cdr_checklist
	COM close_flow,job=cdr_checklist
	if ($job_exists == yes) then
		COM rename_entity,job=,is_fw=no,type=job,fw_type=form,name=cdr_checklist.orig,new_name=cdr_checklist
	endif
endif

COM save_job,job=genesislib,override=no
COM check_inout,mode=in,type=job,job=genesislib
COM close_job,job=genesislib
