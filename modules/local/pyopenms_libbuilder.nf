
process PYOPENMS_LIBBUILDER{
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'quay.io/biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"

    input:
    tuple val(meta), path(consensusxml)

    output:
    tuple val(meta),path("*tsv"), emit: tsv
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """

    lib_generator.py \\
     --input $consensusxml  --output ${prefix}.tsv $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
