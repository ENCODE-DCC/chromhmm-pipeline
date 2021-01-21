version 1.0
# Maintainer: Keshav Gurushankar

#CAPER docker quay.io/encode-dcc/chromhmm-pipeline:1.0
#CAPER singularity docker://quay.io/encode-dcc/chromhmm-pipeline:1.0

workflow chromhmm {
    # # if i have already generated markTable
    File markTable
    File chrom_sizes
    Array[File] bams # be able to generate this from markTable
    Int states = 10
    Int bin_size = 200

    call binarize {
        input:
            bams = bams,
            markTable = markTable,
            bin_size = bin_size,
            chrom_sizes = chrom_sizes
    }

    call model {
        input:
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

task make_cell_mark_file_table {
    input {
        Array[BamPairWithMetadata] bams
    }

    command {
        python "$(which make_cellmarkfiletable.py)" -i ~{write_json(bams)} -o "cellmarkfiletable"
    }
    output {
        File cellmarkfiletable = "cellmarkfiletable.tsv"
    }
}

task binarize {
    Array[File] bams # when interpolated, will this give me a directory or a list?
    File chrom_sizes
    File markTable
    Int bin_size

    command {
        mkdir /bams
        mv ~{sep=' /bams/; mv ' bams} /bams/
        java -Xmx20G -jar /ChromHMM/ChromHMM.jar BinarizeBam -b ~{bin_size} -gzip ~{chrom_sizes} /bams/ ~{markTable} binarize
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
