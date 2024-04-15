process OPENMS_PEAKPICKERHIRES {
    tag "$meta.id"
    label 'process_medium'

    conda  "bioconda::openms=3.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:3.0.0--h8964181_0' :
        'biocontainers/openms:3.0.0--h8964181_0' }"

    input:
    tuple val(meta), path(mzml)

    output:
    tuple val(meta), path("output/*.mzML"), emit: mzml
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """
        mkdir output
        PeakPickerHiRes \\
                        -in $mzml -out output/${prefix}.mzML $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/OpenMS Version/{getline; getline; print \$3}')
    END_VERSIONS
        """
}
