process PYOPENMS_GAPFILLCONSENSUS {
    tag "$meta.id"
    label 'process_single'

    conda "bioconda::pyopenms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0' :
        'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0' }"

    input:
    tuple val(meta), path(consensusxml)
    tuple val(samples), path(sample_maps, stageAs: 'sample_maps/*', arity: '1..*'), path(candidates, stageAs: 'candidates/*', arity: '1..*'), path(fills, stageAs: 'fills/*', arity: '1..*')

    output:
    tuple val(meta), path("${prefix}.consensusXML")                         , emit: consensusxml
    tuple val(meta), path("output_requantification_mask_${meta.id}.tsv")      , emit: mask
    tuple val(meta), path("output_requantification_provenance_${meta.id}.tsv"), emit: provenance
    tuple val(meta), path("output_requantification_summary_${meta.id}.tsv")   , emit: summary
    path  "versions.yml"                                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}_gapfilled"
    if (samples.size() != sample_maps.size() || samples.size() != candidates.size() || samples.size() != fills.size()) {
        error "PYOPENMS_GAPFILLCONSENSUS: ${samples.size()} samples but ${sample_maps.size()}/${candidates.size()}/${fills.size()} tables"
    }
    def sample_tables = (0..<samples.size()).collect { index ->
        "--sample-tables '${samples[index]}' '${sample_maps[index]}' '${candidates[index]}' '${fills[index]}'"
    }.join(' \\\n        ')
    """
    gapfill_consensus.py \\
        --consensus ${consensusxml} \\
        ${sample_tables} \\
        --output-consensus ${prefix}.consensusXML \\
        --mask output_requantification_mask_${meta.id}.tsv \\
        --provenance output_requantification_provenance_${meta.id}.tsv \\
        --summary output_requantification_summary_${meta.id}.tsv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}_gapfilled"
    """
    touch ${prefix}.consensusXML
    touch output_requantification_mask_${meta.id}.tsv
    touch output_requantification_provenance_${meta.id}.tsv
    touch output_requantification_summary_${meta.id}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
    """
}
