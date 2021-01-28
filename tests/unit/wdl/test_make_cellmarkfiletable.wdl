version 1.0

import "../../../chromhmm.wdl" as chromhmm

workflow test_make_cellmarkfiletable {
    input {
        Array[BamPairWithMetadata] bams
    }

    call chromhmm.make_cellmarkfiletable { input:
        bams = write_json(bams),
    }
}
