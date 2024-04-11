
include { OPENMS_FEATURELINKERUNLABELEDKD } from '../../modules/local/openms_featurelinkerunlabeledkd.nf'
include { OPENMS_FEATURELINKERUNLABELEDKD as OPENMS_FEATURELINKERUNLABELEDKDPARTS } from '../../modules/local/openms_featurelinkerunlabeledkd.nf'

include { PYOPENMS_EXTRACTFEATUREMZ } from '../../modules/local/pyopenms_extractfeaturemz.nf'
include { PYOPENMS_CONCTSV as PYOPENMS_CONCTSV_MZ } from '../../modules/local/pyopenms_conctsv.nf'
include { PYOPENMS_CALCULATEBOUNDRIES } from '../../modules/local/pyopenms_calculateboundries.nf'
include { PYOPENMS_SPLITFEATUREXML } from '../../modules/local/pyopenms_splitfeaturexml.nf'
include { PYOPENMS_FILEMERGER } from '../../modules/local/pyopenms_filemerger.nf'



workflow LINKER {
    take:
        quantification_information
        parallel_linking

    main:
        ch_versions = Channel.empty()


if(parallel_linking)
{

     quantification_information.map{it[0,1]} | PYOPENMS_EXTRACTFEATUREMZ
    ch_versions       = ch_versions.mix(PYOPENMS_EXTRACTFEATUREMZ.out.versions.first())




PYOPENMS_CONCTSV_MZ(Channel.of([id:"merged_mz_range"]).combine(PYOPENMS_EXTRACTFEATUREMZ.out.tsv.collect{it[1]}.toList()),"tsv","tsv")
ch_versions       = ch_versions.mix(PYOPENMS_CONCTSV_MZ.out.versions.first())
PYOPENMS_CONCTSV_MZ.out.csv | PYOPENMS_CALCULATEBOUNDRIES
ch_versions       = ch_versions.mix(PYOPENMS_CALCULATEBOUNDRIES.out.versions.first())



PYOPENMS_SPLITFEATUREXML(quantification_information.map{it[0,1]},
    PYOPENMS_CALCULATEBOUNDRIES.out.tsv.map{it[1]}
)
ch_versions       = ch_versions.mix(PYOPENMS_SPLITFEATUREXML.out.versions.first())



PYOPENMS_SPLITFEATUREXML.out.featurexml.collect{it[1]}.flatten().map{file ->
def n1 = (file.baseName =~ /\d+/)[-1] as Integer
[[id:"part"+n1],file]}.groupTuple(by: 0).map{meta,files->[[meta][0], files.sort { a, b ->
        a.baseName <=> b.baseName
    }]} | OPENMS_FEATURELINKERUNLABELEDKDPARTS

ch_versions       = ch_versions.mix(OPENMS_FEATURELINKERUNLABELEDKDPARTS.out.versions.first())



to_be_merged = Channel.of([id:"Linked_data"]).combine(
OPENMS_FEATURELINKERUNLABELEDKDPARTS.out.consensusxml.map{it[1]}.collect()
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

consensusxml=   PYOPENMS_FILEMERGER.out.consensusxml.map{meta,consensusxml->[[id:consensusxml.baseName],consensusxml]}

}else{

  Channel.of([id:"Linked_data"]).combine(quantification_information.collect{it[1]}.map { files ->
    files.sort { a, b ->
        a.baseName <=> b.baseName
    }
}.toList()) | OPENMS_FEATURELINKERUNLABELEDKD


        consensusxml=OPENMS_FEATURELINKERUNLABELEDKD.out.consensusxml.map{meta,consensusxml->[[id:consensusxml.baseName],consensusxml]}
        ch_versions       = ch_versions.mix(OPENMS_FEATURELINKERUNLABELEDKD.out.versions.first())

}







    emit:
        consensusxml_data = consensusxml
        versions       = ch_versions

}
