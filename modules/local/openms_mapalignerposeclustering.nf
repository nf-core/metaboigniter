

process OPENMS_MAPALIGNERPOSECLUSTERING {
    tag "Multiple files"
    label 'process_high'

    conda  "bioconda::openms=3.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:3.0.0--h8964181_0' :
        'biocontainers/openms:3.0.0--h8964181_0' }"

    input:
    tuple val(meta), path(featurexml)

    output:
    tuple val(meta), path({meta.id.collect { 'output/'+it+'.trafoXML' }}), emit: trafoxml
    tuple val(meta), path({meta.id.collect { 'output/'+it+'.featureXML' }}), emit: featurexml
    path  "versions.yml"                      , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.id
    def featurexml_input        = featurexml.collect { it }.join(' ')
    def trafoxml_output        = prefix.collect { 'output/'+it+'.trafoXML' }.join(' ')
    def featurexml_output        = prefix.collect { 'output/'+it+'.featureXML' }.join(' ')

        """
    mkdir output
    MapAlignerPoseClustering -in $featurexml_input -out $featurexml_output -trafo_out $trafoxml_output $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/OpenMS Version/{getline; getline; print \$3}')
    END_VERSIONS
        """
}
