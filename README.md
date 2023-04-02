# ESM bias Correction workflow

This README describes the procedure for the Bias correction of 3D and 2D (separate) fields for CMIP6 Global Climate Models (GCM's).

NOTE: this repository only contains the tempate folder structure, the actual fortran code can be found on [the NCAR github page](https://github.com/NCAR/ESM_bias_correction)


## <a name="install"></a>Installation


The fortran code can be found here: [github.com/NCAR/ESM_bias_correction](https://github.com/NCAR/ESM_bias_correction). (Compile and link to the executable `esm_bias_correction` in the main folder.) Make sure to use the branch 'discontinuous time' (currently only available at [Bert's github](https://github.com/bertjebertjek/ESM_bias_correction/tree/discontinuous_time), awaiting PR on NCAR github ) if you want to bias correct per month. Otherwise the time variable output from the esm fortran code will be incorrect, and the postprocessing scripts will result in an error. You can overwrite the erroneous time variable but this can easily lead to mistakes.

The compressed CMIP6 models: `/glade/campaign/ral/hap/trude/CMIP6/FORCING/NOAA_SNOW`

Clone this repo (esm_bc_template) and link to the compiled fortran code's executable.

## Usage

The following steps are required before the Fortran code can be run. 
### 0. Download GCM data and process
The GCM data need to be downloaded and depending on the model, certain variables need to be calculated. This is not described here (yet).

### 1. Make monthly files
Both the GCM data and the ERAi data need to be separated into monthly files, so the bias correction can be done per month. 
#### 1A. Make monthly GCM files
Divide the GCM output into monthly files. This means grouping all the january's, all the february's etc. 
Use the script `create_monthly_files_prl.py` in the folder preprocess. It is paralellized over 12 months/cores. Note that the time encoding in this script should NOT be changed from `days since 1900`, since this is what the ESM fortran code expects. Otherwise the output timestamps will be incorrect!

Specify the models, scenario's/periods and paths in lines 28-36 of the script `create_monthly_files_prl.py`:

```python
scenarios=['historical', 'ssp585','ssp370']
modLs=['MIROC-ES2L'] #'CanESM5','CESM2','CMCC-CM2-SR5','MIROC-ES2L','MPI-M.MPI-ESM1-2-LR','NorESM2-MM',  'CNRM-ESM2-1'

# The raw GCM data, decompressed (!), yearly :
dir_raw_decmp = '/glade/scratch/bkruyt/CMIP6/raw/'

# the directory to store the monthly files made in this script:
dir_raw_month = '/glade/scratch/bkruyt/CMIP6/raw_month/'
```

Then submit (modify queue if you want to submit to cheyenne):

``` bash
qsubcasper create_monthly_files_prl.pbs
```

#### 1B. Make monthly ERAi files
Similarly, we need monthly files for ERA-Interim to bias correct 'towards'. These may already be available at `/glade/u/home/currierw/scratch/erai/convection/erai/clipped_by_month_convert_SST/merged_by_month_bc` (Western US) or  `/glade/scratch/bkruyt/erai/erai_greatlakes_month` (Great lakes domain). If not, they can be made from standard ERAi files with the Jupyter notebook found in `preprocess/create_monthly_ERAi_files.ipynb`. Note that these files do need to be named `erai_01.nc` etc. for the bias-correction code to work.

### 2. Apply ESM bias correction (3D)
The 3D fields are bias corrected using the fortran code (see [installation](#install)), but first a folder structure must be set up:

#### 2A. Setup folder structure
This involves an elaborate folder structure. However the process is somewhat automated. A template folder structure can be found on [Bert's github](https://github.com/bertjebertjek/esm_bc_template). the `MAIN.sh` file is the only one that needs to be modified. Specify the model, scenarios and paths in the section `USER SETTINGS` (lines 15-35):

```bash
#---------------------------- USER SETTINGS:  -----------------------------------

# the models for which directories will be created:
# declare -a ModelArray=("CanESM5" "CESM2" "CMCC-CM2-SR5" "CNRM-ESM2-1" "HadGEM3-GC31-LL" "MIROC-ES2L" "MPI-ESM1-2-HR" "MRI-ESM2-0" "NorESM2-MM" "UKESM1-0-LL")
declare -a ModelArray=("NorESM2-MM" "CanESM5"  )

# # The scenarios 
declare -a ScenarioArray=("historical" "ssp585" )
# scen="ssp585" # for scen in scnearios

# specify the folder where the model/scenario ESM stucture will be set up:
root_dir="/glade/work/bkruyt/ESM_bias_correction/CMIP6"

# specify the location of the monthly GCM files, created with the script create_monthly_files_BK.sh. This path will be linked to.
GCM_month="/glade/scratch/bkruyt/CMIP6/raw_month"

# specify location of the era-interim files that will be used to bias correct to. Note that if domain is smaller than the GCM, the output will be cropped to this domain:
# erai_path="/glade/u/home/currierw/scratch/erai/convection/erai/clipped_by_month_convert_SST/merged_by_month_bc" # W-COnus domain
erai_path="/glade/scratch/bkruyt/erai/erai_greatlakes_month"  # Great Lakes domain

# specify the output folder on scratch, this will be created and linked to:
scratch_output="/glade/scratch/bkruyt/CMIP6/monthly_BC_3D"

# Choose queue to specify in job scripts ('cheyenne' or 'casper')
queue='cheyenne'

# The memory in GB for each job. (Note that regular has a 100GB limit, and casper 350 (or 500 for large mem nodes))
mem=20

# The number of years per job, currently only options are 5 years (FiveYearChunks=true), or ~30 years (FiveYearChunks= -you guessed it- false).
FiveYearChunks=true

# Exclude correction? (This is an option in the Fortran ESM bias correction, and is set via the config.nml)
ExcludeCorrection=true

```


Finally set up the structure by running main.sh:
```bash
sh MAIN.sh
```
This will prompt you to confirm the setup of the folders for the model/scenario combinations listed in the USER SETTINGS.
```
Setting up Model/scenario structure in root:  /glade/work/bkruyt/ESM_bias_correction/CMIP6
 For the following models : NorESM2-MM CanESM5
 For the following scenarios : historical ssp585
 Do you wish to proceed? [y/n]
```

Type 'y' and all will be set up and ready to roll.


#### 2B. Run 3D ESM bias correction

The procedure under 2A will have created job scripts in `$root_dir/model/scenario`. per Model/scenario folder structure, run the script `SUBMIT_ALL.sh`, which will submit jobs for all months, divided into ~30y periods.

```bash
sh SUBMIT_ALL.sh
```
This will launch all job scripts for the model/scenario combination. Currently a standard walltime of 4 hrs is hardcoded in `duplicate_months.sh`.

### 3 Postprocess: Combine monthly files

After the bias correction has run, the output dir will have files per month and ~30y time-period. To combine these into yearly files, use the notebook 'stich_together_after_ESM.ipynb' in the postprocessing folder.

### 4 2D bias correction. 

The fortran code only corrects the 3D variables. To additionally correct SST/tskin and Cp, use either the notebook or the python script + pbs jobscript in the folder `2D_ESM_bias_correction`. Set the correct input- and ouput paths, and run.

```python
### SET paths and parameters  ####

# ERAi
# era_path='/glade/u/home/currierw/scratch/erai/convection/erai/clipped_by_month_convert_SST/'
# era_path='/glade/scratch/bkruyt/erai/erai_greatlakes_month/' # not chronological because monthly + buffer
era_path='/glade/scratch/gutmann/icar/forcing/erai_conus/monthly/'  # path with erai files (chronological) cp not corrected!! And CONUS wide...

modelLs       = ['MIROC-ES2L']; i=0
scenarios     = ['ssp370'] #['ssp585'] #

raw_dir = '/glade/scratch/bkruyt/CMIP6/raw/' #MIROC-ES2L/historical' 
in_dir = '/glade/scratch/bkruyt/CMIP6/BC_3D_merged/' #MIROC-ES2L/historical' 
out_dir='/glade/scratch/bkruyt/CMIP6/BC_2D_3D/'
```

Not that the code will automatically correct the erai convective precipitation to mm/s if it does not find an attribute called `Note` in the Cp variable that is defined as ` 'Converted from mm/time step (6 hours) to mm/s by dividing by 21600' `

### Footnotes
Be sure to check the final files an see if they make sense. I cannot guarantee that there might be issues with certain models or fringe-case scenarios. There are some scripts in the folder `helper_scripts` to check for correct time, but as always look critical at the results and when in doubt, do reach out.
Happy modeling!


```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

And please include comments in your code so it is understandable why you do what you do. A line of comment per line of code is a good rule of thumb. 


## License

[MIT](https://choosealicense.com/licenses/mit/)