
process OPENMS_GNPSEXPORT {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'quay.io/biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"

    input:
    tuple val(meta), path(consensusxml),path(mzml)


    output:
    tuple val(meta), path("MSMS.mgf"), emit: mgf
    tuple val(meta), path("FeatureQuantificationTable.txt"), emit: txt
    tuple val(meta), path("SuppPairs.csv"), emit: csv,optional: true
    tuple val(meta), path("metadata.tsv"), emit: tsv
    path  "versions.yml"                      , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: meta.id
    def mzml_input        = mzml.collect { it }.join(' ')

        """


        GNPSExport -in_cm $consensusxml -in_mzml $mzml_input  -out MSMS.mgf -out_quantification FeatureQuantificationTable.txt -out_pairs SuppPairs.csv -out_meta_values metadata.tsv $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/OpenMS Version/{getline; getline; print \$3}')
    END_VERSIONS
        """
}
