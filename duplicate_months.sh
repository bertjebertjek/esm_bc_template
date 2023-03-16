#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
#
# Duplicate the month 01 folder to the other 11 months, and modify their contents. 
#
# 
#
#
# Authors: Abby Smith, Ryan Currier, Bert Kruyt, NCAR RAL, 2022-23
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


declare -a StringArray=("02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12")

# Check if the script is called with an argument (the target path), and if not use current dir as target:
if [ $# -eq 0 ];   then
    echo "No arguments supplied" # if called from current model's dir
	target_path=$PWD # should include model and scen
elif [ $# -eq 1 ]; then   #  1 arg
	# echo " 1 argument supplied: "$1
	target_path=$1
elif [ $# -eq 2 ]; then   #  1 arg
	# echo " 1 argument supplied: "$1
	target_path=$1
	queue=$2  # if the bias correction is to be done on casper or cheyenne.... To DO!!!
fi

# Check which scenario / period to set up:
# !!!! NOTe that if you change the years in StartYears or EndYears, you will have to change the .pbs and .nml files in the /01 folder!
if [[ $target_path == *"ssp"* ]]; then
	echo "    Setting up future period"
	# full range may be too much for the mem demand, cut up into ~30 year chunks?
	declare -a StartYears=("2015" "2047" "2079" )
	declare -a EndYears=("2046" "2078" "2100" )
elif  [[ $target_path == *"historical"* ]]; then
	echo "    Setting up historical period"
	declare -a StartYears=("1950" "1982")
	declare -a EndYears=("1981" "2014")
elif  [[ $target_path == *"template"* ]]; then
	echo "--- In template dir, cannot run duplicate_months.sh from here. Exiting ---"
	exit 1
fi


# create months>01 & copy the .nml and .pbs files from the /01 folder to the other months:
for mon in ${StringArray[@]}; do

	mkdir -p $target_path/$mon
	# for year in {1950..2095..5}; do  # Abby's code for 5y chuncks
		# year2=$((year + 4))
	count=0
	for year in ${StartYears[@]}; do
		year2=${EndYears[count]}
		# echo "start: "$year " end: "$year2  # for debugging

		# make generic files in 01!! 
				
		cp $target_path/01/config_${year}-${year2}_01.nml $target_path/$mon/config_${year}-${year2}_$mon.nml
		cp $target_path/01/bias_corr_${year}-${year2}_01.pbs $target_path/$mon/bias_corr_${year}-${year2}_$mon.pbs
		

		# create 11 job submission scripts (this does not create 01!)
		echo "qsubcasper $mon/bias_corr_$year-${year2}_$mon.pbs " >> $target_path/submit_pbs_$mon.sh
		echo " " >> $target_path/submit_pbs_$mon.sh

		# also create 01 submission script:
		if [[ $mon == "02" ]]; then
			echo "qsubcasper 01/bias_corr_$year-${year2}_01.pbs " >> $target_path/submit_pbs_01.sh
			echo " " >> $target_path/submit_pbs_01.sh
		fi

		# N.B. change qsubcasper to qsub for cheyenne sub

		count=$(($count+1))  # counter to loop through end years
	done



	# Modify text inside the .nml and .pbs files
	sed -i "s+_01.txt+_$mon.txt+g" $target_path/$mon/config_*.nml
	sed -i "s+_01.nc+_$mon.nc+g" $target_path/$mon/config_*.nml
	sed -i "s+bc01+bc$mon+g" $target_path/$mon/bias_corr_*.pbs  # BK addition PBS -N
	sed -i "s+01/c+$mon/c+g" $target_path/$mon/bias_corr_*.pbs
 	sed -i "s+_01.nml+_$mon.nml+g" $target_path/$mon/bias_corr_*.pbs
done