#!/usr/bin/env nextflow

Channel
    .fromPath( "/home/ubuntu/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1 }//input_set is the output

output="/home/ubuntu/out"

process  XcmsFindPeaks{
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/findPeaks", mode: 'copy'

  input:
  file mzMLFile from mzMLFilesMS1
 
output:
file "${mzMLFile.baseName}.rdata" into collectFiles, test5
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=10 peakwidthLow=4 peakwidthHigh=30 noise=1000 polarity=positive realFileName=!{mzMLFile} sampleClass=sample asd=asd
    cp $HOME/* $nextFlowDIR/
	'''
}
