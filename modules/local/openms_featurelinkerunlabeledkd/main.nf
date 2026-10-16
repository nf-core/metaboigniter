process OPENMS_FEATURELINKERUNLABELEDKD {
    tag "$meta.id"
    label 'process_high'

    conda  "bioconda::openms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:3.6.0--hc52dbad_0' :
        'biocontainers/openms:3.6.0--hc52dbad_0' }"

    input:
    tuple val(meta), path(featurexml)

    output:
    tuple val(meta), path("*.consensusXML"), emit: consensusxml
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def featurexml_input        = featurexml.collect { input_file -> input_file }.join(' ')
        """

    FeatureLinkerUnlabeledKD -in $featurexml_input -out ${prefix}.consensusXML $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/^Version/{print \$3; exit}')
    END_VERSIONS
        """
}
