process OPENMS_FILECONVERTER {
    tag "$meta.id"
    label 'process_low'

    conda  "bioconda::openms=3.0.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:3.0.0--h8964181_0' :
        'biocontainers/openms:3.0.0--h8964181_0' }"

    input:
    tuple val(meta), path(mzml)

    output:
    tuple val(meta), path("output/${mzml.name}"), emit: mzml
    path  "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

        """
        mkdir output
        # The file name is kept: identification output refers to spectra by mzML file name
        FileConverter \\
                        -in $mzml -out output/${mzml.name} $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/OpenMS Version/{getline; getline; print \$3}')
    END_VERSIONS
        """
}
