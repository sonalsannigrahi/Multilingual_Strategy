#!/bin/bash
#SBATCH --job-name=single_thread      # Job name
#SBATCH --mail-type=END,FAIL          # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=email@inria.fr    # Where to send mail 
#SBATCH --ntasks=1                    # Run on a single CPU
#SBATCH --mem=100m                    # Job memory request; if unit is not specified MB will be assumed
#SBATCH --time=00:01:00               # Time limit hrs:min:sec
#SBATCH --output=single_thread_%j.log # Standard output and error log


bash get_data.sh
bash process_data.sh


