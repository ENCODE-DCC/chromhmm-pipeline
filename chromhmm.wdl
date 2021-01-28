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
        String assembly
        Int num_states = 10
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

    # Assumes cell types are all the same. Only affects the task outputs, outputs for
    # all cell types will be available in the task execution directory.
    String cell_type = bam_pairs[0].cell_type

    call learn_model { input:
        binarized = binarize.binarized,
        bin_size = bin_size,
        num_states = num_states,
        assembly = assembly,
        cell_type = cell_type,
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
        java -Xmx20G -jar /opt/ChromHMM/ChromHMM.jar BinarizeBam \
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

task learn_model {
    input {
        Array[File] binarized
        Int bin_size
        Int num_states
        String assembly
        String cell_type
    }

    command {
        mkdir binarized
        mv ~{sep=' ' binarized} binarized
        java -Xmx20G -jar /opt/ChromHMM/ChromHMM.jar LearnModel \
            -b ~{bin_size} \
            -p 0 \
            -gzip \
            binarized output ~{num_states} ~{assembly}
     }

    output {
       File dense_bed = "output/~{cell_type}_~{num_states}_dense.bed.gz"
       File emissions_png = "output/emissions_~{num_states}.png"
       File emissions_svg = "output/emissions_~{num_states}.svg"
       File emissions_txt = "output/emissions_~{num_states}.txt"
       File expanded_bed = "output/~{cell_type}_~{num_states}_expanded.bed.gz"
       File model = "output/model_~{num_states}.txt"
       File overlap_png = "output/~{cell_type}_~{num_states}_overlap.png"
       File overlap_svg = "output/~{cell_type}_~{num_states}_overlap.svg"
       File overlap_txt = "output/~{cell_type}_~{num_states}_overlap.txt"
       File refseq_tes_neighborhood_png = "output/~{cell_type}_~{num_states}_RefSeqTES_neighborhood.png"
       File refseq_tes_neighborhood_svg = "output/~{cell_type}_~{num_states}_RefSeqTES_neighborhood.svg"
       File refseq_tes_neighborhood_txt = "output/~{cell_type}_~{num_states}_RefSeqTES_neighborhood.txt"
       File refseq_tss_neighborhood_png = "output/~{cell_type}_~{num_states}_RefSeqTSS_neighborhood.png"
       File refseq_tss_neighborhood_svg = "output/~{cell_type}_~{num_states}_RefSeqTSS_neighborhood.svg"
       File refseq_tss_neighborhood_txt = "output/~{cell_type}_~{num_states}_RefSeqTSS_neighborhood.txt"
       File segments_bed = "output/~{cell_type}_~{num_states}_segments.bed.gz"
       File transitions_png = "output/transitions_~{num_states}.png"
       File transitions_svg = "output/transitions_~{num_states}.svg"
       File transitions_txt = "output/transitions_~{num_states}.txt"
       File webpage = "output/webpage_~{num_states}.html"
    }

    runtime {
        cpu: 8
        memory: "30 GB"
        disks: "local-disk 250 SSD"
    }
}
