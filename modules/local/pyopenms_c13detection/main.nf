process PYOPENMS_C13DETECTION {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:3.6.0--py311hbf5b9ba_0' :
        'biocontainers/pyopenms:3.6.0--py311hbf5b9ba_0' }"


    input:
    tuple val(meta), path(input_target),path(input_spectra)

    output:
    tuple val(meta), path("output/*.featureXML"),path(input_spectra), emit: featurexml
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """
        mkdir output
        c13detection.py --input_feature $input_target --input_mzml $input_spectra  --output_feature output/${prefix}.featureXML $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}
