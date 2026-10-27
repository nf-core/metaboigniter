
include { OPENMS_FEATURELINKERUNLABELEDKD } from '../../../modules/local/openms_featurelinkerunlabeledkd/main'
include { OPENMS_FEATURELINKERUNLABELEDKD as OPENMS_FEATURELINKERUNLABELEDKDPARTS } from '../../../modules/local/openms_featurelinkerunlabeledkd/main'

include { PYOPENMS_EXTRACTFEATUREMZ } from '../../../modules/local/pyopenms_extractfeaturemz/main'
include { PYOPENMS_CONCTSV as PYOPENMS_CONCTSV_MZ } from '../../../modules/local/pyopenms_conctsv/main'
include { PYOPENMS_CALCULATEBOUNDRIES } from '../../../modules/local/pyopenms_calculateboundries/main'
include { PYOPENMS_SPLITFEATUREXML } from '../../../modules/local/pyopenms_splitfeaturexml/main'
include { PYOPENMS_FILEMERGER } from '../../../modules/local/pyopenms_filemerger/main'



workflow LINKER {
    take:
        quantification_information
        parallel_linking

    main:
        ch_versions = channel.empty()


if(parallel_linking)
{

    quantification_information.map{ entry -> entry[0,1]} | PYOPENMS_EXTRACTFEATUREMZ
    ch_versions       = ch_versions.mix(PYOPENMS_EXTRACTFEATUREMZ.out.versions.first())




PYOPENMS_CONCTSV_MZ(channel.of([id:"merged_mz_range"]).combine(PYOPENMS_EXTRACTFEATUREMZ.out.tsv.collect{ entry -> entry[1]}.toList()),"tsv","tsv")
ch_versions       = ch_versions.mix(PYOPENMS_CONCTSV_MZ.out.versions.first())
PYOPENMS_CONCTSV_MZ.out.csv | PYOPENMS_CALCULATEBOUNDRIES
ch_versions       = ch_versions.mix(PYOPENMS_CALCULATEBOUNDRIES.out.versions.first())



PYOPENMS_SPLITFEATUREXML(quantification_information.map{ entry -> entry[0,1]},
    PYOPENMS_CALCULATEBOUNDRIES.out.tsv.map{ entry -> entry[1]}
)
ch_versions       = ch_versions.mix(PYOPENMS_SPLITFEATUREXML.out.versions.first())



PYOPENMS_SPLITFEATUREXML.out.featurexml.collect{ entry -> entry[1]}.flatten().map{file ->
def n1 = (file.baseName =~ /\d+/)[-1] as Integer
[[id:"part"+n1],file]}.groupTuple(by: 0).map{meta,files->[[meta][0], files.sort { a, b ->
        a.baseName <=> b.baseName
    }]} | OPENMS_FEATURELINKERUNLABELEDKDPARTS

ch_versions       = ch_versions.mix(OPENMS_FEATURELINKERUNLABELEDKDPARTS.out.versions.first())



to_be_merged = channel.of([id:"Linked_data"]).combine(
OPENMS_FEATURELINKERUNLABELEDKDPARTS.out.consensusxml.map{ entry -> entry[1]}.collect()
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
}.toList())

PYOPENMS_FILEMERGER(to_be_merged)
ch_versions       = ch_versions.mix(PYOPENMS_FILEMERGER.out.versions.first())

consensusxml=   PYOPENMS_FILEMERGER.out.consensusxml.map{_meta,consensus_file->[[id:consensus_file.baseName],consensus_file]}

}else{

channel.of([id:"Linked_data"]).combine(quantification_information.collect{ entry -> entry[1]}.map { files ->
    files.sort { a, b ->
        a.baseName <=> b.baseName
    }
}.toList()) | OPENMS_FEATURELINKERUNLABELEDKD


        consensusxml=OPENMS_FEATURELINKERUNLABELEDKD.out.consensusxml.map{_meta,consensus_file->[[id:consensus_file.baseName],consensus_file]}
        ch_versions       = ch_versions.mix(OPENMS_FEATURELINKERUNLABELEDKD.out.versions.first())

}







    emit:
        consensusxml_data = consensusxml
        versions       = ch_versions

}
