version 1.0

struct BamPairWithMetadata {
    File bam
    File control_bam
    String cell_type
    String chromatin_mark
}

workflow chromhmm {
    meta {
        version: "0.1.0"
        caper_docker: "encodedcc/chromhmm-pipeline:0.1.0"
        caper_singularity: "docker://encodedcc/chromhmm-pipeline:0.1.0"
    }

    input {
        Array[BamPairWithMetadata] bam_pairs
        File chrom_sizes
        Int states = 10
        Int bin_size = 200
    }

    call make_cellmarkfiletable { input:
        bams = write_json(bam_pairs),
    }

   # Adapted from https://github.com/openwdl/wdl/issues/203#issuecomment-580002994
    scatter(bam_pair in bam_pairs) {
        File bams = bam_pair.bam
        File control_bams = bam_pair.control_bam
    }
    Array[File] all_bams = flatten([bams, control_bams])

    call binarize { input:
        bams = all_bams,
        cellmarkfiletable = make_cellmarkfiletable.cellmarkfiletable,
        bin_size = bin_size,
        chrom_sizes = chrom_sizes,
    }

    call model { input:
        binarized = binarize.binarized,
        bin_size = bin_size,
        states = states,
    }
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
    input {
        Array[File] bams
        File chrom_sizes
        File cellmarkfiletable
        Int bin_size
    }

    command {
        mkdir bams
        mv ~{sep=' ' bams} bams
        java -Xmx20G -jar /opt/ChromHMM.jar BinarizeBam \
            -b ~{bin_size} \
            -gzip \
            ~{chrom_sizes} bams ~{cellmarkfiletable} binarize
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
    input {
        Array[File] binarized
        Int bin_size
        Int states
    }

    command {
        mkdir /binarized
        mv ~{sep=' /binarized/; mv ' binarized} /binarized/
        java -Xmx20G -jar /opt/ChromHMM.jar LearnModel -b ~{bin_size} -p 0 /binarized OUTPUT ~{states} hg38
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
