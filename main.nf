#!/usr/bin/env nextflow

output="/home/jovyan/work/fibro/fibro/metaboRawFiles"
Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/metaboRawFiles/POS/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1 }//input_set is the output

	Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/Huntington_STEPHfiles/pos/MS2/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS2 }//input_set is the output
	
Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/metaboRawFiles/pospheno.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { phenoPosIn }//input_set is the output

	
output="/home/jovyan/work/fibro/fibro/outNoFilter"

	
process  XcmsFindPeaks{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/findPeaks", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/collected", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/group1", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/rtcor", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/group2", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/blankFilter", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/dilutionFilter", mode: 'copy'

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

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/cvfilter.r" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { extraCVfile }//input_set is the output

process  cvFilterP{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/cvFilter", mode: 'copy'

  input:
  file inrdata from cvFilter
  each file(cvfile) from extraCVfile
output:
file "cvFiltered.rdata" into CameraAnnotatePeaksIn

  shell:
    '''
	cp !{cvfile} /usr/local/bin/cvfilter.r
	chmod +x /usr/local/bin/cvfilter.r
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/cvfilter.r input=!{inrdata} output=cvFiltered.rdata qc=QC cvcut=0.3
    cp $HOME/cvFiltered.rdata $nextFlowDIR/cvFiltered.rdata
	'''
}
*/
process  CameraAnnotatePeaks{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraAnnotatePeaks", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraGroup", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraFindAdducts", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraFindIsotopes", mode: 'copy'

  input:
  file inrdata from CameraFindIsotopesIn

output:
file "CameraFindIsotopes.rdata" into MapMsms2CameraInCam,Msms2MetFragInCam, fixNameIn

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/ReadMsms", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/MapMsms2Camera", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/Msms2MetFrag", mode: 'copy'

  input:
  file inrdata from Msms2MetFragIn
  file incam from Msms2MetFragInCam

output:
file "*.txt" into CsifingeridIn, removeMS2DublicatedIn
file "res.zip" into removeMS2DublicatedInZip

  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	mkdir $HOME/out
	/usr/local/bin/MS2ToMetFrag.r inputCAMERA=!{incam} inputMS2=!{inrdata} output=$HOME/out precursorppm=15 fragmentppm=30 fragmentabs=0.07 database=LocalCSV mode=pos adductRules=primary minPeaks=2
    zip -r res.zip $HOME/out/
	cp $HOME/res.zip $nextFlowDIR/res.zip
	cd $nextFlowDIR
	unzip -j res.zip
	'''
}
//cp $HOME/out/* $nextFlowDIR/

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/removeDub.R" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { removeDubFile }//input_set is the output
	
//removeMS2DublicatedInF=removeMS2DublicatedIn.flatten()
	
//removeMS2DublicatedInF.into{removeMS2DublicatedInF2;removeMS2DublicatedInF1}

process  removeMS2Dublicated{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/removeMS2Dublicated", mode: 'copy'

  input:
  file inrdata from removeMS2DublicatedInZip
  each file(extraFile) from removeDubFile

output:
file "*.txt" into seachEngineParm

  script:
   
    """
	cp ${extraFile} /usr/local/bin/${extraFile}
	chmod +x /usr/local/bin/${extraFile}
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	unzip -j ${inrdata}
	/usr/local/bin/removeDub.R
	for i in *; do cp "\$i" \$nextFlowDIR/; done
    
	"""
}
//cp \$HOME/* \$nextFlowDIR/
// def input_args = inrdata.collect{ "$it" }.join(",")



Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/libraryFiles/POS/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS1Library }//input_set is the output

	Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/libraryFiles/POS/*.mzML" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { mzMLFilesMS2Library }//input_set is the output
	


	
output="/home/jovyan/work/fibro/fibro/out"

	
process  XcmsFindPeaksLibrary{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/xcms:dev_v1.52.0_cv0.8.70'
stageInMode 'copy'
publishDir "${output}/findPeaksLibrary", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraAnnotatePeaksLibrary", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraGroupLibrary", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraFindAdductsLibrary", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/CameraFindIsotopesLibrary", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/ReadMsmsLibrary", mode: 'copy'

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
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/MapMsms2CameraLibrary", mode: 'copy'

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

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/createLibraryFun.r" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { extralibFun }//input_set is the output
Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/createLibrary.R" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { extralibMain }//input_set is the output

	
Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/libPos.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { libraryInfo }//input_set is the output
	
	
	
	
process  createLibraryP{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/createLibraryP", mode: 'copy'

  input:
set val(name), file(incam), file(inrdata) from CreateLibInputsLibrary
each file(functionR) from extralibFun
each file(mainR) from extralibMain
each file(libraryin) from libraryInfo

output:
file "${incam.baseName}.csv" into collectLibraryIn

  shell:
    '''
	cp !{functionR} /usr/local/bin/!{functionR}
	chmod +x /usr/local/bin/!{functionR}
	
	cp !{mainR} /usr/local/bin/createLibrary.r
	chmod +x /usr/local/bin/createLibrary.r
	
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	mkdir $HOME/out
	/usr/local/bin/createLibrary.r inputCAMERA=!{incam} inputMS2=!{inrdata} output=$HOME/!{incam.baseName}.csv precursorppm=15 fragmentppm=30 fragmentabs=0.07 database=LocalCSV mode=pos adductRules=primary maxSpectra=100000 minPeaks=2 inputLibrary=!{libraryin}  rawFileName=rawFile   compundID=HMDB.YMDB.ID   compoundName=PRIMARY_NAME  mzCol=mz whichmz=f

	cp $HOME/!{incam.baseName}.csv $nextFlowDIR/!{incam.baseName}.csv
	'''
}

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/collectLibrary.R" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { collectFile }//input_set is the output

process  collectLibrary{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/collectLibrary", mode: 'copy'

  input:
file inrdata from collectLibraryIn.collect()
each file(extraFile) from collectFile

output:
file "library.csv" into searchEngineLib

  script:
  def input_args = inrdata.collect{ "$it" }.join(",")
  
    """
	cp ${extraFile} /usr/local/bin/${extraFile}
	chmod +x /usr/local/bin/${extraFile}
	
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	/usr/local/bin/collectLibrary.R inputs=$input_args realNames=$input_args output=library.csv
    cp \$HOME/library.csv \$nextFlowDIR/library.csv
	"""
}



Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/librarySearchEngine.r" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { searchEngineFile }//input_set is the output
	
seachEngineParmF=seachEngineParm.flatten()	
process  librarySearchEngine{
maxForks 100
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/librarySearchEngine", mode: 'copy'

  input:
  file param from seachEngineParmF
  each file(extraFile) from searchEngineFile
  each file(libraryFile) from searchEngineLib

output:
file "${param.baseName}.csv" into AggregateMetFragIn

  script:
    """
	cp ${extraFile} /usr/local/bin/${extraFile}
	chmod +x /usr/local/bin/${extraFile}
	nextFlowDIR=\$PWD
	cd \$HOME
	mv \$nextFlowDIR/* \$HOME/
	librarySearchEngine.r inputLibrary=${libraryFile} inputMS2=${param} outputCSV=${param.baseName}.csv tolprecursorPPMTol=15 tolfragmentabsTol=0.07 fragmentPPMTol=30 precursorRTTol=20 searchRange=T outputSemiDecoy=T topHits=-1 ionMode=pos topScore=Scoredotproduct resample=1000
	
    cp \$HOME/${param.baseName}.csv \$nextFlowDIR/${param.baseName}.csv
	"""
}


process  AggregateMetFragLib{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
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
Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/fixname.r" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { extraRfile }//input_set is the output
	
	
process  fixname{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/fixname", mode: 'copy'

  input:
  file camInput from fixNameIn
   each file(rfile) from extraRfile
output:
file "${camInput}" into PrepareOutPutInCam
  shell:
    '''
	cp !{rfile} /usr/local/bin/fixname.r
	chmod +x /usr/local/bin/fixname.r
	
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/fixname.r input=!{camInput} output=!{camInput}
    cp $HOME/* $nextFlowDIR/
	'''
}

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/posphenoFixed.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { phenoPosIn2 }//input_set is the output

	
process  PrepareOutPut{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/test", mode: 'copy'

  input:
  file phenoIn from phenoPosIn2
  file camInput from PrepareOutPutInCam
  file sIn from prepareOutPutSIn
output:
file "*.txt" into plsdaIn
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	
	R -e 'x<-read.csv("!{sIn}",header=T);write.table(x,"ids.csv",quote=F,sep="\\t")'
	/usr/local/bin/prepareOutput.r inputcamera=!{camInput} inputscores=ids.csv inputpheno=!{phenoIn} ppm=15 rt=20 higherTheBetter=true scoreColumn=Scoredotproduct impute=false typeColumn=Class selectedType=Sample rename=true renameCol=rename onlyReportWithID=false combineReplicate=true combineReplicateColumn=rep log=true sampleCoverage=50 sampleCoverageMethod=Groups outputPeakTable=peaktable.txt outputVariables=vars.txt outputMetaData=metadata.txt
    cp $HOME/* $nextFlowDIR/
	'''
}


process  plsda{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/multivariate:v2.3.10_cv1.2.20'
stageInMode 'copy'
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
    multivariate_wrapper.R dataMatrix_in peaktable.txt sampleMetadata_in metadata.txt variableMetadata_in vars.txt respC Groups predI 2 orthoI 0 testL FALSE opgC default opcC default sampleMetadata_out mv_meta.tsv variableMetadata_out mv_vars.tsv figure mv_fig.pdf info mv_info.txt
    cp $HOME/* $nextFlowDIR/
	'''
}
	
//zip -r Csifingerid.zip $nextFlowDIR/
//zip Csifingerid.zip *csv
//find . -type f -empty -delete
//cp $nextFlowDIR/* $HOME/

/*
CsifingeridInF=CsifingeridIn.flatten()

process  Csifingerid{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/csifingerid:dev_v4.0_cv4.0.2'
stageInMode 'copy'
publishDir "${output}/Csifingerid", mode: 'copy'
maxForks = 100

  input:
  file inrdata from CsifingeridInF

   output:
  file "${inrdata.baseName}.csv" into AggregateMetFragIn

  script:
    """
	nextFlowDIR=\$PWD
	cd \$HOME
	cp \$nextFlowDIR/* \$HOME/
	touch \$HOME/${inrdata.baseName}.csv
	/usr/local/bin/fingerID.r input=\$HOME/${inrdata} database=hmdb tryOffline=T output=\$HOME/${inrdata.baseName}.csv
    cp \$HOME/${inrdata.baseName}.csv \$nextFlowDIR/${inrdata.baseName}.csv
	"""
}

process  AggregateMetFrag{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/msnbase:v2.2_cv0.7.54'
stageInMode 'copy'
publishDir "${output}/AggregateMetFrag", mode: 'copy'
maxForks = 100

  input:
  file inrdata from AggregateMetFragIn.collect()

output:
file "AggregateMetFrag.csv" into prepareOutPutSIn
 
  shell:
    '''
	nextFlowDIR=$PWD
	zip --quiet -r ids.zip .
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	find . -type f -empty -delete
	
	zip Csifingerid.zip *csv
	/usr/local/bin/aggregateMetfrag.r inputs=Csifingerid.zip realNames=Csifingerid.zip output=AggregateMetFrag.csv filetype=zip
    cp $HOME/AggregateMetFrag.csv $nextFlowDIR/AggregateMetFrag.csv
	'''
}

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/fixname.r" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { extraRfile }//input_set is the output
	
	
process  fixname{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/fixname", mode: 'copy'

  input:
  file camInput from prepareOutPutSIn
   each file(rfile) from extraRfile
output:
file "${camInput}" into PrepareOutPutInCam
  shell:
    '''
	cp !{rfile} /usr/local/bin/fixname.r
	chmod +x /usr/local/bin/fixname.r
	
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/fixname.r input=!{camInput} output=!{camInput}
    cp $HOME/* $nextFlowDIR/
	'''
}

Channel
    .fromPath( "/home/jovyan/work/fibro/fibro/posphenoFixed.csv" )
    .ifEmpty { error "Cannot find any files in the folder" }
    .set { phenoPosIn2 }//input_set is the output

	
process  PrepareOutPut{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/camera:v1.33.3_cv0.10.59'
stageInMode 'copy'
publishDir "${output}/test", mode: 'copy'

  input:
  file phenoIn from phenoPosIn2
  file camInput from PrepareOutPutInCam
  file sIn from prepareOutPutSIn
output:
file "*.txt" into plsdaIn
  shell:
    '''
	nextFlowDIR=$PWD
	cd $HOME
	cp $nextFlowDIR/* $HOME/
	/usr/local/bin/prepareOutput.r inputcamera=!{camInput} inputscores=!{sIn} inputpheno=!{phenoIn} ppm=15 rt=20 higherTheBetter=true scoreColumn=Scoredotproduct impute=false typeColumn=Class selectedType=Sample rename=true renameCol=rename onlyReportWithID=false combineReplicate=true combineReplicateColumn=rep log=true sampleCoverage=50 sampleCoverageMethod=Groups outputPeakTable=peaktable.txt outputVariables=vars.txt outputMetaData=metadata.txt
    cp $HOME/* $nextFlowDIR/
	'''
}


process  plsda{
maxForks 15
container 'container-registry.phenomenal-h2020.eu/phnmnl/multivariate:v2.3.10_cv1.2.20'
stageInMode 'copy'
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
    multivariate_wrapper.R dataMatrix_in peaktable.txt sampleMetadata_in metadata.txt variableMetadata_in vars.txt respC Groups predI 2 orthoI 0 testL FALSE opgC default opcC default sampleMetadata_out mv_meta.tsv variableMetadata_out mv_vars.tsv figure mv_fig.pdf info mv_info.txt
    cp $HOME/* $nextFlowDIR/
	'''
}
	
*/
//find *.csv -size  0 -print0 |xargs -0 rm --
