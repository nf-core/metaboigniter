
include {SIRIUS_SEARCH } from '../../modules/local/sirius_search.nf'
include { PYOPENMS_SPLITMGF as PYOPENMS_SPLITMS } from '../../modules/local/pyopenms_splitmgf.nf'
include { PYOPENMS_CONCTSV as PYOPENMS_CONCTSVSIRIUS } from '../../modules/local/pyopenms_conctsv.nf'
include { PYOPENMS_CONCTSV as PYOPENMS_CONCTSVFINGERID } from '../../modules/local/pyopenms_conctsv.nf'

workflow SIRIUS {

    take:
    ms_channel
    mgf_splitmgf_pyopenms
    sirius_split




    main:

ch_versions = Channel.empty()


if(mgf_splitmgf_pyopenms>1 && sirius_split)
{
PYOPENMS_SPLITMS(ms_channel,"ms")

ch_versions       = ch_versions.mix(PYOPENMS_SPLITMS.out.versions.first())

ms_channel = PYOPENMS_SPLITMS.out.ms.flatMap{id, values -> values.collect { [id, it]}}


}


SIRIUS_SEARCH(ms_channel)
ch_versions       = ch_versions.mix(SIRIUS_SEARCH.out.versions.first())

output_sirius = SIRIUS_SEARCH.out.sirius_tsv
output_sirius = output_sirius.map{meta,file->[[id:"sirius_${meta.id}"],file]}
output_fingerid = SIRIUS_SEARCH.out.fingerid_tsv
output_fingerid = output_fingerid.map{meta,file->[[id:"fingerid_${meta.id}"],file]}
if(mgf_splitmgf_pyopenms>1 && sirius_split)
{

output_sirius = SIRIUS_SEARCH.out.sirius_tsv.groupTuple(by:0)
output_sirius = output_sirius.map{meta,file->[[id:"sirius_${meta.id}"],file]}
output_fingerid = SIRIUS_SEARCH.out.fingerid_tsv.groupTuple(by:0)
output_fingerid = output_fingerid.map{meta,file->[[id:"fingerid_${meta.id}"],file]}


}
PYOPENMS_CONCTSVSIRIUS(output_sirius,"tsv","tsv")
ch_versions       = ch_versions.mix(PYOPENMS_CONCTSVSIRIUS.out.versions.first())
PYOPENMS_CONCTSVFINGERID(output_fingerid,"tsv","tsv")
ch_versions       = ch_versions.mix(PYOPENMS_CONCTSVFINGERID.out.versions.first())

output_sirius = PYOPENMS_CONCTSVSIRIUS.out.csv
output_fingerid = PYOPENMS_CONCTSVFINGERID.out.csv


    emit:
    output_sirius       = output_sirius
    output_fingerid     = output_fingerid
    versions            = ch_versions
}
