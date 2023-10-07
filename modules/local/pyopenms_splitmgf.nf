process PYOPENMS_SPLITMGF{
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'quay.io/biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"


    input:
    tuple val(meta),path(mgf)
    val file_type


    output:
    tuple val(meta),path("output/*.mgf"), emit: mgf, optional: true
    tuple val(meta),path("output/*.ms"), emit: ms, optional: true
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """
    mkdir output
    split_mgf.py --mgf_file $mgf --file_type $file_type  $args --output output/



    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
