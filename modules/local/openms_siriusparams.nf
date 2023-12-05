
process OPENMS_SIRIUSPARAMS {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'quay.io/biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"

    input:
    tuple val(meta), path(consensusxml),path(featurexml),path(mzml),path(ms1)

    output:
    tuple val(meta), path("*.ms"), emit: msfile
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mzml_input        = mzml.collect { it }.join(' ')
    def ms_output        = mzml.collect { "${it.baseName}.ms" }.join(' ')
    def ms1_input        = mzml.collect { it }.join(' ')
    def featurexml_input        = featurexml.collect { it }.join(' ')

        """

        mkdir output
        generate_ms_params.py --consensus_file_path $consensusxml --mzml_file_paths $mzml_input --featurexml_file_paths $featurexml_input --ms1_file_paths $ms1_input --output ${consensusxml.baseName}.ms --outputs_unmapped $ms_output $args



    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/OpenMS Version/{getline; getline; print \$3}')
    END_VERSIONS
        """
}
