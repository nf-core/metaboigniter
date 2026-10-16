process PYOPENMS_MSMAPPING {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::pyopenms=3.6.0"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0'
        : 'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0'}"

    input:
    tuple val(meta), path(input_target), path(input_spectra)

    output:
    tuple val(meta), path("output/*.consensusXML"), emit: consensusxml
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mzml_input = input_spectra.collect { input_file -> input_file }.join(' ')
    """
    mkdir output

    extract_mapping.py \\
        --consensus_input ${input_target} --mzml_file_paths ${mzml_input} --output output/${prefix}.consensusXML ${args}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
