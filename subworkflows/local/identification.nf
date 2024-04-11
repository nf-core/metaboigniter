
include { OPENMS_FILEFILTER } from '../../modules/local/openms_filefilter.nf'
include {PYOPENMS_MSMAPPING } from '../../modules/local/pyopenms_msmapping.nf'
include {PYOPENMS_GENERATESEARCHPARAMS } from '../../modules/local/pyopenms_generatesearchparams.nf'
include {PYOPENMS_GENERATESEARCHPARAMSUNMAPPED } from '../../modules/local/pyopenms_generatesearchparamsunmapped.nf'
include { PYOPENMS_SPLITCONSENSUS } from '../../modules/local/pyopenms_splitconsensus.nf'
include { PYOPENMS_CONCTSV as PYOPENMS_CONCTSV_UNMAPPED } from '../../modules/local/pyopenms_conctsv.nf'
include { GENERAL_MERGEFILE as GENERAL_MERGEMSFILE } from '../../modules/local/general_mergefile.nf'
include { GENERAL_MERGEFILE as GENERAL_MERGEMGFFILE } from '../../modules/local/general_mergefile.nf'

include { MS2QUERY as MS2QUERYMAPPED } from '../../subworkflows/local/ms2query.nf'
include { MS2QUERY as MS2QUERYUNMAPPED} from '../../subworkflows/local/ms2query.nf'

include { SIRIUS as SIRIUSMAPPED } from '../../subworkflows/local/sirius.nf'
include { SIRIUS as SIRIUSUNMAPPED } from '../../subworkflows/local/sirius.nf'


workflow IDENTIFICATION {

    take:
    consensusxml_data
    mzml_files
    quantification_information
    offline_model_ms2query
    models_dir_ms2query
    train_library_ms2query
    library_path_ms2query
    polarity
    split_consensus_parts
    run_umapped_spectra
    mgf_splitmgf_pyopenms
    sirius_split
    run_ms2query
    run_sirius




    main:

ch_versions = Channel.empty()



 // Map the MS2 to consensus
consensusxml_data.combine(mzml_files.filter{meta,file->meta.level == "MS2" | meta.level == "MS12"}.collect{it[1]}
.map { files ->
    files.sort { a, b ->
        a.baseName <=> b.baseName
    }
}.toList()) | PYOPENMS_MSMAPPING

ch_versions       = ch_versions.mix(PYOPENMS_MSMAPPING.out.versions.first())


// Filter out the unmapped features
PYOPENMS_MSMAPPING.out.consensusxml | OPENMS_FILEFILTER

ch_versions       = ch_versions.mix(OPENMS_FILEFILTER.out.versions.first())

filtered_consensus = OPENMS_FILEFILTER.out.consensusxml

// split the consensusXML files
if(split_consensus_parts>1)
{
OPENMS_FILEFILTER.out.consensusxml | PYOPENMS_SPLITCONSENSUS

ch_versions       = ch_versions.mix(PYOPENMS_SPLITCONSENSUS.out.versions.first())

filtered_consensus = PYOPENMS_SPLITCONSENSUS.out.consensusxml.map{it[1]}.flatten().map{ file ->
    def matcher = file.baseName =~ /_part(\d+)/
    def partNumber = matcher ? matcher[0][1] : ''  // Extracts the numeric part after "_part"
    [[id: file.baseName, part: partNumber], file]
}

}


// Generate MS and MGF files, also CSV files for unmapped spectra
PYOPENMS_GENERATESEARCHPARAMS(
filtered_consensus,

mzml_files.filter{ meta, file -> meta.level == "MS2" || meta.level == "MS12" }.map{tuple ->
    [tuple]}.collect().map { tuples ->
        tuples.sort { a, b ->
            a[1].baseName <=> b[1].baseName
        }
    }
    .map { sortedTuples ->
        def metas = sortedTuples.collect { it[0] }
        def files = sortedTuples.collect { it[1] }
        return [metas, files]
    }
)

ch_versions       = ch_versions.mix(PYOPENMS_GENERATESEARCHPARAMS.out.versions.first())

csv_unmmaped_channel = PYOPENMS_GENERATESEARCHPARAMS.out.csv.map{it[1]}.flatten().map{file -> [[id:file.baseName],file]}
ms_mmaped_channel = PYOPENMS_GENERATESEARCHPARAMS.out.ms.map{it[1]}.flatten().map{file -> [[id:file.baseName],file]}
mgf_mmaped_channel = PYOPENMS_GENERATESEARCHPARAMS.out.mgf.map{it[1]}.flatten().map{file -> [[id:file.baseName],file]}

// merge files, if they have been split
if(split_consensus_parts>1)
{

generated_params = OPENMS_FILEFILTER.out.consensusxml.map{it[0]}.combine(
 PYOPENMS_GENERATESEARCHPARAMS.out.csv.collect{it[1]}
.map { files ->
    files.sort { a, b ->
    def n1 = (a.baseName =~ /\d+/)[-1] as Integer
    def n2 = (b.baseName =~ /\d+/)[-1] as Integer

    def s1 = a.baseName.replaceAll(/\d+$/, '').trim()
    def s2 = b.baseName.replaceAll(/\d+$/, '').trim()

    if (s1 == s2){
        return n1 <=> n2
    }
    else{
        return s1 <=> s2
    }
    }
}.toList()).map{it[1]}.flatten().
map{file ->
def matcher = file.baseName =~ /(.*)_part\d+/
def filename = matcher ? matcher[0][1] : null
[[id:filename],file]}.groupTuple(by: 0)

PYOPENMS_CONCTSV_UNMAPPED(generated_params,"csv","csv")

ch_versions       = ch_versions.mix(PYOPENMS_CONCTSV_UNMAPPED.out.versions.first())
csv_unmmaped_channel = PYOPENMS_CONCTSV_UNMAPPED.out.csv


// merge ms

OPENMS_FILEFILTER.out.consensusxml.map{it[0]}.combine(
PYOPENMS_GENERATESEARCHPARAMS.out.ms.collect{it[1]}
.map { files ->
    files.sort { a, b ->
    def n1 = (a.baseName =~ /\d+/)[-1] as Integer
    def n2 = (b.baseName =~ /\d+/)[-1] as Integer

    def s1 = a.baseName.replaceAll(/\d+$/, '').trim()
    def s2 = b.baseName.replaceAll(/\d+$/, '').trim()

    if (s1 == s2){
        return n1 <=> n2
    }
    else{
        return s1 <=> s2
    }
    }
}.toList()).map{it[1]}.flatten().
map{file ->
def matcher = file.baseName =~ /(.*)_part\d+/
def filename = matcher ? matcher[0][1] : null
[[id:filename],file]}.groupTuple(by: 0) | GENERAL_MERGEMSFILE

ch_versions       = ch_versions.mix(GENERAL_MERGEMSFILE.out.versions.first())

ms_mmaped_channel = GENERAL_MERGEMSFILE.out.mergedfile


OPENMS_FILEFILTER.out.consensusxml.map{it[0]}.combine(
PYOPENMS_GENERATESEARCHPARAMS.out.mgf.collect{it[1]}
.map { files ->
    files.sort { a, b ->
    def n1 = (a.baseName =~ /\d+/)[-1] as Integer
    def n2 = (b.baseName =~ /\d+/)[-1] as Integer

    def s1 = a.baseName.replaceAll(/\d+$/, '').trim()
    def s2 = b.baseName.replaceAll(/\d+$/, '').trim()

    if (s1 == s2){
        return n1 <=> n2
    }
    else{
        return s1 <=> s2
    }
    }
}.toList()).map{it[1]}.flatten().
map{file ->
def matcher = file.baseName =~ /(.*)_part\d+/
def filename = matcher ? matcher[0][1] : null
[[id:filename],file]}.groupTuple(by: 0) | GENERAL_MERGEMGFFILE

ch_versions       = ch_versions.mix(GENERAL_MERGEMGFFILE.out.versions.first())

mgf_mmaped_channel = GENERAL_MERGEMGFFILE.out.mergedfile


}

// run unmapped data extraction
if(run_umapped_spectra)
{
mzml_files.filter{ meta, file -> meta.level == "MS2" || meta.level == "MS12" }
.map{meta,file->[[id:file.baseName],meta,file]}.join(
    csv_unmmaped_channel, by:0
).map{it[1,2,3]} | PYOPENMS_GENERATESEARCHPARAMSUNMAPPED

ch_versions       = ch_versions.mix(PYOPENMS_GENERATESEARCHPARAMSUNMAPPED.out.versions.first())

ms_unmmaped_channel = PYOPENMS_GENERATESEARCHPARAMSUNMAPPED.out.ms
mgf_unmmaped_channel = PYOPENMS_GENERATESEARCHPARAMSUNMAPPED.out.mgf

}

output_sirius = Channel.empty()
output_fingerid = Channel.empty()
if(run_sirius)
{
SIRIUSMAPPED(ms_mmaped_channel,mgf_splitmgf_pyopenms,sirius_split)
output_sirius = SIRIUSMAPPED.out.output_sirius
output_fingerid = SIRIUSMAPPED.out.output_fingerid
ch_versions = ch_versions.mix(SIRIUSMAPPED.out.versions)
if (run_umapped_spectra)
{
SIRIUSUNMAPPED(ms_unmmaped_channel,mgf_splitmgf_pyopenms,sirius_split)
ch_versions = ch_versions.mix(SIRIUSUNMAPPED.out.versions)
}

}

ms2query = Channel.empty()
if(run_ms2query)
{
MS2QUERYMAPPED(mgf_mmaped_channel,offline_model_ms2query,models_dir_ms2query,train_library_ms2query,library_path_ms2query,polarity,mgf_splitmgf_pyopenms)
ms2query = MS2QUERYMAPPED.out.ms2query
ch_versions = ch_versions.mix(MS2QUERYMAPPED.out.versions)
if (run_umapped_spectra)
{
MS2QUERYUNMAPPED(mgf_unmmaped_channel,offline_model_ms2query,models_dir_ms2query,train_library_ms2query,library_path_ms2query,polarity,mgf_splitmgf_pyopenms)
ch_versions = ch_versions.mix(MS2QUERYUNMAPPED.out.versions)
}
}


    emit:
    sirius         = output_sirius
    fingerid       = output_fingerid
    ms2query = ms2query
    versions       = ch_versions
}
