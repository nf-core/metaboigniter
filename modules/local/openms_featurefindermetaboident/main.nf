process OPENMS_FEATUREFINDERMETABOIDENT {
    tag "$meta.id"
    label 'process_low'

    conda  "bioconda::openms=3.6.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms:3.6.0--hc52dbad_0' :
        'biocontainers/openms:3.6.0--hc52dbad_0' }"

    input:
    tuple val(meta), path(mzml), path(library)

    output:
    tuple val(meta), path("${prefix}.featureXML"), emit: featurexml
    tuple val(meta), path("${prefix}.ffmi.log")  , emit: log
    path  "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    # The library must have at least one target with a finite mass, a finite
    # retention time and a finite, positive retention-time range.
    awk -F'\\t' '
        function finite(value) { return value ~ /^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)([eE][+-]?[0-9]+)?\$/ }
        NR == 1 {
            for (i = 1; i <= NF; i++) column[\$i] = i
            if (!("Mass" in column) || !("RetentionTime" in column) || !("RetentionTimeRange" in column)) {
                print "Library ${library} lacks Mass, RetentionTime or RetentionTimeRange" > "/dev/stderr"; exit 1
            }
            next
        }
        {
            rows++
            mass = \$column["Mass"]; rt = \$column["RetentionTime"]; range = \$column["RetentionTimeRange"]
            if (!finite(mass) || !finite(rt) || !finite(range) || range + 0 <= 0) {
                print "Invalid library row " NR " in ${library}" > "/dev/stderr"; exit 1
            }
        }
        END { if (rows < 1) { print "Library ${library} has no targets" > "/dev/stderr"; exit 1 } }
    ' ${library}

    # FeatureFinderMetaboIdent 3.6.0 exits with status 8 when no target of a
    # non-empty library yields a feature candidate, but it uses status 8 for
    # other errors too (e.g. "Could not find any points for chromatogram" for a
    # target RT window without a non-empty MS1 spectrum, or a failed imputation
    # fit). Status 8 is turned into an empty feature map only for the recognised
    # zero-candidate log of a valid extraction (checked below); any other status
    # 8 or failure is propagated, so extraction or configuration errors never
    # become silent missing values. Exit status 0 is not inspected here.
    status=0
    FeatureFinderMetaboIdent \\
        -id ${library} \\
        -in ${mzml} \\
        -out ${prefix}.featureXML \\
        ${args} \\
        2>&1 | tee ${prefix}.ffmi.log || status=\$?

    if [ "\$status" -ne 0 ]; then
        if [ "\$status" -eq 8 ] \\
            && [ ! -e ${prefix}.featureXML ] \\
            && grep -qxF 'Found 0 feature candidates in total.' ${prefix}.ffmi.log \\
            && grep -qxF '0 features left after selection of best candidates.' ${prefix}.ffmi.log \\
            && grep -qF 'Error: Unexpected internal error (Empty or uninitalized range object' ${prefix}.ffmi.log \\
            && ! grep -qF 'Could not find any points for chromatogram' ${prefix}.ffmi.log \\
            && [ "\$(grep -c 'Error:' ${prefix}.ffmi.log)" -eq 1 ]; then
            echo "FeatureFinderMetaboIdent found no candidate for any target; writing an empty feature map" | tee -a ${prefix}.ffmi.log
            printf '%s\\n' \\
                '<?xml version="1.0" encoding="ISO-8859-1"?>' \\
                '<featureMap version="1.9" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' \\
                '<featureList count="0">' \\
                '</featureList>' \\
                '</featureMap>' > ${prefix}.featureXML
        else
            exit "\$status"
        fi
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/^Version/{print \$3; exit}')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.featureXML
    touch ${prefix}.ffmi.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        openms: \$(OpenMSInfo | awk '/^Version/{print \$3; exit}')
    END_VERSIONS
    """
}
