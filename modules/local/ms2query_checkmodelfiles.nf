process MS2QUERY_CHECKMODELFILES {
    tag "checking files"
    label 'process_medium'

    conda "bioconda::ms2query=1.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ms2query:1.2.0--pyhdfd78af_0' :
        'biocontainers/ms2query:1.2.0--pyhdfd78af_0' }"



    input:
    path modelfiles

    output:
    path "*.sqlite", emit: sqlite, includeInputs:true, optional: true
    path "*.model", emit: s2v_model, includeInputs:true
    path "*.hdf5", emit: ms2ds_model, includeInputs:true
    path "*.onnx", emit: ms2query_model, includeInputs:true
    path "*s2v_embeddings.pickle", emit: s2v_embeddings, includeInputs:true, optional: true
    path "*ms2ds_embeddings.pickle", emit: ms2ds_embeddings, includeInputs:true, optional: true
    path "*.syn1neg.npy", emit: trainables_syn1neg, includeInputs:true
    path "*.wv.vectors.npy", emit: wv_vectors, includeInputs:true
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def model_files        = modelfiles.collect { it }.join(' ')
        """

    checkfiles_ms2query.py $model_files $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ms2query: \$(python -c "import ms2query; print(ms2query.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
