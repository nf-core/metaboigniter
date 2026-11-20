process PYOPENMS_LIBBUILDER {
    tag "$meta.id"
    label 'process_single'

    conda "bioconda::pyopenms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0' :
        'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0' }"

    input:
    tuple val(meta), path(featurexml)
    tuple val(meta2), path(consensusxml)

    output:
    // eval runs inside `bash -c "..."`, so awk field references are escaped for that shell
    tuple val(meta), path("${prefix}.library.tsv"), eval("awk -v column=n_targets 'NR == 1 { for (i = 1; i <= NF; i++) if (\\\$i == column) c = i } NR == 2 && c { print \\\$c }' ${prefix}.sample_map.tsv"), emit: library
    tuple val(meta), path("${prefix}.targets.tsv")   , emit: targets
    tuple val(meta), path("${prefix}.originals.tsv") , emit: originals
    tuple val(meta), path("${prefix}.sample_map.tsv"), emit: sample_map
    path  "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    lib_generator.py \\
        --consensus ${consensusxml} \\
        --features ${featurexml} \\
        --sample ${meta.id} \\
        --library ${prefix}.library.tsv \\
        --targets ${prefix}.targets.tsv \\
        --originals ${prefix}.originals.tsv \\
        --sample-map ${prefix}.sample_map.tsv \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    printf 'CompoundName\\tSumFormula\\tMass\\tCharge\\tRetentionTime\\tRetentionTimeRange\\tIsoDistribution\\n' > ${prefix}.library.tsv
    touch ${prefix}.targets.tsv ${prefix}.originals.tsv
    printf 'sample\\tmap_index\\tn_features\\tn_targets\\theader_filename\\theader_filename_matches_sample\\n${meta.id}\\t0\\t0\\t0\\t${meta.id}.mzML\\ttrue\\n' > ${prefix}.sample_map.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
    """
}
