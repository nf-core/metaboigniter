process PYOPENMS_CONCTSV {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::pyopenms=3.6.0"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0'
        : 'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0'}"

    input:
    tuple val(meta), path(csv, stageAs: "inputs/*")
    val separator_in
    val separator_out

    output:
    tuple val(meta), path("*.contc.csv"), emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """

        conc_tsv.py --input_dir inputs/ --output_file ${prefix}.contc.csv --input_type ${separator_in} --output_type ${separator_out} ${args}



    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
