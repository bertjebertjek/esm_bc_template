# ESM bias Correction

Bias correction of 3D and 2D (separate) fields for CMIP6 Global Climate Models (GCM's).

## Installation

The fortran code can be found here: `https://github.com/NCAR/ESM_bias_correction/`

The compressed CMIP6 models: `/glade/campaign/ral/hap/trude/CMIP6/FORCING/NOAA_SNOW`



## Usage

Several pre- and postprocessing steps are required before the Fortran code can be run. 

### 1. Make monthly GCM files
Divide the GCM output into monthly files. This means grouping all the january's, all the february's etc. 
Use the script `create_monthly_files_BK.py` 

! Specify the models and scenario's /periods in lines 28-36 of the script `create_monthly_files_BK.py`:

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
qsubcasper create_monthly_files_BK.pbs
```

### 2. Apply ESM bias correction (3D)

#### 2A. Setup folder structure
This involves an elaborate folder structure. However the process is somewhat automated. A template folder structure can be found here: [INSERT esm_bc_template github link]. the `MAIN.sh` file is the only one that needs to be modified. Specify the model, scenarios and paths in the section `USER SETTINGS` (lines 15-35):

```bash
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

```
This assumes you will use the monthly erai files as a reference to bias correct 'towards' , these are linked in the esm_template directory:
`erai -> /glade/u/home/currierw/scratch/erai/convection/erai/clipped_by_month_convert_SST/merged_by_month_bc`. Check these files are present, or if you want to use something else, modify this link.

Finally set up the structure by running main.sh:
```bash
sh MAIN.sh
```
(Note: This procedure creates scripts for ~ 30y runs. Depending on memory availability you may want to modify this. To do so, modify the script `duplicate_months.sh` in esm_bc_template, look for the variables StartYears and EndYears.) 

#### 2B Run 3D ESM bias correction

The procedure under 2A will have created job scripts. per Model/scenario folder structure, run the script `SUBMIT_ALL.sh`, which will submit jobs for all months, divided into ~30y periods. 

```bash
sh SUBMIT_ALL.sh
```
