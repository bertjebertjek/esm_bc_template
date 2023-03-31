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

#------------------------------------------------------
# walltime should become an argument as well, but hardcoded for now:
# walltime_hr="04" for 30 year jobs, 01 for 5year jobs, set in ln 60
#------------------------------------------------------


# Check if the script is called with arguments and set the corresponding variables
if [ $# -eq 0 ];   then
    echo "No arguments supplied" # if called from current model's dir
	target_path=$PWD # should include model and scen
	queue='casper'
	mem=50
fi
if [ $# -gt 0 ]; then   #  1 arg
	target_path=$1
	queue='casper'
	mem=50
	# echo "    Setting up bias correction jobs to run on $queue (default) with a default memory of $mem GB per job "
fi
if [ $# -gt 1 ]; then   #  2 argument (optional) specifies the queue
	if ! { [ $2 == 'casper' ] || [ $2 == 'cheyenne' ];  }; then
		echo "specify desired queue as either 'cheyenne' , 'casper' , or leave blank for default (casper) "
		echo "  "
		echo " !!!!!  ERROR , STOPPING !!!!!!! "
		echo "  "
		exit 1
	else
		queue=$2  # if the bias correction is to be done on casper or cheyenne....
	fi
fi
if [ $# -gt 2 ]; then   #  3rd arg is mem
	# # if {$3 != a number} ....
	# 		# re='^[0-9]+$'
	# 		# if ! [[ $yournumber =~ $re ]] ; then
	# 		# echo "error: Not a number" >&2; exit 1
	# 		# fi
    # fi
    mem=$3
fi
if [ $# -gt 3 ]; then   #  4th arg specifies 5yrchuncks (bool)
	FiveYearChunks=$4
    if $FiveYearChunks; then 
        echo "    - Jobs will be submitted in five year chunks "
        walltime_hr="01" #check if this is enough (should be)
    else
        walltime_hr="04"
    fi
fi
if [ $# -gt 4 ]; then   #  5th arg specifies exclude_correction (bool)
    ExcludeCorrection=$5
    if $ExcludeCorrection; then  echo "    - Exclude Correction is TRUE "
    fi
fi

echo "    Setting up bias correction jobs to run on  $queue with $mem GB memory and ${walltime_hr}hr walltime per job"



# depending on whether we want 5 year chunks or ~32 year ones, set some parameters:
# Check which scenario / period to set up:
# !!!! NOTe that if you change the years in StartYears or EndYears, you will have to change the .pbs and .nml files in the /01 folder! (and probably the code below will break.)
if $FiveYearChunks; then
    n=5 # would be nice to make this an argument, but this is cumbersome.
    if [[ $target_path == *"ssp"* ]]; then
        echo "    Setting up future period"
        StartYears=($(seq -s " " 2015 $n $((2100-$n)) ))
        EndYears=($(seq -s " " $((2014+$n)) $n 2099 ))
    elif  [[ $target_path == *"historical"* ]]; then
        echo "    Setting up historical period"
        StartYears=($(seq -s " " 1950 $n $((2015-$n)) ))
        EndYears=($(seq -s " " $((1949+$n)) $n 2014 ))
    elif  [[ $target_path == *"template"* ]]; then
        echo "--- In template dir, cannot run duplicate_months.sh from here. Exiting ---"
        exit 1
    fi
else # otherwise we make large blocks of about 30 years. Maybe we can do all at once? It is not that mem intensive after all....
    if [[ $target_path == *"ssp"* ]]; then
        echo "    Setting up future period"
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
fi



# create months>01 & copy the .nml and .pbs files from the /01 folder to the other months:
for mon in ${StringArray[@]}; do

	# make output dir for each month > 01:
	mkdir -p $target_path/$mon

	count=0
	for year in ${StartYears[@]}; do
		year2=${EndYears[count]}
		# echo "start: "$year " end: "$year2  # for debugging

		# copy the contents of the '01' folder to the new month:
		cp $target_path/01/config_${year}-${year2}_01.nml $target_path/$mon/config_${year}-${year2}_$mon.nml
		cp $target_path/01/bias_corr_${year}-${year2}_01.pbs $target_path/$mon/bias_corr_${year}-${year2}_$mon.pbs

		# create 11 job submission scripts:
		if [[ $queue == 'cheyenne' ]]; then 

			echo "qsub $mon/bias_corr_$year-${year2}_$mon.pbs " >> $target_path/submit_pbs_$mon.sh
			echo " " >> $target_path/submit_pbs_$mon.sh

			# also create 01 submission script:
			if [[ $mon == "02" ]]; then
				echo "qsub 01/bias_corr_$year-${year2}_01.pbs " >> $target_path/submit_pbs_01.sh
				echo " " >> $target_path/submit_pbs_01.sh
			fi

		elif [[ $queue == 'casper' ]]; then 
			echo "qsubcasper $mon/bias_corr_$year-${year2}_$mon.pbs " >> $target_path/submit_pbs_$mon.sh
			echo " " >> $target_path/submit_pbs_$mon.sh

			# also create 01 submission script:
			if [[ $mon == "02" ]]; then
				echo "qsubcasper 01/bias_corr_$year-${year2}_01.pbs " >> $target_path/submit_pbs_01.sh
				echo " " >> $target_path/submit_pbs_01.sh
			fi
		fi
		count=$(($count+1))  # counter to loop through end years
	done

	# make job-files executable:
	chmod a+rx $target_path/submit_pbs_$mon.sh
	chmod a+rx $target_path/submit_pbs_01.sh

	# Modify text inside the .nml and .pbs files:
	sed -i "s+_01.txt+_$mon.txt+g" $target_path/$mon/config_*.nml
	sed -i "s+_01.nc+_$mon.nc+g" $target_path/$mon/config_*.nml

	sed -i "s+bc01+bc$mon+g" $target_path/$mon/bias_corr_*.pbs  # Job ID
	sed -i "s+01/c+$mon/c+g" $target_path/$mon/bias_corr_*.pbs
 	sed -i "s+_01.nml+_$mon.nml+g" $target_path/$mon/bias_corr_*.pbs

	# set memory
	sed -i "s+mem=XX_GB+mem=${mem}GB+g" $target_path/$mon/bias_corr_*.pbs
	sed -i "s+mem=XX_GB+mem=${mem}GB+g" $target_path/01/bias_corr_*.pbs  # dont forget 01 dir :)

	# set walltime
	sed -i "s+walltime=12:00:00+walltime=${walltime_hr}:00:00+g" $target_path/$mon/bias_corr_*.pbs
	sed -i "s+walltime=12:00:00+walltime=${walltime_hr}:00:00+g" $target_path/01/bias_corr_*.pbs  # dont forget 01 dir :)


	# if selected queue is cheyenne, modify the job scripts wrt. queue 
	if [[ $queue == 'cheyenne' ]]; then
		sed -i "s+casper+regular+g" $target_path/$mon/bias_corr_*.pbs
		sed -i "s+casper+regular+g" $target_path/01/bias_corr_*.pbs
	fi

    # If exclude correction is true, set it to true in the namellists as well:
    if $ExcludeCorrection; then
        sed -i "s+exclude_correction=False+exclude_correction=True+g" $target_path/$mon/config_*.nml
        sed -i "s+exclude_correction=False+exclude_correction=True+g" $target_path/01/config_*.nml
    fi

done