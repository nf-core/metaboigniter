process MS2QUERY_MODELTRAIN {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::ms2query=1.2.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ms2query:1.2.3--pyhdfd78af_0' :
        'biocontainers/ms2query:1.2.3--pyhdfd78af_0' }"


    input:
    tuple val(meta), path(mgf), path(modelfiles,stageAs: "model/*")

    output:
    path "output/*.sqlite", emit: sqlite
    path "model/*.model", emit: s2v_model, includeInputs:true
    path "model/*.hdf5", emit: ms2ds_model, includeInputs:true
    path "model/*.onnx", emit: ms2query_model, includeInputs:true
    path "output/*s2v_embeddings.pickle", emit: s2v_embeddings
    path "output/*ms2ds_embeddings.pickle", emit: ms2ds_embeddings
    path "model/*.syn1neg.npy", emit: trainables_syn1neg, includeInputs:true
    path "model/*.wv.vectors.npy", emit: wv_vectors, includeInputs:true
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
        """
    mkdir output
    train_ms2query.py --input $mgf --output output/  --model model/  $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ms2query: \$(python -c "import ms2query; print(ms2query.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
