#!/bin/bash
PARAMETERFILE=""
PARAMETERFILES=""
ADDITIONALPARAMETERS=""
LOCALDATABASEPATH=""
RESULTSPATH=""
RESULTSFILE=""
ADDITIONALSCORES=""
ZIPFILE=""
RENAMERESULTS="false"
outputFile=""
while [[ $# -gt 1 ]]
do
    key="$1"
    case $key in
            -p|--parameterfile)
            PARAMETERFILE="$2"
            shift # past argument
        ;;
	    -pp|--parameterfiles)
            PARAMETERFILES="$2"
            shift # past argument
        ;;
            -a|--additionalparameters)
            ADDITIONALPARAMETERS="$2"
            shift # past argument
        ;;
            -l|--localdatabasepath)
            LOCALDATABASEPATH="$2"
            shift # past argument
        ;;
            -r|--resultspath)
            RESULTSPATH="$2"
            shift # past argument
	;;
            -f|--resultsfile)
            RESULTSFILE="$2"
            shift # past argument
	;;
	    -z|--zipfile)
	    ZIPFILE="$2"
	    shift
        ;;
	    -o|--output)
	    outputFile="$2"
	    shift
        ;;
	    -rn|--rename)
            RENAMERESULTS="$2"
            shift
        ;;
	    -s|--additionalscores)
            ADDITIONALSCORES="$2"
            shift # past argument
	;;
            *)
            # unknown option
        ;;
    esac
    shift # past argument or value
done
if [ "$PARAMETERFILE" == "" ] && [ "$PARAMETERFILES" == "" ]; then
    echo "Error: ParameterFile or ParameterFiles needs to be defined. Use -p (ParameterFile) or -pp (ParameterFiles) option."
    exit 1
fi
if [ "$PARAMETERFILE" != "" ] && [ "$PARAMETERFILES" != "" ]; then
    echo "Error: ParameterFile and ParameterFiles are defined. Which one shall I use?"
    exit 1
fi
# check result folder/file
if [ "$RESULTSPATH" == "" ] && [ "$RESULTSFILE" == "" ]; then
    echo "Error: ResultsPath or ResultsFile needs to be defined. Use -r (ResultsPath) or -f (ResultsFile) option."
    exit 1
fi
# define array of filenames
declare -a files
if [ "$PARAMETERFILE" != "" ]; then
    IFS=',' read -r -a files <<< $PARAMETERFILE
else
    IFS=',' read -r -a files <<< $PARAMETERFILES
fi
# loop over file names to create commands arguments for gnu parallel
if [ "$RESULTSFILE" != "" ]; then
    cmdfile=${RESULTSFILE}.cmd
else
    cmdfile=${RESULTSPATH}/commands.cmd
fi
cmdprefix="/usr/bin/metfrag -Xmx2048m -Xms1024m "
for file in "${files[@]}"; do
    while read line; do
	cmd="$cmdprefix $(echo "\'${line}" | tr -d "\"" | sed "s/PeakListString=\(.*\)\s/PeakListString=\"\1\" /" | sed "s/SampleName=.*\/\(.*\)\(\s\|$\)/SampleName=\1 /" | sed "s/SampleName=.*\\\\\/\(.*\)\(\s\|$\)/SampleName=\1 /")"
	if [ "$ADDITIONALSCORES" != "" ]; then
            # MetFragScoreTypes=FragmenterScore MetFragScoreWeights=1.0
            if [ "$(echo $ADDITIONALSCORES | grep -c 'StatisticalScore')" == 1 ]; then
               ADDITIONALSCORES=$(echo $ADDITIONALSCORES | sed "s/StatisticalScore/AutomatedPeakFingerprintAnnotationScore,AutomatedLossFingerprintAnnotationScore/")
            fi
            cmd=$(echo $(echo $cmd | sed "s/MetFragScoreTypes=[A-Za-z0-9]\+/MetFragScoreTypes=FragmenterScore,$ADDITIONALSCORES/")" MetFragScoreWeights=1.0,"$(echo $ADDITIONALSCORES | sed "s/[A-Za-z0-9]\+/1.0/g"))
        fi
        if [ "$ADDITIONALPARAMETERS" != "" ]; then
            cmd="$cmd $ADDITIONALPARAMETERS"
        fi
        if [ "$LOCALDATABASEPATH" != "" ]; then
            cmd="$cmd LocalDatabasePath=$LOCALDATABASEPATH"
        fi
        if [ "$RESULTSFILE" != "" ]; then
            cmd="$cmd ResultsFile=$RESULTSFILE"
        else
            cmd="$cmd ResultsPath=$RESULTSPATH"
        fi
        cmd="$cmd NumberThreads=1\'"
        echo $cmd >> $cmdfile
    done < $file
done
echo "wrote commands into $cmdfile"
# define join function
function join { local IFS="$1"; shift; echo "$*"; }
# define header flag
headerFlag="0"
# run the command
# cat $cmdfile | parallel --load 80% --noswap
cat $cmdfile | parallel
rm $cmdfile
if [ "$RESULTSPATH" != "" ] && [ "$RENAMERESULTS" == "true" ]; then
    for i in $(ls $RESULTSPATH); do
	# check number of lines
	numberOfLines=$(wc -l < $RESULTSPATH/$i)
        echo $numberOfLines
	if [ ${numberOfLines} -eq "1" ]; then continue ; fi
        if [ ${numberOfLines} -eq "0" ]; then continue ; fi
        # extract mz, RT and fileName
        IFS='_' read -r -a filesInfo <<< "$i"
        parentRT=${filesInfo[1]}
        parentMZ=${filesInfo[2]}
        fileName=$(join _ ${filesInfo[@]:4})
        # add file name
        echo parentRT,parentMZ,fileName,$(head -n1 $RESULTSPATH/$i) > "$RESULTSPATH/$i.tmp"
        tail -n +2 $RESULTSPATH/$i | sed "s/^/${parentRT},${parentMZ},${fileName},/" >> "$RESULTSPATH/$i.tmp"
        mv "$RESULTSPATH/$i.tmp" "$RESULTSPATH/$i"
        # check if the header has been written.
        if [ "$headerFlag" != "0" ]; then
           sed -i '1d' $RESULTSPATH/$i
        fi
        # save results
        cat "$RESULTSPATH/$i" >> $outputFile
        headerFlag="1"
    done
fi
if [ "$ZIPFILE" != "" ]; then
    zip -j -r $ZIPFILE $RESULTSPATH
fi
