### FUNCTION: runHITnDRIVE() ---
runHITnDRIVE <- function(dir.wrk, batch.name, output.name, network.name, filename.alteration, filename.outlier, alpha, beta, gamma, file.seed.genes="NULL", generateILP){
    if(generateILP == TRUE){
        get.parms(dir.wrk, batch.name, output.name, alpha, beta, gamma)
        prepareHITnDRIVEscript(dir.wrk, batch.name, network.name, filename.alteration, filename.outlier, file.seed.genes)
    }else {
        getPatientDrivers(batch.name, output.name)
    }        
}

### FUNCTION: get.dirs() ---
get.dirs <- function(dir.wrk, batch.name){
    dir.network <- file.path(dir.wrk, "graph")
    dir.lib <- file.path(dir.wrk, "lib")
    dir.analysis <- file.path(dir.wrk, "analysis")    
    dir.batch <- file.path(dir.analysis, batch.name)
    dir.script <- file.path(dir.batch, "scripts")

    suppressWarnings(dir.create(dir.script, showWarnings=FALSE))

    list.dirstruct <- list(dir.network, dir.lib, dir.analysis, dir.batch, dir.script)
    return(list.dirstruct)
}

### FUNCTION: get.parms() ---
get.parms <- function(dir.wrk, batch.name, output.name, alpha, beta, gamma){
    cat(paste(Sys.time()), "PARAMETER FILE : CREATING ...","\n", sep="\t")

    # GET DIRS ---
    dir.batch <- get.dirs(dir.wrk, batch.name)[[4]]

    # PARAMETER COMBINATIONS ---
	par <- expand.grid(gamma, alpha, beta)
	colnames(par) <- c("gamma","alpha","beta")
	par <- par[order(par$gamma, par$beta, decreasing=FALSE),]
	par <- par[which(apply(par, 1, function(x) ifelse(x[2] >= x[3], 1, 0)) == 1),]
		
	if(nrow(par) == 0){
		stop(paste(Sys.time(), "ERROR! HIT'nDRIVE expects alpha >= beta. Please correct simulation values.", sep="\t"))
	}

    if(nrow(par) <= 99){
        par$outputName <- paste(output.name, sprintf("%02d", 1:nrow(par)), sep="_")
    }else if(nrow(par) <= 999){
        par$outputName <- paste(output.name, sprintf("%03d", 1:nrow(par)), sep="_")
    }

	print(par)

    # WRITE OUTPUT ---
    file.par <- file.path(dir.batch, "hitndrive_params.tsv")
	write.table(par, file.par, sep="\t", row.names=FALSE, col.names=TRUE, quote=FALSE)

    cat(paste(Sys.time()), "PARAMETER FILE : CREATED ...","\n", sep="\t")
}

### FUNCTION: prepareHITnDRIVEscript() ---
prepareHITnDRIVEscript <- function(dir.wrk, batch.name, network.name, filename.alteration, filename.outlier, file.seed.genes="NULL"){
    cat(paste(Sys.time()), "HIT'nDRIVE SCRIPT : CREATING ...","\n", sep="\t")

    # GET DIRS ---
    dir.network <- get.dirs(dir.wrk, batch.name)[[1]]    
    dir.lib <- get.dirs(dir.wrk, batch.name)[[2]]
    dir.batch <- get.dirs(dir.wrk, batch.name)[[4]]
    dir.script <- get.dirs(dir.wrk, batch.name)[[5]]

    # DEFINE FILES ---
    file.hnd <- file.path(dir.lib, "hitndrive")
    file.alt <- file.path(dir.batch, filename.alteration)
    file.out <- file.path(dir.batch, filename.outlier)
    file.nodes <- file.path(dir.network, paste(network.name, "nodes", sep="."))
    file.infmatrix <- file.path(dir.network, paste(network.name, "ht", sep="."))
    file.par <- file.path(dir.batch, "hitndrive_params.tsv")

    # LOAD PARAMETER FILE ---
    par <- read.delim(file.par, header=TRUE, stringsAsFactors=FALSE)

    # CALL get.cmd() ---
    list.main <- list()
    for(i in 1:nrow(par)){
        val_gamma <- par$gamma[i]
        val_alpha <- par$alpha[i]
        val_beta <- par$beta[i]
        val_outname <- par$outputName[i]

        cmd.slurm <- get.slurm(val_outname, hrs="12", min="00", sec="00", val_memory="700G", val_cpu=64, val_node=1)
        cmd <- get.cmd(dir.batch, file.hnd, file.alt, file.out, file.nodes, file.infmatrix, file.seed.genes, val_gamma, val_alpha, val_beta, val_outname)
        cmd.code <- c(cmd.slurm, cmd)
        
        # WRITE OUTPUT ---
        file.code <- file.path(dir.script, paste(val_outname, "sh", sep="."))
        write.table(cmd.code, file.code, row.names=FALSE, col.names=FALSE, quote=FALSE)

        cat(paste(Sys.time()), "FILE GENERATED:", file.code, "\n", sep=" ")

        list.main[[i]] <- paste("sbatch", file.code, sep=" ")
    }

    # AGGREGATE MAIN CMD ---
    file.main <- file.path(dir.script, "main.sh")
    write.table(unlist(list.main), file.main, row.names=FALSE, col.names=FALSE, quote=FALSE)

    cat(paste(Sys.time()), "FILE GENERATED:", file.main, "\n", sep=" ")
}


### FUNCTION: get.slurm() ---
get.slurm <- function(val_outname, hrs="12", min="00", sec="00", val_memory="700G", val_cpu=64, val_node=1){
    line1 <- "#!/bin/bash"
    line2 <- paste("#SBATCH --job-name=", val_outname, sep="")
    line3 <- paste("#SBATCH --time=", paste(hrs, min, sec, sep=":"), sep="")
    line4 <- paste("#SBATCH --mem=", val_memory, sep="")
    line5 <- paste("#SBATCH -c", val_cpu, sep=" ")
    line6 <- paste("#SBATCH -N", val_node, sep=" ")  
    line7 <- "#SBATCH --export=all"
    line8 <- paste("#SBATCH --output=", paste("job_", val_outname, ".out", sep=""), sep="")
    line9 <- paste("#SBATCH --error=", paste("job_", val_outname, ".err", sep=""), sep="")

    lines <- c(line1, line2, line3, line4, line5, line6, line7, line8, line9)    
    return(lines)
}

### FUNCTION: get.cmd() ---
get.cmd <- function(dir.batch, file.hnd, file.alt, file.out, file.nodes, file.infmatrix, file.seed.genes="NULL", val_gamma, val_alpha, val_beta, val_outname){
    # ./hitndrive -a [alterations file] -o [outlier file] -g [gene names file] -i [influence matrix] -f [output folder] -n [output filename] -l [alpha] -b [beta] -m [gamma] -x [seed gene filename]   

    file.log <- file.path(dir.batch, paste(val_outname, "log", sep="."))

    if(!file.exists(file.seed.genes)){
        cmd <- paste(file.hnd, 
                    "-a", file.alt, 
                    "-o", file.out, 
                    "-g", file.nodes, 
                    "-i", file.infmatrix, 
                    "-f", dir.batch, 
                    "-n", val_outname, 
                    "-l", val_alpha, 
                    "-b", val_beta, 
                    "-m", val_gamma,
                    "2>", file.log, 
                    sep=" ")
    } else{
        cmd <- paste(file.hnd, 
                    "-a", file.alt, 
                    "-o", file.out, 
                    "-g", file.nodes, 
                    "-i", file.infmatrix, 
                    "-f", dir.batch, 
                    "-n", val_outname, 
                    "-l", val_alpha, 
                    "-b", val_beta, 
                    "-m", val_gamma,
                    "-x", file.seed.genes,
                    "2>", file.log, 
                    sep=" ")        
    }

    return(cmd)
}

### FUNCTION: getPatientDrivers() ---
getPatientDrivers <- function(batch.name, output.name){
    cat(paste(Sys.time()), "PATIENT SPECIFIC DRIVER GENES: COMPUTING ...","\n", sep="\t")

    # GET DIRS ---
    dir.batch <- get.dirs(dir.wrk, batch.name)[[4]]

    # LOAD PARAMETER FILE ---
    file.par <- file.path(dir.batch, "hitndrive_params.tsv")
    par <- read.delim(file.par, header=TRUE, stringsAsFactors=FALSE)

    # CALL computePatientDrivers() ---
    list.df <- list.sol <- list()
    for(i in 1:nrow(par)){
        val_gamma <- par$gamma[i]
        val_alpha <- par$alpha[i]
        val_beta <- par$beta[i]
        val_outname <- par$outputName[i]

        file.bip <- file.path(dir.batch, paste(val_outname, "bip", sep="."))
        file.drivers <- file.path(dir.batch, paste(val_outname, "drivers", sep="."))

        list.sol[[i]] <- getSolDrivers(file.drivers, val_gamma, val_alpha, val_beta)
        list.df[[i]] <- computePatientDrivers(file.bip, file.drivers, val_gamma, val_alpha, val_beta)
    }        

    # AGGREGATE DATA ---
    df.sol <- do.call(rbind.data.frame, list.sol)
    df <- do.call(rbind.data.frame, list.df)

    # WRITE OUTPUT ---
    file.output1 <- file.path(dir.batch, paste(output.name, "solution_driver_genes.tsv", sep="_"))
    write.table(df.sol, file.output1, sep="\t", row.names=FALSE, col.names=TRUE, quote=FALSE)

    # WRITE OUTPUT ---
    file.output2 <- file.path(dir.batch, paste(output.name, "patient_specific_driver_genes.tsv", sep="_"))
    write.table(df, file.output2, sep="\t", row.names=FALSE, col.names=TRUE, quote=FALSE)

    cat(paste(Sys.time()), "PATIENT SPECIFIC DRIVER GENES: COMPLETE ...","\n", sep="\t")
    cat(paste(Sys.time()), "FILE GENERATED:", file.output1, "\n", sep=" ")
    cat(paste(Sys.time()), "FILE GENERATED:", file.output2, "\n", sep=" ")
}

### getSolDrivers() ---
getSolDrivers <- function(file.drivers, val_gamma, val_alpha, val_beta){
    # LOAD DRIVER GENES ---
    genes.drivers <- read.table(file.drivers, header=FALSE, stringsAsFactors=FALSE)$V1

    # PREPARE DATA ---
    d.sol <- data.frame(gamma=val_gamma, alpha=val_alpha, beta=val_beta, DriverGenes=paste(genes.drivers, collapse=":"))
    return(d.sol)
}

### computePatientDrivers() ---
computePatientDrivers <- function(file.bip, file.drivers, val_gamma, val_alpha, val_beta){
    # LOAD DRIVER GENES ---
    genes.drivers <- read.table(file.drivers, header=FALSE, stringsAsFactors=FALSE)$V1

    # LOAD BI-PARTITE GRAPH ---
    bip <- read.delim(file.bip, header=TRUE, stringsAsFactors=FALSE)

    # GET SAMPLEIDS ---
    ids <- sort(unique(bip$SampleID), decreasing=FALSE)

    # PREPARE DATA ---
    df <- data.frame(SampleID=ids, gamma=val_gamma, alpha=val_alpha, beta=val_beta)
    df$DriverGene <- NA
    
    # GET PATIENT SPECIFIC DRIVER GENES ---
    for(i in 1:length(ids)){
        bip.temp1 <- subset(bip, bip$SampleID == ids[i])
        bip.temp2 <- subset(bip.temp1, bip.temp1$AberrantGene %in% genes.drivers)
        genes.psol <- sort(unique(bip.temp2$AberrantGene), decreasing=FALSE)
        df$DriverGene[i] <- paste(genes.psol, collapse=":")
    }

    return(df)
}

### buildGraphR() ---
buildGraph <- function(dir.wrk, batch.name, network.name, file.network){
    cat(paste(Sys.time()), "BUILD GRAPH : START ...","\n", sep="\t")

    # GET DIRS ---
    dir.network <- get.dirs(dir.wrk, batch.name)[[1]]    
    dir.lib <- get.dirs(dir.wrk, batch.name)[[2]]

    # DEFINE FILES ---
    file.buildgraph <- file.path(dir.lib, "buildGraph")

    # GET COMMAND ---
    cmd <- paste(file.buildgraph, 
                "-i", file.network,
                "-f", dir.network, 
                "-o", network.name, 
                sep=" ")

    # EXECUTE ---
    system(cmd)

    cat(paste(Sys.time()), "BUILD GRAPH : END ...","\n", sep="\t")
}  

### getHTMatrixInversionR() ---
getHTMatrixInversionR <- function(dir.wrk, batch.name, network.name){
    cat(paste(Sys.time()), "HITTING TIME MATRIX INVERSION : START ...","\n", sep="\t")

    # GET DIRS ---
    dir.network <- get.dirs(dir.wrk, batch.name)[[1]]    
    dir.lib <- get.dirs(dir.wrk, batch.name)[[2]]
    dir.batch <- get.dirs(dir.wrk, batch.name)[[4]]

    # DEFINE FILES ---
    file.matinv <- file.path(dir.lib, "getHTMatrixInversion")
    file.infmatrix <- file.path(dir.network, network.name)
    file.graph <- file.path(dir.network, paste(network.name, "graph", sep="."))

    # GET COMMAND ---
    cmd <- paste(file.matinv, 
                "-i", file.graph, 
                "-o", dir.infmatrix, 
                sep=" ")

    # EXECUTE ---
    system(cmd)

    cat(paste(Sys.time()), "HITTING TIME MATRIX INVERSION : END ...","\n", sep="\t")
}
