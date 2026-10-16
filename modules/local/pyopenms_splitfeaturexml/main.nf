process PYOPENMS_SPLITFEATUREXML{
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0' :
        'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0' }"

    input:
    tuple val(meta),path(input_spectra)
    each  path(input_boundries)

    output:
    tuple val(meta),path("output/*.featureXML"), emit: featurexml
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

        """
    mkdir output
    split_features.py \\
    --input $input_spectra --input_boundries $input_boundries --output output/  $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
