#!/usr/bin/env nextflow

//Parameters
params.outdir = "output"
params.counts = ""
//params.counts = "/home/clarkb/scratch/ss3_2/zUMIs/merged/zUMIs_output/allelic/*.csv"
//params.counts = "/home/clarkb/scratch/burst/ss3_2/zUMIs/sdparekh/zUMIs_output/allelic/*.txt"
//params.bam = "/home/clarkb/scratch/burst/ss3_2/stitcher-out/stitched_transcripts.bam"
//params.yaml = "/home/clarkb/scratch/burst/ss3_2/scripts/zUMIs_master_sam.run.yaml"


process stitch {
	cpus = 10
	memory = 24.GB
	time = "1 hour"
	input:
		path ss3_bam
		path gtf
		path isoform_json
		
	output:
		path "stitched_transcripts.bam"
	"""
	stitcher.py -i $ss3_bam -o "stitched_transcripts.bam" -g $gtf --isoform $isoform_json -t 10 
	"""
}

process getDir {
	input:
		path yaml
	output:
		stdout
	"""
	#!/usr/bin/env python
	import yaml
	with open("$yaml") as file:
		input = yaml.safe_load(file)
	print(input["out_dir"] + "/zUMIs_output/allelic/*.txt")
	"""

}

process tab2CSV {
	input:
		path tab
	output:
		path "${tab.baseName}.csv"
	"""
	cat $tab | tr -s "\\t" "," > "${tab.baseName}.csv" 
	""" 
}

process alleleLevelExpression {
	cpus = 5
        memory = 24.GB
	input:
		path yaml
		val outdir
	output:
		path "${outdir}*.txt"

	""" 
	module load r/4.1.2;
	get_variant_overlap_CAST.R --yaml $yaml --vcf $baseDir/CAST.SNPs.validated.vcf.gz     
	"""
}

process txburstML {
	publishDir "$params.outdir/ML"
	input:
		path csv 
	output:
		path "*ML.pkl"

	"""
	txburstML.py --njobs 20  $csv
	"""
}

process txburstPL {
	publishDir "$params.outdir/PL"
	input:
		path csv
		path ML
	output:
		path "*PL.pkl"
	"""
	txburstPL.py --njobs 20 --file $csv --MLFile $ML 
	"""
}

workflow {
	
	counts_in = Channel.fromPath(params.counts)
	
	tab2CSV(counts_in)
		
	csv = tab2CSV.out
	
	txburstML(csv)

	txburstPL(csv, txburstML.out)

} 
