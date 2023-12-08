process MS2QUERY_MODELFULLTRAIN {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::ms2query=1.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ms2query:1.2.0--pyhdfd78af_0' :
        'biocontainers/ms2query:1.2.0--pyhdfd78af_0' }"


    input:
    tuple val(meta), path(mgf)

    output:
    path "output/*.sqlite"                      , emit: sqlite
    path "output/*.model"                        , emit: s2v_model
    path "output/*.hdf5"                         , emit: ms2ds_model
    path "output/*.onnx"                         , emit: ms2query_model
    path "output/*s2v_embeddings.pickle"        , emit: s2v_embeddings
    path "output/*ms2ds_embeddings.pickle"      , emit: ms2ds_embeddings
    path "output/*.syn1neg.npy"                  , emit: trainables_syn1neg
    path "output/*.wv.vectors.npy"               , emit: wv_vectors
    path  "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
        """

    mkdir output
    fulltrain_ms2query.py --input $mgf --output $PWD/output/  --polarity negative


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ms2query: \$(python -c "import ms2query; print(ms2query.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
