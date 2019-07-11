# hitndriveCPPr

This repository contains R-wrapper functions to execute **HIT'nDRIVE** (<https://github.com/sfu-compbio/hitndrive>) tool. These R functions are specifically designed to work with the *Slurm version 19.05* linux cluster.

Please refer to <https://github.com/sfu-compbio/hitndrive> if your are working on a different environment.

### Publications
----
- Shrestha R, Hodzic E, Sauerwald T, Dao P, Yeung J, Wang K, Anderson S, Haffari G, Collins CC, and Sahinalp SC. 2017. HIT’nDRIVE: Patient-Specific Multi-Driver Gene Prioritization for Precision Oncology. Genome Research. doi:10.1101/gr.221218.117 (http://dx.doi.org/10.1101/gr.221218.117)
- Shrestha R, Hodzic E, Yeung J, Wang K, Sauerwald T, Dao P, Anderson S, Beltran H, Rubin MA, Collins CC, Haffari G and Sahinalp SC. 2014. HIT’nDRIVE: Multi-driver gene prioritization based on hitting time. Research in Computational Molecular Biology: 18th Annual International Conference, RECOMB 2014, Pittsburgh, PA, USA, April 2-5, 2014, 293–306. (https://link.springer.com/chapter/10.1007/978-3-319-05269-4_23)

<br/><br/>

## Setup
#### System Requirements
- make (version 3.81 or higher)
- g++ (GCC version 4.1.2 or higher)
- IBM ILOG CPLEX Optimization Studio
- R (version 3.5.0 or higher)

#### Installation
First install the HIT'nDRIVE tool containing the C++ scripts (from <https://github.com/sfu-compbio/hitndrive>), clone the repo using following command
```sh
git clone git@github.com:sfu-compbio/hitndrive.git
```
Then copy the `hitndriveCPP_main.R` file to the same directory where the CPP scripts from above is installed.

<br/><br/>

## How to run HIT'nDRIVE using hitndriveCPPr
See the wiki for detailed instruction on executing HIT'nDRIVE as well as instructions for input data preparations.

#### 1. Create Directory Structure
First create the directory structure as instructed below. `<batch.name>` is user defined directory, for example, the name of your project.

```sh
../hitndrive/
    |-- lib/
    |-- graph/
    |-- analysis/
        |-- <batch.name>/
```

#### 2. Install and Place necessary files
- Copy all C++ scripts downloaded from <https://github.com/sfu-compbio/hitndrive> to the following path `../hitndrive/lib/`
- Configure `../hitndrive/lib/Makefile` with path to CPLEX as instructed in <https://github.com/sfu-compbio/hitndrive>
- Run `make` command in `../hitndrive/lib/` as instructed in <https://github.com/sfu-compbio/hitndrive>
- Copy `hitndriveCPP_main.R` file from this repo. to `../hitndrive/lib/`
- Copy input data files (alteration and expression-outlier) to the following path `../hitndrive/analysis/<batch.name>/` 
- Copy network graph (interaction network) to the following path `../hitndrive/graph/` 

#### 3. Generation of Graph Influence Matrix
If installing for the first time execute `buildGraph()` and `getHTMatrixInversionR()` functions in R. Skip this if you have already executed these two functions before.
```sh
buildGraph(dir.wrk, batch.name, network.name, file.network)

getHTMatrixInversionR(dir.wrk, batch.name, network.name)
```

#### 4. Generating and Solving ILP
Then execute `runHITnDRIVE()` function. This will first generate the CPLEX INPUT FILES (.lp) within the following path `../hitndrive/analysis/<batch.name>/scripts`
```sh
# GENERATE ILP FILES ---
runHITnDRIVE(dir.wrk, batch.name, output.name, network.name, filename.alteration, filename.outlier, generateILP=TRUE)

# THEN SUBMIT YOUR JOB(s) IN SLURM CLUSTER MACHINE TO RUN CPLEX ILP SOLVER ---
$ sbatch [../analysis/<batch.name>/scripts/main.sh]

# AFTER YOU HAVE OBTAINED SOLUTION FILES FROM CPLEX, RUN THIS TO GET FINAL DRIVER GENES ---
runHITnDRIVE(dir.wrk, batch.name, output.name, network.name, filename.alteration, filename.outlier, generateILP=FALSE)
```

All resulting files can be found within the following path `../hitndrive/analysis/<batch.name>/`  
