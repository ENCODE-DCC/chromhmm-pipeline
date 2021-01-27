version 1.0

import "../../../chromhmm.wdl" as chromhmm

workflow test_binarize {
    input {
        Array[File] bams
        File cellmarkfiletable
        File chrom_sizes
        Int bin_size
    }

    call chromhmm.binarize { input:
        bams = bams,
        cellmarkfiletable = cellmarkfiletable,
        chrom_sizes = chrom_sizes,
        bin_size = bin_size,
    }
}
