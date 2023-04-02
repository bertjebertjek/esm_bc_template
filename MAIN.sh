#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copy files and folder structure from template dir to each model (ModelArray)'s dir (will be made)
#
# see README.md for instructions
#
#
# Authors: Bert Kruyt, Abby Smith, Ryan Currier,  NCAR RAL, 2022-23
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


#--------------------------------       USER SETTINGS:       --------------------------------------

# the models for which directories will be created:
# declare -a ModelArray=("CanESM5" "CESM2" "CMCC-CM2-SR5" "CNRM-ESM2-1" "HadGEM3-GC31-LL" "MIROC-ES2L" "MPI-ESM1-2-HR" "MRI-ESM2-0" "NorESM2-MM" "UKESM1-0-LL")
declare -a ModelArray=("CMCC-CM2-SR5"  "NorESM2-MM")  #("CanESM5") #  test

# # The scenarios
# declare -a ScenarioArray=("historical" "ssp585" )  # test
# declare -a ScenarioArray=("historical")
declare -a ScenarioArray=("historical" "ssp585" "ssp370")

# specify the folder where the model/scenario ESM stucture will be set up:
root_dir="/glade/work/bkruyt/ESM_bias_correction/CMIP6"

# specify the location of the monthly GCM files, created with the script create_monthly_files_BK.sh. This path will be linked to.
GCM_month="/glade/scratch/bkruyt/CMIP6/raw_month"

# specify location of the era-interim files that will be used to bias correct to. Note that if domain is smaller than the GCM, the output will be cropped to this domain:
# erai_path="/glade/u/home/currierw/scratch/erai/convection/erai/clipped_by_month_convert_SST/merged_by_month_bc" # W-COnus domain
erai_path="/glade/scratch/bkruyt/erai/erai_greatlakes_month"  # Great Lakes domain

# spedify the location of the compiled fortran code, esm_bias_correction:
# esm_exe='/glade/work/bkruyt/ESM_bias_correction/CMIP6/esm_bias_correction'
esm_exe='/glade/work/bkruyt/ESM_bias_correction/ESM_bias_correction/esm_bias_correction'

# specify the output folder on scratch, this will be created and linked to:
scratch_output="/glade/scratch/bkruyt/CMIP6/monthly_BC_3D"

# Choose queue to specify in job scripts ('cheyenne' or 'casper'):
queue='cheyenne'

# The memory in GB for each job. (Note that regular has a 100GB limit, and casper 350 (or 500 for large mem nodes))
mem=20

# The number of years per job, currently only options are 5 years, or ~30 years.
FiveYearChunks=false

# Exclude correction? (This is an option in the Fortran ESM bias correction, and is set via the config.nml)
ExcludeCorrection=false

#---------------------------- No need to modify below this line  -----------------------------------



echo "  "
echo " Setting up Model/scenario structure in root: " $root_dir
echo " For the following models : "${ModelArray[*]}
echo " For the following scenarios : "${ScenarioArray[@]}   # "$@" expands each element as a separate argument, "$*" expands to the arguments merged into one argument.
echo " Jobs will run on $queue with $mem GB of memory."
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

		{ # try
			rsync -r --exclude 'helper_scripts' --exclude 'duplicate_months.sh' --exclude 'MAIN.sh' *  $root_dir/$mdl/$scen

		} || { # catch (in case rsync isn't available or some other error. )
			echo "   rsync error"
			cp -r * $root_dir/$mdl/$scen
			rm -r $root_dir/$mdl/$scen/preprocess $root_dir/$mdl/$scen/helper_scripts $root_dir/$mdl/$scen/duplicate_months.sh $root_dir/$mdl/$scen/MAIN.sh
		}

		# make GCM file list files:
		sed -i "s+TEMPLATE_MODEL+$mdl+g" $root_dir/$mdl/$scen/file_list_GCM_*.txt
		# link to monthly GCM files:
		ln -sfn $GCM_month/$mdl/$scen/ $root_dir/$mdl/$scen/GCM
		# link to monthly ERAi files:
		ln -sfn $erai_path $root_dir/$mdl/$scen/erai
		# link to monthly ERAi files:
		ln -sfn $esm_exe $root_dir/$mdl/$scen/esm_bias_correction
		# link to output: (make if it doesnt exist yet)
		mkdir -p $scratch_output/$mdl/$scen/ 
		ln -sfn $scratch_output/$mdl/$scen/ $root_dir/$mdl/$scen/output


		# Call the duplicate months script with arguments:
		# /bin/bash duplicate_months.sh "$root_dir/$mdl/$scen" $queue $mem
		/bin/bash duplicate_months.sh "$root_dir/$mdl/$scen" $queue $mem $FiveYearChunks $ExcludeCorrection


		echo "    Finished ESM bias correction set-up for $root_dir/$mdl/$scen"
		echo "   "

	done
done

echo "    ************    Done!   ***************  "
echo "   "