process MS2QUERY_EXPORT {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'quay.io/biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"




    input:
    tuple val(meta), path(tsv),path(csv)

    output:
    tuple val(meta), path("*.ms2query.tsv")     , emit: tsv
    path  "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """

    analog_annotation.py $tsv $csv ${prefix}.ms2query.tsv $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import ms2query; print(ms2query.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
