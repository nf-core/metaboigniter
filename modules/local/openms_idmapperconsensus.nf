process OPENMS_IDMAPPERCONSENSUS {
    tag "$meta.id"
    label 'process_medium'
    conda  "bioconda::openms=3.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:3.0.0--h8964181_0' :
        'biocontainers/openms:3.0.0--h8964181_0' }"

    input:
    tuple val(meta), path(input_target),path(input_spectra,stageAs: "spectra/*")
    each path(input_id)

    output:
    tuple val(meta), path("output/*.consensusxml"), emit: consensusxml
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """


        mkdir output
        IDMapper \\
                    -id $input_id -in $input_target -spectra:in ${input_spectra[0]}  -out output/${prefix}.consensusxml


        # Then process the rest
        for input_spectra_in in ${input_spectra[-1]}; do
            IDMapper -id $input_id -in output/${prefix}.consensusxml -spectra:in \$input_spectra_in -out output/${prefix}.consensusxml

        done


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/OpenMS Version/{getline; getline; print \$3}')
    END_VERSIONS
        """
}
