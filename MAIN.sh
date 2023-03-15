#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#
# Copy files and folder structure from template dir to each model (ModelArray)'s dir (will be made)
#
#
# run from CMIP6/template/  (CESM2 is template model)
#
# Authors: Abby Smith, Ryan Currier, Bert Kruyt, NCAR RAL, 2022-23
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


#---------------------------- USER SETTINGS:  -----------------------------------

# the models for which directories will be created:
# declare -a ModelArray=("CanESM5" "CESM2" "CMCC-CM2-SR5" "CNRM-ESM2-1" "HadGEM3-GC31-LL" "MIROC-ES2L" "MPI-ESM1-2-HR" "MRI-ESM2-0" "NorESM2-MM" "UKESM1-0-LL")
declare -a ModelArray=("NorESM2-MM" "CanESM5"  )  # test

# # The scenarios 
declare -a ScenarioArray=("historical" "ssp585" )  # test
# scen="ssp585" # for scen in scnearios

# specify the folder where the model/scenario ESM stucture will be set up:
root_dir="/glade/work/bkruyt/ESM_bias_correction/CMIP6"

# specify the location of the monthly GCM files, created with the script create_monthly_files_BK.sh. This path will be linked to.
GCM_month="/glade/scratch/bkruyt/CMIP6/raw_month"

# specify the output folder on scratch, this will be created and linked to:
scratch_output="/glade/scratch/bkruyt/CMIP6/monthly_BC_3D"


#---------------------------- No need to modify below this line  -----------------------------------



echo "  "
echo " Setting up Model/scenario structure in root: " $root_dir 
echo " For the following models : "${ModelArray[*]}
echo " For the following models : "${ScenarioArray[@]}   # "$@" expands each element as a separate argument, "$*" expands to the arguments merged into one argument.
echo " Do you wish to proceed? [y/n]"

read varname
# echo $varname
if [[ $varname != 'y' ]]; then
	echo " Exit"
    exit 1
else
	echo " "
    echo " Here we go!"
	echo " "
fi


for mdl in ${ModelArray[@]}; do
	for scen in ${ScenarioArray[@]}; do
		
		echo "    Setting up $root_dir/$mdl/$scen"

		# make dir for model and scenario if it does not yet exist:
		mkdir -p $root_dir/$mdl/$scen

		# copy the contents of template to model/scen dir:
		rm -r $root_dir/$mdl/$scen/*
			cp -r * $root_dir/$mdl/$scen

		# make GCM file list files:
		sed -i "s+TEMPLATE_MODEL+$mdl+g" $root_dir/$mdl/$scen/file_list_GCM_*.txt
		# link to monthly GCM files:
		ln -sfn $GCM_month/$mdl/$scen/ $root_dir/$mdl/$scen/GCM
		# link to output: (make if it doesnt exist yet)
		mkdir -p $scratch_output/$mdl/$scen/ 
		ln -sfn $scratch_output/$mdl/$scen/ $root_dir/$mdl/$scen/output

		# wait 10

		# Call the duplicate months script with argument:
		/bin/bash duplicate_months.sh "$root_dir/$mdl/$scen"
		# sh duplicate_months.sh "$root_dir/$mdl/$scen"

		# wait 10
		echo "    Finished ESM bias correction set-up for $root_dir/$mdl/$scen"
		echo "   "

	done
done

