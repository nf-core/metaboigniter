process OPENMS_MAPALIGNERPOSECLUSTERINGMZML {
    tag "Multiple files"
    label 'process_high'

    conda "bioconda::openms=3.6.0"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/openms:3.6.0--hc52dbad_0'
        : 'biocontainers/openms:3.6.0--hc52dbad_0'}"

    input:
    tuple val(meta), path(featurexml)

    output:
    tuple val(meta), path { meta.id.collect { map_id -> 'output/' + map_id + '.trafoXML' } }, emit: trafoxml
    tuple val(meta), path { meta.id.collect { map_id -> 'output/' + map_id + '.mzML' } }, emit: mzml
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.id
    def featurexml_input = featurexml.collect { input_file -> input_file }.join(' ')
    def trafoxml_output = prefix.collect { map_id -> 'output/' + map_id + '.trafoXML' }.join(' ')
    def mzml_output = prefix.collect { map_id -> 'output/' + map_id + '.mzML' }.join(' ')

    """
    mkdir output
    MapAlignerPoseClustering -in ${featurexml_input} -out ${mzml_output} -trafo_out ${trafoxml_output} ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/^Version/{print \$3; exit}')
    END_VERSIONS
        """
}
