// Helpers shared by the real-data pipeline tests in tests/default.nf.test.
import java.security.MessageDigest

class RequantTestUtils {

    static final String OBSERVED  = 'TABLE_OUTPUT/output_quantification_Linked_data.tsv'
    static final String GAPFILLED = 'TABLE_OUTPUT/output_quantification_Linked_data_gapfilled.tsv'
    static final String MASK      = 'TABLE_OUTPUT/output_requantification_mask_Linked_data.tsv'
    static final String SUMMARY   = 'TABLE_OUTPUT/output_requantification_summary_Linked_data.tsv'

    // OpenMS assigns these identifiers randomly, so they are omitted from stable hashes.
    static final List UID_COLUMNS = ['id', 'feature_ids']

    // Stable matrix hashes from the existing test profile, recorded without requantification.
    static final String REAL_OBSERVED_MD5 = 'd62f29e6a562260e6daf319e929f806a'
    static final String REAL_OBSERVED_PARALLEL_MD5 = '2f529e502f11c5aba6d6098f6c2e0e96'
    static final String REAL_IDENTIFICATION_MD5 = '4fe8ab8aebf0f15437618d34759b4fb2'

    static final String REAL_GAPFILLED_PARALLEL_MD5 = '21408f8ce156852cbf10f5066197348f'
    static final String REAL_GAPFILLED_IDENTIFICATION_MD5 = '9b184358a2f1fd7bb80e749ed15963f2'
    static final List SUMMARY_ALL_COLUMNS = [
        'consensus_rows', 'observed', 'targets_requested', 'candidates_recovered', 'accepted', 'rejected',
        'no_candidate', 'rejected_malformed_qc_metadata', 'rejected_existing_signal_overlap',
        'rejected_no_peak_at_apex', 'rejected_apex_outside_target_window', 'rejected_model_status_not_valid',
        'rejected_low_apex_signal_fraction', 'rejected_shared_candidate_signal',
        'rejected_duplicate_feature_identity', 'missing_after',
    ]
    static final List REAL_SUMMARY_ALL_PARALLEL = [57372, 108352, 63764, 40818, 4321, 36497, 22946, 0, 11294, 5980, 0, 18121, 1012, 90, 0, 59443]
    static final List REAL_SUMMARY_ALL_IDENTIFICATION = [57404, 108353, 63859, 41167, 4292, 36875, 22692, 0, 11171, 6060, 0, 18542, 1016, 86, 0, 59567]

    static List summaryAll(List lines) {
        def row = tsv(lines).find { it.sample == 'all' }
        return SUMMARY_ALL_COLUMNS.collect { row[it] as long }
    }

    static List header(List lines) {
        return lines[0].split('\t', -1) as List
    }

    static List<Map> tsv(List lines) {
        def columns = header(lines)
        return lines.drop(1).collect { line ->
            def values = line.split('\t', -1) as List
            assert values.size() == columns.size() : "ragged TSV line: ${line}"
            [columns, values].transpose().collectEntries()
        }
    }

    static String canonical(String value) {
        if (value ==~ /-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?/) {
            return String.format(Locale.ROOT, '%.6g', value as double)
        }
        return value
    }

    static List stableView(List lines) {
        def keep = header(lines).findAll { !(it in UID_COLUMNS) }
        def rows = tsv(lines).collect { row -> keep.collect { canonical(row[it]) }.join('\t') }.sort()
        return [keep.join('\t')] + rows
    }

    static String stableMd5(List lines) {
        def digest = MessageDigest.getInstance('MD5').digest(stableView(lines).join('\n').getBytes('UTF-8'))
        return digest.encodeHex().toString()
    }

    static List sampleColumns(List lines) {
        return header(lines).findAll { it.endsWith('.mzML') }.sort()
    }

    // Check that the observed matrix, gap-filled matrix and mask describe the same cells.
    static List crossCheck(List observedLines, List gapfilledLines, List maskLines) {
        def problems = []
        def observed = tsv(observedLines).collectEntries { [it.id, it] }
        def gapfilled = tsv(gapfilledLines).collectEntries { [it.id, it] }
        def samples = sampleColumns(maskLines)
        if (observed.keySet() != gapfilled.keySet()) {
            problems << 'observed and gap-filled matrices have different consensus ids'
        }
        if (sampleColumns(observedLines) != samples || sampleColumns(gapfilledLines) != samples) {
            problems << 'sample columns differ between matrices and mask'
        }
        def counts = [:].withDefault { 0 }
        tsv(maskLines).each { maskRow ->
            def observedRow = observed[maskRow.consensus_uid]
            def gapfilledRow = gapfilled[maskRow.consensus_uid]
            if (observedRow == null || gapfilledRow == null) {
                problems << "mask row ${maskRow.consensus_uid} missing from a matrix"
                return
            }
            ['charge', 'RT', 'mz'].each { column ->
                if (observedRow[column] != gapfilledRow[column]) {
                    problems << "row ${maskRow.consensus_uid} column ${column} differs"
                }
            }
            samples.each { sample ->
                def state = maskRow[sample]
                counts[state] += 1
                def observedValue = observedRow[sample] as double
                def gapfilledValue = gapfilledRow[sample] as double
                if (state == 'observed' && !(observedValue > 0 && observedRow[sample] == gapfilledRow[sample])) {
                    problems << "observed cell ${maskRow.consensus_uid}/${sample}: ${observedRow[sample]} vs ${gapfilledRow[sample]}"
                } else if (state == 'requantified' && !(observedValue == 0 && gapfilledValue > 0)) {
                    problems << "requantified cell ${maskRow.consensus_uid}/${sample}: ${observedRow[sample]} vs ${gapfilledRow[sample]}"
                } else if (state.startsWith('missing_') && !(observedValue == 0 && gapfilledValue == 0)) {
                    problems << "missing cell ${maskRow.consensus_uid}/${sample}: ${observedRow[sample]} vs ${gapfilledRow[sample]}"
                } else if (!(state in ['observed', 'requantified', 'missing_no_candidate', 'missing_failed_qc', 'missing_existing_signal_overlap'])) {
                    problems << "unknown mask state ${state}"
                }
            }
        }
        return [problems.take(20), counts]
    }
}
