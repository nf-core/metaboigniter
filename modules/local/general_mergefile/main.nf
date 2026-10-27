process GENERAL_MERGEFILE{
    tag "$meta.id"
    label 'process_medium'
    conda "bioconda::pyopenms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0' :
        'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0' }"

    input:
    tuple val(meta), path(input_target)

    output:
    tuple val(meta), path("output/${meta.id}.${input_target[0].extension}"), emit: mergedfile
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def inputs        = input_target.collect { input_file -> input_file }.join(' ')


        """
    mkdir output

    cat $inputs > output/${prefix}.${input_target[0].extension} $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
