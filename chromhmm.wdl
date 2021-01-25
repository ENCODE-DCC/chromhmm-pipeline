version 1.0

workflow chromhmm {
    meta {
        version: "0.1.0"
        caper_docker: "quay.io/encode-dcc/chromhmm-pipeline:0.1.0"
        caper_singularity: "docker://quay.io/encode-dcc/chromhmm-pipeline:0.1.0"
    }

    input {
        Array[BamPairWithMetadata] bams
        File chrom_sizes
        Int states = 10
        Int bin_size = 200
    }

    call make_cellmarkfiletable { input:
        bams = write_json(bams)
    }

   # Adapted from https://github.com/openwdl/wdl/issues/203#issuecomment-580002994
    scatter(bam in bams) {
        File bams_ = bam.bam
        File? control_bams = bam.control_bam
    }
    Array[File] all_bams = flatten([bams_, select_all(control_bams)])

    call binarize { input:
        bams = all_bams,
        cellmarkfiletable = make_cellmarkfiletable.cellmarkfiletable,
        bin_size = bin_size,
        chrom_sizes = chrom_sizes
    }

    call model { input:
        binarized = binarize.binarized,
        bin_size = bin_size,
        states = states
    }
}

struct BamPairWithMetadata {
    File bam
    File? control_bam
    String cell_type
    String chromatin_mark
}

task make_cellmarkfiletable {
    input {
        File bams
        String? output_filename = "cellmarkfiletable.tsv"
    }

    command {
        python "$(which make_cellmarkfiletable.py)" -i ~{bams} -o ~{output_filename}
    }

    output {
        File cellmarkfiletable = "~{output_filename}"
    }
}

task binarize {
    Array[File] bams
    File chrom_sizes
    File cellmarkfiletable
    Int bin_size

    command {
        mkdir /bams
        mv ~{sep=' ' bams} /bams/
        java -Xmx20G -jar /ChromHMM/ChromHMM.jar BinarizeBam -b ~{bin_size} -gzip ~{chrom_sizes} /bams/ ~{cellmarkfiletable} binarize
    }

    output {
        Array[File] binarized = glob("binarize/*")
    }

     # runs fine at 128, might as well go double to play it safe
    runtime {
        cpu: 8
        memory: "30 GB"
        disks: "local-disk 250 SSD"
    }
}

task model {
    Array[File] binarized
    Int bin_size
    Int states

    command {
        mkdir /binarized
        mv ~{sep=' /binarized/; mv ' binarized} /binarized/
        java -Xmx20G -jar /ChromHMM/ChromHMM.jar LearnModel -b ~{bin_size} -p 0 /binarized OUTPUT ~{states} hg38
     }

    output {
       Array[File] out = glob("OUTPUT/*")
    }

     # when I gave it 100 processors, load doesnt really break 7
    runtime {
        cpu: 8
        memory: "30 GB"
        disks: "local-disk 250 SSD"
    }
}
