#!/bin/bash
#SBATCH --account=reedsos
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mail-user=maxwell.brown@nrel.gov
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mem=60000      # RAM in MB

#load your default settings
. $HOME/.bashrc