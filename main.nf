#!/usr/bin/env nextflow


Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/metaboRawFiles/POS/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1 }//input_set is the output

	Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/Huntington_STEPHfiles/pos/MS2/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS2 }//input_set is the output
	
Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/pospheno.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .into { phenoPosIn;phenoPosIn2 }//input_set is the output


Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/libraryFiles/POS/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1Library }//input_set is the output

	Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/libraryFiles/POS/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS2Library }//input_set is the output
	
	
Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/libPos.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { libraryInfo }//input_set is the output
		

Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/metaboRawFiles/NEG/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1NEG }//input_set is the output

	Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/Huntington_STEPHfiles/neg/MS2/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS2NEG }//input_set is the output
	
Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/negpheno.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .into { phenoPosInNEG;phenoPosIn2NEG }//input_set is the output


Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/libraryFiles/NEG/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1LibraryNEG }//input_set is the output

	Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/libraryFiles/NEG/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS2LibraryNEG }//input_set is the output
	
	
Channel
    .fromPath( "/home/jovyan/work/fibro/MS2data/libNeg.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { libraryInfoNEG }//input_set is the output
		


output="/home/jovyan/work/fibro/MS2data/outNoFilter"

	
process  XcmsFindPeaks{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/findPeaks", mode: 'copy'

  input:
  file mzMLFile from mzMLFilesMS1
  each file(pheno) from phenoPosIn
output:
file "${mzMLFile.baseName}.rdata" into collectFiles, test5
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=10 peakwidthLow=4 peakwidthHigh=30 noise=1000 polarity=positive realFileName=!{mzMLFile} phenoFile=!{pheno} phenoDataColumn=Class sampleClass=sample asd=asd
    cp $HOME/* $nextFlowDIR/
	'''
}


process  collectXCMS{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.80'
////stageInMode 'copy'
//publishDir "${output}/collected", mode: 'copy'

  input:
  file mzMLFile from collectFiles.collect()

output:
file "collection.rdata" into groupPeaksN1

script:
  def input_args = mzMLFile.collect{ "$it" }.join(",")
//  shell:
   """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/xcmsCollect.r input=$input_args output=collection.rdata
    cp \$HOME/collection.rdata \$nextFlowDIR/collection.rdata
	"""
}

process  groupPeaks_1{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/group1", mode: 'copy'

  input:
  file inrdata from groupPeaksN1

output:
file "group1.rdata" into rtCorrectIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/group.r input=!{inrdata} output=group1.rdata bandwidth=15 mzwid=0.005
    cp $HOME/group1.rdata $nextFlowDIR/group1.rdata
	'''
}


process  retcorP{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/rtcor", mode: 'copy'

  input:
  file inrdata from rtCorrectIn

output:
file "corrected.rdata" into groupPeaksN2

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/retCor.r input=!{inrdata} output=corrected.rdata method=loess
    cp $HOME/corrected.rdata $nextFlowDIR/corrected.rdata
	'''
}

process  groupPeaks_2{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/group2", mode: 'copy'

  input:
  file inrdata from groupPeaksN2

output:
file "group2.rdata" into CameraAnnotatePeaksIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/group.r input=!{inrdata} output=group2.rdata bandwidth=15 mzwid=0.005
    cp $HOME/group2.rdata $nextFlowDIR/group2.rdata
	'''
}
/*
process  blankFilterP{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/blankFilter", mode: 'copy'

  input:
  file inrdata from blankFilter

output:
file "blankFiltered.rdata" into dilutionFilter

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/blankfilter.r input=!{inrdata} output=blankFiltered.rdata method=max blank=Blank sample=Sample rest=T
    cp $HOME/blankFiltered.rdata $nextFlowDIR/blankFiltered.rdata
	'''
}

process  dilutionFilterP{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/dilutionFilter", mode: 'copy'

  input:
  file inrdata from dilutionFilter

output:
file "dilutionFiltered.rdata" into cvFilter

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/dilutionfilter.r input=!{inrdata} output=dilutionFiltered.rdata Corto=1,2,3,4,5,6,7 dilution=D1,D2,D3,D4,D5,D6,D7 pvalue=0.1 corcut=0.6 abs=F
    cp $HOME/dilutionFiltered.rdata $nextFlowDIR/dilutionFiltered.rdata
	'''
}

process  cvFilterP{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/cvFilter", mode: 'copy'

  input:
  file inrdata from cvFilter
output:
file "cvFiltered.rdata" into CameraAnnotatePeaksIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/cvfilter.r input=!{inrdata} output=cvFiltered.rdata qc=QC cvcut=0.3
    cp $HOME/cvFiltered.rdata $nextFlowDIR/cvFiltered.rdata
	'''
}
*/
process  CameraAnnotatePeaks{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraAnnotatePeaks", mode: 'copy'

  input:
  file inrdata from CameraAnnotatePeaksIn

output:
file "CameraAnnotatePeaks.rdata" into CameraGroupIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/xsAnnotate.r input=!{inrdata} output=CameraAnnotatePeaks.rdata
    cp $HOME/CameraAnnotatePeaks.rdata $nextFlowDIR/CameraAnnotatePeaks.rdata
	'''
}

process  CameraGroup{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraGroup", mode: 'copy'

  input:
  file inrdata from CameraGroupIn

output:
file "CameraGroup.rdata" into CameraFindAdductsIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/groupFWHM.r input=!{inrdata} output=CameraGroup.rdata sigma=8 perfwhm=0.6 intval=maxo
    cp $HOME/CameraGroup.rdata $nextFlowDIR/CameraGroup.rdata
	'''
}

process  CameraFindAdducts{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindAdducts", mode: 'copy'

  input:
  file inrdata from CameraFindAdductsIn

output:
file "CameraFindAdducts.rdata" into CameraFindIsotopesIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findAdducts.r input=!{inrdata} output=CameraFindAdducts.rdata ppm=10 polarity=positive
    cp $HOME/CameraFindAdducts.rdata $nextFlowDIR/CameraFindAdducts.rdata
	'''
}

process  CameraFindIsotopes{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindIsotopes", mode: 'copy'

  input:
  file inrdata from CameraFindIsotopesIn

output:
file "CameraFindIsotopes.rdata" into MapMsms2CameraInCam,Msms2MetFragInCam, PrepareOutPutInCam

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findIsotopes.r input=!{inrdata} output=CameraFindIsotopes.rdata maxcharge=3
    cp $HOME/CameraFindIsotopes.rdata $nextFlowDIR/CameraFindIsotopes.rdata
	'''
}

process  ReadMsms{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/ReadMsms", mode: 'copy'

  input:
  file inrdata from mzMLFilesMS2

output:
file "${inrdata.baseName}.rdata" into MapMsms2CameraIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/readMS2MSnBase.r input=!{inrdata} output=!{inrdata.baseName}.rdata inputname=!{inrdata.baseName}
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  MapMsms2Camera{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/MapMsms2Camera", mode: 'copy'

  input:
  file inrdata from MapMsms2CameraIn.collect()
  file incam from MapMsms2CameraInCam

output:
file "MapMsms2Camera.rdata" into Msms2MetFragIn

  script:
    def input_args = inrdata.collect{ "$it" }.join(",")
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/mapMS2ToCamera.r inputCAMERA=${incam} inputMS2=${input_args} output=MapMsms2Camera.rdata ppm=15 RT=20
    cp \$HOME/MapMsms2Camera.rdata \$nextFlowDIR/MapMsms2Camera.rdata
	"""
}

process  Msms2MetFrag{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/Msms2MetFrag", mode: 'copy'

  input:
  file inrdata from Msms2MetFragIn
  file incam from Msms2MetFragInCam

output:
file "*.txt" into CsifingeridIn, seachEngineParm
file "res.zip" into removeMS2DublicatedInZip

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	mkdir $HOME/out
	/usr/local/bin/MS2ToMetFrag.r inputCAMERA=!{incam} inputMS2=!{inrdata} output=$HOME/out precursorppm=15 fragmentppm=30 fragmentabs=0.07 database=LocalCSV mode=pos adductRules=primary minPeaks=2 removeDup=T
    zip -r res.zip $HOME/out/
	cp $HOME/res.zip $nextFlowDIR/res.zip
	cd $nextFlowDIR
	unzip -j res.zip
	'''
}


	
process  XcmsFindPeaksLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/findPeaksLibrary", mode: 'copy'

  input:
  file mzMLFile from mzMLFilesMS1Library
output:
file "${mzMLFile.baseName}.rdata" into CameraAnnotatePeaksInLibrary
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	/usr/local/bin/findPeaks.r input=!{mzMLFile}  output=!{mzMLFile.baseName}.rdata ppm=15 peakwidthLow=4 peakwidthHigh=50 noise=1000 polarity=positive realFileName=!{mzMLFile} sampleClass=sample asd=asd asd2=asd
    cp $HOME/* $nextFlowDIR/
	'''
}


process  CameraAnnotatePeaksLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraAnnotatePeaksLibrary", mode: 'copy'

  input:
  file inrdata from CameraAnnotatePeaksInLibrary

output:
file "${inrdata.baseName}.rdata" into CameraGroupInLibrary

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/xsAnnotate.r input=!{inrdata} output=!{inrdata.baseName}.rdata
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  CameraGroupLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraGroupLibrary", mode: 'copy'

  input:
  file inrdata from CameraGroupInLibrary

output:
file "${inrdata.baseName}.rdata" into CameraFindAdductsInLibrary

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/groupFWHM.r input=!{inrdata} output=!{inrdata.baseName}.rdata sigma=8 perfwhm=0.6 intval=maxo
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  CameraFindAdductsLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindAdductsLibrary", mode: 'copy'

  input:
  file inrdata from CameraFindAdductsInLibrary

output:
file "${inrdata.baseName}.rdata" into CameraFindIsotopesInLibrary

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findAdducts.r input=!{inrdata} output=!{inrdata.baseName}.rdata ppm=10 polarity=positive
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  CameraFindIsotopesLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindIsotopesLibrary", mode: 'copy'

  input:
  file inrdata from CameraFindIsotopesInLibrary

output:
file "${inrdata.baseName}.rdata" into MapMsms2CameraInCamLibrary,createLibCamLibrary

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findIsotopes.r input=!{inrdata} output=!{inrdata.baseName}.rdata maxcharge=3
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  ReadMsmsLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/ReadMsmsLibrary", mode: 'copy'

  input:
  file inrdata from mzMLFilesMS2Library

output:
file "${inrdata.baseName}_ReadMsmsLibrary.rdata" into MapMsms2CameraInLibrary

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/readMS2MSnBase.r input=!{inrdata} output=!{inrdata.baseName}.rdata inputname=!{inrdata.baseName}
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}_ReadMsmsLibrary.rdata
	'''
}

MapMsms2CameraInCamLibrary.map { file -> tuple(file.baseName, file) }.set { ch1CalLibrary }
MapMsms2CameraInLibrary.map { file -> tuple(file.baseName.replaceAll(/_ReadMsmsLibrary/,""), file) }.set { ch2CalLibrary }

MapMsms2CameraInputsLibrary=ch1CalLibrary.join(ch2CalLibrary,by:0)

process  MapMsms2CameraLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/MapMsms2CameraLibrary", mode: 'copy'

  input:
set val(name), file(incam), file(inrdata) from MapMsms2CameraInputsLibrary

output:
file "${incam.baseName}_MapMsms2CameraLibrary.rdata" into createInLibrary

  script:
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/mapMS2ToCamera.r inputCAMERA=${incam} inputMS2=${inrdata} output=${incam.baseName}.rdata ppm=15 RT=20
    cp \$HOME/${incam.baseName}.rdata \$nextFlowDIR/${incam.baseName}_MapMsms2CameraLibrary.rdata
	"""
}



createLibCamLibrary.map { file -> tuple(file.baseName, file) }.set { ch1CreateLibrary }
createInLibrary.map { file -> tuple(file.baseName.replaceAll(/_MapMsms2CameraLibrary/,""), file) }.set { ch2CreateLibrary }

CreateLibInputsLibrary=ch1CreateLibrary.join(ch2CreateLibrary,by:0)


	
	
process  createLibraryP{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/createLibraryP", mode: 'copy'

  input:
set val(name), file(incam), file(inrdata) from CreateLibInputsLibrary
each file(libraryin) from libraryInfo

output:
file "${incam.baseName}.csv" into collectLibraryIn

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	mkdir $HOME/out
	/usr/local/bin/createLibrary.r inputCAMERA=!{incam} inputMS2=!{inrdata} output=$HOME/!{incam.baseName}.csv precursorppm=15 fragmentppm=30 fragmentabs=0.07 database=LocalCSV mode=pos adductRules=primary maxSpectra=100000 minPeaks=2 inputLibrary=!{libraryin}  rawFileName=rawFile   compundID=HMDB.YMDB.ID   compoundName=PRIMARY_NAME  mzCol=mz whichmz=f

	cp $HOME/!{incam.baseName}.csv $nextFlowDIR/!{incam.baseName}.csv
	'''
}

process  collectLibrary{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/collectLibrary", mode: 'copy'

  input:
file inrdata from collectLibraryIn.collect()

output:
file "library.csv" into searchEngineLib

  script:
  def input_args = inrdata.collect{ "$it" }.join(",")
  
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/collectLibrary.r inputs=$input_args realNames=$input_args output=library.csv
    cp \$HOME/library.csv \$nextFlowDIR/library.csv
	"""
}

	
seachEngineParmF=seachEngineParm.flatten()	
process  librarySearchEngine{
maxForks 60
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//publishDir "${output}/librarySearchEngine", mode: 'copy'

  input:
  file param from seachEngineParmF
  each file(libraryFile) from searchEngineLib

output:
file "${param.baseName}.csv" into AggregateMetFragIn

  script:
    """

	nextFlowDIR=\$PWD
	cd \$HOME
	mv \$nextFlowDIR/* \$HOME/
	/usr/local/bin/librarySearchEngine.r inputLibrary=${libraryFile} inputMS2=${param} outputCSV=${param.baseName}.csv tolprecursorPPMTol=15 tolfragmentabsTol=0.07 fragmentPPMTol=30 precursorRTTol=20 searchRange=T outputSemiDecoy=T topHits=-1 ionMode=pos topScore=Scoredotproduct resample=1000
	
    cp \$HOME/${param.baseName}.csv \$nextFlowDIR/${param.baseName}.csv
	"""
}


process  AggregateMetFragLib{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
publishDir "${output}/AggregateMetFrag", mode: 'copy'
maxForks = 100

  input:
  file inrdata from AggregateMetFragIn.collect()

output:
file "AggregateMetFrag.csv" into prepareOutPutSIn
 
  shell:
    '''
	nextFlowDIR=$PWD
	zip --quiet -R ids.zip '*.csv'
	cp ids.zip $HOME/ids.zip
	cd $HOME
	/usr/local/bin/aggregateMetfrag.r inputs=ids.zip realNames=ids.zip output=AggregateMetFrag.csv filetype=zip
    cp $HOME/AggregateMetFrag.csv $nextFlowDIR/AggregateMetFrag.csv
	'''
}



    
process  PrepareOutPut{
cpus 8
memory { 15.GB * task.attempt }
    time { 1.hour * task.attempt }

    errorStrategy { task.exitStatus == 137 ? 'retry' : 'terminate' }
    maxRetries 3
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'

publishDir "${output}/test", mode: 'copy'

  input:
  file phenoIn from phenoPosIn2
  file camInput from PrepareOutPutInCam
  file sIn from prepareOutPutSIn
 
output:
file "*.txt" into batcheffect
  shell:
'''
	
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	/usr/local/bin/prepareOutput.r inputcamera=!{camInput} inputscores=!{sIn} inputpheno=!{phenoIn} ppm=15 rt=20 higherTheBetter=true scoreColumn=Scoredotproduct impute=false typeColumn=Class selectedType=Sample rename=true renameCol=rename onlyReportWithID=false combineReplicate=true combineReplicateColumn=rep log=true sampleCoverage=50 sampleCoverageMethod=Groups outputPeakTable=peaktablePOS.txt outputVariables=varsPOS.txt outputMetaData=metadataPOS.txt ncore=7 Ifnormalize=1
	
    cp $HOME/* $nextFlowDIR/
	'''
}

process  removebatcheffect{

container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'

publishDir "${output}/batcheffect", mode: 'copy'

  input:
file phenoIn from batcheffect.collect()
 
output:
file "*.txt" into plsdaIn, combineDataPOS
  shell:

	'''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	/usr/local/bin/correctBatchEffect.r -in peaktablePOS.txt -s metadataPOS.txt -b1 Gender -c "Age,BMI" -out peaktablePOS.txt
	
    cp $HOME/* $nextFlowDIR/
	'''
}


process  plsda{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/multivariate:v2.3.10_cv1.2.20'
//stageInMode 'copy'
publishDir "${output}/plsda", mode: 'copy'

  input:
  file phenoIn from plsdaIn.collect()
output:
file "*.*" into finish
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
    multivariate_wrapper.R dataMatrix_in peaktablePOS.txt sampleMetadata_in metadataPOS.txt variableMetadata_in varsPOS.txt respC Groups predI 2 orthoI 0 testL FALSE opgC default opcC default sampleMetadata_out mv_meta.tsv variableMetadata_out mv_vars.tsv figure mv_fig.pdf info mv_info.txt
    cp $HOME/* $nextFlowDIR/
	'''
}

	
process  XcmsFindPeaksNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/findPeaksNEG", mode: 'copy'

  input:
  file mzMLFile from mzMLFilesMS1NEG
  each file(pheno) from phenoPosInNEG
output:
file "${mzMLFile.baseName}.rdata" into collectFilesNEG, test5NEG
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findPeaks.r input=!{mzMLFile} output=!{mzMLFile.baseName}.rdata ppm=10 peakwidthLow=4 peakwidthHigh=30 noise=1000 polarity=negative realFileName=!{mzMLFile} phenoFile=!{pheno} phenoDataColumn=Class sampleClass=sample asd=asd
    cp $HOME/* $nextFlowDIR/
	'''
}


process  collectXCMSNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.80'
////stageInMode 'copy'
//publishDir "${output}/collectedNEG", mode: 'copy'

  input:
  file mzMLFile from collectFilesNEG.collect()

output:
file "collection.rdata" into groupPeaksN1NEG

script:
  def input_args = mzMLFile.collect{ "$it" }.join(",")
//  shell:
   """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/xcmsCollect.r input=$input_args output=collection.rdata
    cp \$HOME/collection.rdata \$nextFlowDIR/collection.rdata
	"""
}

process  groupPeaks_1NEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/group1NEG", mode: 'copy'

  input:
  file inrdata from groupPeaksN1NEG

output:
file "group1.rdata" into rtCorrectInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/group.r input=!{inrdata} output=group1.rdata bandwidth=15 mzwid=0.005
    cp $HOME/group1.rdata $nextFlowDIR/group1.rdata
	'''
}


process  retcorPNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/rtcor", mode: 'copy'

  input:
  file inrdata from rtCorrectInNEG

output:
file "corrected.rdata" into groupPeaksN2NEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/retCor.r input=!{inrdata} output=corrected.rdata method=loess
    cp $HOME/corrected.rdata $nextFlowDIR/corrected.rdata
	'''
}

process  groupPeaks_2NEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
////stageInMode 'copy'
//publishDir "${output}/group2NEG", mode: 'copy'

  input:
  file inrdata from groupPeaksN2NEG

output:
file "group2.rdata" into CameraAnnotatePeaksInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/group.r input=!{inrdata} output=group2.rdata bandwidth=15 mzwid=0.005
    cp $HOME/group2.rdata $nextFlowDIR/group2.rdata
	'''
}
/*
process  blankFilterPNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/blankFilterNEG", mode: 'copy'

  input:
  file inrdata from blankFilterNEG

output:
file "blankFiltered.rdata" into dilutionFilterNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/blankfilter.r input=!{inrdata} output=blankFiltered.rdata method=max blank=Blank sample=Sample rest=T
    cp $HOME/blankFiltered.rdata $nextFlowDIR/blankFiltered.rdata
	'''
}

process  dilutionFilterPNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/dilutionFilterNEG", mode: 'copy'

  input:
  file inrdata from dilutionFilterNEG

output:
file "dilutionFiltered.rdata" into cvFilterNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/dilutionfilter.r input=!{inrdata} output=dilutionFiltered.rdata Corto=1,2,3,4,5,6,7 dilution=D1,D2,D3,D4,D5,D6,D7 pvalue=0.1 corcut=0.6 abs=F
    cp $HOME/dilutionFiltered.rdata $nextFlowDIR/dilutionFiltered.rdata
	'''
}

process  cvFilterPNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/cvFilter", mode: 'copy'

  input:
  file inrdata from cvFilterNEG
output:
file "cvFiltered.rdata" into CameraAnnotatePeaksInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/cvfilter.r input=!{inrdata} output=cvFiltered.rdata qc=QC cvcut=0.3
    cp $HOME/cvFiltered.rdata $nextFlowDIR/cvFiltered.rdata
	'''
}
*/
process  CameraAnnotatePeaksNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraAnnotatePeaksNEG", mode: 'copy'

  input:
  file inrdata from CameraAnnotatePeaksInNEG

output:
file "CameraAnnotatePeaks.rdata" into CameraGroupInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/xsAnnotate.r input=!{inrdata} output=CameraAnnotatePeaks.rdata
    cp $HOME/CameraAnnotatePeaks.rdata $nextFlowDIR/CameraAnnotatePeaks.rdata
	'''
}

process  CameraGroupNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraGroupNEG", mode: 'copy'

  input:
  file inrdata from CameraGroupInNEG

output:
file "CameraGroup.rdata" into CameraFindAdductsInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/groupFWHM.r input=!{inrdata} output=CameraGroup.rdata sigma=8 perfwhm=0.6 intval=maxo
    cp $HOME/CameraGroup.rdata $nextFlowDIR/CameraGroup.rdata
	'''
}

process  CameraFindAdductsNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindAdducts", mode: 'copy'

  input:
  file inrdata from CameraFindAdductsInNEG

output:
file "CameraFindAdducts.rdata" into CameraFindIsotopesInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findAdducts.r input=!{inrdata} output=CameraFindAdducts.rdata ppm=10 polarity=negative
    cp $HOME/CameraFindAdducts.rdata $nextFlowDIR/CameraFindAdducts.rdata
	'''
}

process  CameraFindIsotopesNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindIsotopesNEG", mode: 'copy'

  input:
  file inrdata from CameraFindIsotopesInNEG

output:
file "CameraFindIsotopes.rdata" into MapMsms2CameraInCamNEG,Msms2MetFragInCamNEG, PrepareOutPutInCamNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findIsotopes.r input=!{inrdata} output=CameraFindIsotopes.rdata maxcharge=3
    cp $HOME/CameraFindIsotopes.rdata $nextFlowDIR/CameraFindIsotopes.rdata
	'''
}

process  ReadMsmsNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/ReadMsmsNEG", mode: 'copy'

  input:
  file inrdata from mzMLFilesMS2NEG

output:
file "${inrdata.baseName}.rdata" into MapMsms2CameraInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/readMS2MSnBase.r input=!{inrdata} output=!{inrdata.baseName}.rdata inputname=!{inrdata.baseName}
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  MapMsms2CameraNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/MapMsms2CameraNEG", mode: 'copy'

  input:
  file inrdata from MapMsms2CameraInNEG.collect()
  file incam from MapMsms2CameraInCamNEG

output:
file "MapMsms2Camera.rdata" into Msms2MetFragInNEG

  script:
    def input_args = inrdata.collect{ "$it" }.join(",")
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/mapMS2ToCamera.r inputCAMERA=${incam} inputMS2=${input_args} output=MapMsms2Camera.rdata ppm=15 RT=20
    cp \$HOME/MapMsms2Camera.rdata \$nextFlowDIR/MapMsms2Camera.rdata
	"""
}

process  Msms2MetFragNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/Msms2MetFragNEG", mode: 'copy'

  input:
  file inrdata from Msms2MetFragInNEG
  file incam from Msms2MetFragInCamNEG

output:
file "*.txt" into CsifingeridInNEG, seachEngineParmNEG
file "res.zip" into removeMS2DublicatedInZipNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	mkdir $HOME/out
	/usr/local/bin/MS2ToMetFrag.r inputCAMERA=!{incam} inputMS2=!{inrdata} output=$HOME/out precursorppm=15 fragmentppm=30 fragmentabs=0.07 database=LocalCSV mode=neg adductRules=primary minPeaks=2 removeDup=T
    zip -r res.zip $HOME/out/
	cp $HOME/res.zip $nextFlowDIR/res.zip
	cd $nextFlowDIR
	unzip -j res.zip
	'''
}


	
process  XcmsFindPeaksLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.53.1_cv0.1.84'
//stageInMode 'copy'
//publishDir "${output}/findPeaksLibraryNEG", mode: 'copy'

  input:
  file mzMLFile from mzMLFilesMS1LibraryNEG
output:
file "${mzMLFile.baseName}.rdata" into CameraAnnotatePeaksInLibraryNEG
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	/usr/local/bin/findPeaks.r input=!{mzMLFile}  output=!{mzMLFile.baseName}.rdata ppm=15 peakwidthLow=4 peakwidthHigh=50 noise=1000 polarity=negative realFileName=!{mzMLFile} sampleClass=sample asd=asd asd2=asd
    cp $HOME/* $nextFlowDIR/
	'''
}


process  CameraAnnotatePeaksLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraAnnotatePeaksLibraryNEG", mode: 'copy'

  input:
  file inrdata from CameraAnnotatePeaksInLibraryNEG

output:
file "${inrdata.baseName}.rdata" into CameraGroupInLibraryNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/xsAnnotate.r input=!{inrdata} output=!{inrdata.baseName}.rdata
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  CameraGroupLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraGroupLibraryNEG", mode: 'copy'

  input:
  file inrdata from CameraGroupInLibraryNEG

output:
file "${inrdata.baseName}.rdata" into CameraFindAdductsInLibraryNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/groupFWHM.r input=!{inrdata} output=!{inrdata.baseName}.rdata sigma=8 perfwhm=0.6 intval=maxo
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  CameraFindAdductsLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindAdductsLibraryNEG", mode: 'copy'

  input:
  file inrdata from CameraFindAdductsInLibraryNEG

output:
file "${inrdata.baseName}.rdata" into CameraFindIsotopesInLibraryNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findAdducts.r input=!{inrdata} output=!{inrdata.baseName}.rdata ppm=10 polarity=negative
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  CameraFindIsotopesLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'
//stageInMode 'copy'
//publishDir "${output}/CameraFindIsotopesLibraryNEG", mode: 'copy'

  input:
  file inrdata from CameraFindIsotopesInLibraryNEG

output:
file "${inrdata.baseName}.rdata" into MapMsms2CameraInCamLibraryNEG,createLibCamLibraryNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/findIsotopes.r input=!{inrdata} output=!{inrdata.baseName}.rdata maxcharge=3
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}.rdata
	'''
}

process  ReadMsmsLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/ReadMsmsLibraryNEG", mode: 'copy'

  input:
  file inrdata from mzMLFilesMS2LibraryNEG

output:
file "${inrdata.baseName}_ReadMsmsLibrary.rdata" into MapMsms2CameraInLibraryNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/readMS2MSnBase.r input=!{inrdata} output=!{inrdata.baseName}.rdata inputname=!{inrdata.baseName}
    cp $HOME/!{inrdata.baseName}.rdata $nextFlowDIR/!{inrdata.baseName}_ReadMsmsLibrary.rdata
	'''
}

MapMsms2CameraInCamLibraryNEG.map { file -> tuple(file.baseName, file) }.set { ch1CalLibraryNEG }
MapMsms2CameraInLibraryNEG.map { file -> tuple(file.baseName.replaceAll(/_ReadMsmsLibrary/,""), file) }.set { ch2CalLibraryNEG }

MapMsms2CameraInputsLibraryNEG=ch1CalLibraryNEG.join(ch2CalLibraryNEG,by:0)

process  MapMsms2CameraLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/MapMsms2CameraLibraryNEG", mode: 'copy'

  input:
set val(name), file(incam), file(inrdata) from MapMsms2CameraInputsLibraryNEG

output:
file "${incam.baseName}_MapMsms2CameraLibrary.rdata" into createInLibraryNEG

  script:
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/mapMS2ToCamera.r inputCAMERA=${incam} inputMS2=${inrdata} output=${incam.baseName}.rdata ppm=15 RT=20
    cp \$HOME/${incam.baseName}.rdata \$nextFlowDIR/${incam.baseName}_MapMsms2CameraLibrary.rdata
	"""
}



createLibCamLibraryNEG.map { file -> tuple(file.baseName, file) }.set { ch1CreateLibraryNEG }
createInLibraryNEG.map { file -> tuple(file.baseName.replaceAll(/_MapMsms2CameraLibrary/,""), file) }.set { ch2CreateLibraryNEG }

CreateLibInputsLibraryNEG=ch1CreateLibraryNEG.join(ch2CreateLibraryNEG,by:0)


	
	
process  createLibraryPNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/createLibraryPNEG", mode: 'copy'

  input:
set val(name), file(incam), file(inrdata) from CreateLibInputsLibraryNEG
each file(libraryin) from libraryInfoNEG

output:
file "${incam.baseName}.csv" into collectLibraryInNEG

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	mkdir $HOME/out
	/usr/local/bin/createLibrary.r inputCAMERA=!{incam} inputMS2=!{inrdata} output=$HOME/!{incam.baseName}.csv precursorppm=15 fragmentppm=30 fragmentabs=0.07 database=LocalCSV mode=neg adductRules=primary maxSpectra=100000 minPeaks=2 inputLibrary=!{libraryin}  rawFileName=rawFile   compundID=HMDB.YMDB.ID   compoundName=PRIMARY_NAME  mzCol=mz whichmz=f

	cp $HOME/!{incam.baseName}.csv $nextFlowDIR/!{incam.baseName}.csv
	'''
}

process  collectLibraryNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
//publishDir "${output}/collectLibraryNEG", mode: 'copy'

  input:
file inrdata from collectLibraryInNEG.collect()

output:
file "library.csv" into searchEngineLibNEG

  script:
  def input_args = inrdata.collect{ "$it" }.join(",")
  
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/collectLibrary.r inputs=$input_args realNames=$input_args output=library.csv
    cp \$HOME/library.csv \$nextFlowDIR/library.csv
	"""
}

	
seachEngineParmFNEG=seachEngineParmNEG.flatten()	
process  librarySearchEngineNEG{
maxForks 60
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//publishDir "${output}/librarySearchEngineNEG", mode: 'copy'

  input:
  file param from seachEngineParmFNEG
  each file(libraryFile) from searchEngineLibNEG

output:
file "${param.baseName}.csv" into AggregateMetFragInNEG

  script:
    """

	nextFlowDIR=\$PWD
	cd \$HOME
	mv \$nextFlowDIR/* \$HOME/
	/usr/local/bin/librarySearchEngine.r inputLibrary=${libraryFile} inputMS2=${param} outputCSV=${param.baseName}.csv tolprecursorPPMTol=15 tolfragmentabsTol=0.07 fragmentPPMTol=30 precursorRTTol=20 searchRange=T outputSemiDecoy=T topHits=-1 ionMode=neg topScore=Scoredotproduct resample=1000
	
    cp \$HOME/${param.baseName}.csv \$nextFlowDIR/${param.baseName}.csv
	"""
}


process  AggregateMetFragLibNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:dev_v2.2_cv1.0.65'
//stageInMode 'copy'
publishDir "${output}/AggregateMetFragNEG", mode: 'copy'
maxForks = 100

  input:
  file inrdata from AggregateMetFragInNEG.collect()

output:
file "AggregateMetFrag.csv" into prepareOutPutSInNEG
 
  shell:
    '''
	nextFlowDIR=$PWD
	zip --quiet -R ids.zip '*.csv'
	cp ids.zip $HOME/ids.zip
	cd $HOME
	/usr/local/bin/aggregateMetfrag.r inputs=ids.zip realNames=ids.zip output=AggregateMetFrag.csv filetype=zip
    cp $HOME/AggregateMetFrag.csv $nextFlowDIR/AggregateMetFrag.csv
	'''
}



    
process  PrepareOutPutNEG{
cpus 8
memory { 15.GB * task.attempt }
    time { 1.hour * task.attempt }

    errorStrategy { task.exitStatus == 137 ? 'retry' : 'terminate' }
    maxRetries 3
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'

publishDir "${output}/testNEG", mode: 'copy'

  input:
  file phenoIn from phenoPosIn2NEG
  file camInput from PrepareOutPutInCamNEG
  file sIn from prepareOutPutSInNEG
 
output:
file "*.txt" into batcheffectNEG
  shell:
'''
	
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	/usr/local/bin/prepareOutput.r inputcamera=!{camInput} inputscores=!{sIn} inputpheno=!{phenoIn} ppm=15 rt=20 higherTheBetter=true scoreColumn=Scoredotproduct impute=false typeColumn=Class selectedType=Sample rename=true renameCol=rename onlyReportWithID=false combineReplicate=true combineReplicateColumn=rep log=true sampleCoverage=50 sampleCoverageMethod=Groups outputPeakTable=peaktableNEG.txt outputVariables=varsNEG.txt outputMetaData=metadataNEG.txt ncore=7 Ifnormalize=1
	
    cp $HOME/* $nextFlowDIR/
	'''
}

process  removebatcheffectNEG{

container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:dev_v1.33.3_cv0.10.65'

publishDir "${output}/batcheffectNEG", mode: 'copy'

  input:
file phenoIn from batcheffectNEG.collect()
 
output:
file "*.txt" into plsdaInNEG, combineDataNEG
  shell:

	'''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	/usr/local/bin/correctBatchEffect.r -in peaktableNEG.txt -s metadataNEG.txt -b1 Gender -c "Age,BMI" -out peaktableNEG.txt
	
    cp $HOME/* $nextFlowDIR/
	'''
}


process  plsdaNEG{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/multivariate:v2.3.10_cv1.2.20'
//stageInMode 'copy'
publishDir "${output}/plsdaNEG", mode: 'copy'

  input:
  file phenoIn from plsdaInNEG.collect()
output:
file "*.*" into finishNEG
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
    multivariate_wrapper.R dataMatrix_in peaktable.txt sampleMetadata_in metadata.txt variableMetadata_in vars.txt respC Groups predI 2 orthoI 0 testL FALSE opgC default opcC default sampleMetadata_out mv_meta.tsv variableMetadata_out mv_vars.tsv figure mv_fig.pdf info mv_info.txt
    cp $HOME/* $nextFlowDIR/
	'''
}


process  combineData{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/multivariate:v2.3.10_cv1.2.20'
//stageInMode 'copy'
publishDir "${output}/combineData", mode: 'copy'

  input:
  file phenoInPOS from combineDataPOS.collect()
  file phenoInNEG from combineDataNEG.collect()
output:
file "*.*" into plsdaCombIN
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
    /usr/local/bin/mergeVaribales.r -in peaktablePOS.txt,peaktableNEG.txt -p varPOS.txt,varNEG.txt -s metadataPOS.txt -out peaktable.txt -outp var.txt
	mv metadataPOS.txt metadata.txt 
    cp $HOME/* $nextFlowDIR/
	'''
}

process  plsdaCombined{
maxForks 5
container 'container-registry.phenomenal-h2020.eu/phnmnl/multivariate:v2.3.10_cv1.2.20'
//stageInMode 'copy'
publishDir "${output}/plsdaCombined", mode: 'copy'

  input:
  file phenoIn from plsdaCombIN.collect()
output:
file "*.*" into finishAll
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
    multivariate_wrapper.R dataMatrix_in peaktable.txt sampleMetadata_in metadata.txt variableMetadata_in vars.txt respC Groups predI 2 orthoI 0 testL FALSE opgC default opcC default sampleMetadata_out mv_meta.tsv variableMetadata_out mv_vars.tsv figure mv_fig.pdf info mv_info.txt
    cp $HOME/* $nextFlowDIR/
	'''
}

