process PYOPENMS_REQUANTQC {
    tag "$meta.id"
    label 'process_single'

    conda "bioconda::pyopenms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0' :
        'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0' }"

    input:
    tuple val(meta), path(targets), path(originals), path(candidates)

    output:
    tuple val(meta), path("${prefix}.candidates.tsv"), emit: candidates
    tuple val(meta), path("${prefix}.fills.tsv")     , emit: fills
    path  "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args            = task.ext.args ?: ''
    prefix              = task.ext.prefix ?: "${meta.id}"
    def candidates_args = candidates ? "--candidates ${candidates}" : ''
    """
    requantification_qc.py \\
        --sample ${meta.id} \\
        --targets ${targets} \\
        --originals ${originals} \\
        ${candidates_args} \\
        --output-candidates ${prefix}.candidates.tsv \\
        --output-fills ${prefix}.fills.tsv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.candidates.tsv ${prefix}.fills.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
    """
}
