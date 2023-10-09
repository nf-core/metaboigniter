
include { PYOPENMS_SPLIT } from '../../modules/local/pyopenms_split.nf'
include { MS2QUERY_CHECKMODELFILES } from '../../modules/local/ms2query_checkmodelfiles.nf'
include { MS2QUERY_SEARCH } from '../../modules/local/ms2query_search.nf'
include { MS2QUERY_MODELTRAIN } from '../../modules/local/ms2query_modeltrain.nf'
include { MS2QUERY_MODELFULLTRAIN } from '../../modules/local/ms2query_modelfulltrain.nf'
include { PYOPENMS_EXPORT } from '../../modules/local/pyopenms_export.nf'
include { MS2QUERY_EXPORT } from '../../modules/local/ms2query_export.nf'
include { PYOPENMS_SPLITMGF } from '../../modules/local/pyopenms_splitmgf.nf'
include { PYOPENMS_CONCTSV as PYOPENMS_CONCTSVMS2QUERY } from '../../modules/local/pyopenms_conctsv.nf'
include { MS2QUERY_MODELDOWNLOADER } from '../../subworkflows/local/ms2query_modeldownloader.nf'


workflow MS2QUERY {

    take:
    mgf_channel
    offline_model_ms2query
    models_dir_ms2query
    train_library_ms2query
    library_path_ms2query
    polarity
    mgf_splitmgf_pyopenms




    main:

ch_versions = Channel.empty()



if(!offline_model_ms2query)
{

MS2QUERY_MODELDOWNLOADER(polarity)

MS2QUERY_MODELDOWNLOADER.out.model_files.collect() |  MS2QUERY_CHECKMODELFILES
ch_versions       = ch_versions.mix(MS2QUERY_CHECKMODELFILES.out.versions.first())
}else{

Channel
    .fromPath(models_dir_ms2query+"/*")
    .collect() | MS2QUERY_CHECKMODELFILES

    ch_versions       = ch_versions.mix(MS2QUERY_CHECKMODELFILES.out.versions.first())
}


all_model_files=MS2QUERY_CHECKMODELFILES.out.sqlite.mix(
        MS2QUERY_CHECKMODELFILES.out.s2v_model,
    MS2QUERY_CHECKMODELFILES.out.ms2ds_model,
    MS2QUERY_CHECKMODELFILES.out.ms2query_model,
    MS2QUERY_CHECKMODELFILES.out.s2v_embeddings,
    MS2QUERY_CHECKMODELFILES.out.ms2ds_embeddings,
    MS2QUERY_CHECKMODELFILES.out.trainables_syn1neg,
    MS2QUERY_CHECKMODELFILES.out.wv_vectors
).collect().toList()

if(mgf_splitmgf_pyopenms>1)
{

PYOPENMS_SPLITMGF(mgf_channel,"mgf")

ch_versions       = ch_versions.mix(PYOPENMS_SPLITMGF.out.versions.first())

mgf_channel = PYOPENMS_SPLITMGF.out.mgf.flatMap{id, values -> values.collect { [id, it]}}

}


if(train_library_ms2query)
{

    Channel
    .fromPath(library_path_ms2query)
    .map{it->[[id:it.baseName],it]}.combine(all_model_files) | MS2QUERY_MODELTRAIN

all_model_files=MS2QUERY_MODELTRAIN.out.sqlite.mix(
        MS2QUERY_MODELTRAIN.out.s2v_model,
    MS2QUERY_MODELTRAIN.out.ms2ds_model,
    MS2QUERY_MODELTRAIN.out.ms2query_model,
    MS2QUERY_MODELTRAIN.out.s2v_embeddings,
    MS2QUERY_MODELTRAIN.out.ms2ds_embeddings,
    MS2QUERY_MODELTRAIN.out.trainables_syn1neg,
    MS2QUERY_MODELTRAIN.out.wv_vectors
).collect().toList()

ch_versions       = ch_versions.mix(MS2QUERY_MODELTRAIN.out.versions.first())

}


MS2QUERY_SEARCH(mgf_channel,
all_model_files)

ch_versions       = ch_versions.mix(MS2QUERY_SEARCH.out.versions.first())

output = MS2QUERY_SEARCH.out.csv.map{meta,file->[[id:"ms2query_${meta.id}"],file]}

if(mgf_splitmgf_pyopenms>1)
{

output = output.groupTuple(by:0)


}
PYOPENMS_CONCTSVMS2QUERY(output,"csv","tsv")
ch_versions       = ch_versions.mix(PYOPENMS_CONCTSVMS2QUERY.out.versions.first())



    emit:
    ms2query            = PYOPENMS_CONCTSVMS2QUERY.out.csv
    versions       = ch_versions
}
