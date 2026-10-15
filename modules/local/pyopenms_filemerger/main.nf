
process PYOPENMS_FILEMERGER {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"

    input:
    tuple val(meta), path(consensusxml_input)

    output:
    tuple val(meta), path("output/*.consensusXML"), emit: consensusxml
    path  "versions.yml"                      , emit: versions



    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.id
    def inputs        = consensusxml_input.collect { it }.join(' ')

        """
        mkdir output
        file_merger_consensus.py --input $inputs --output output/${prefix}.consensusXML $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>&1 | grep -v "Warning:")
    END_VERSIONS
        """
}
