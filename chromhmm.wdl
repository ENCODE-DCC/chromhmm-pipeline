# Maintainer: Otto Jolanki

#CAPER docker quay.io/encode-dcc/chromhmm-pipeline:template
#CAPER singularity docker://quay.io/encode-dcc/chromhmm-pipeline:template

workflow chromhmm {
    #inputs if im using the auto find script, requiring this
    # String epigenomics_accession

    # # if i have already generated markTable
    File markTable
    Array[File] bams # be able to generate this from markTable

    # # If I already have the binarized, just straight to learn?

    # File[Array]? binarized

    Int states = 10
    Int bin_size = 200

    call binarize {
        input:
            bams = bams,
            markTable = markTable,
            bin_size = bin_size
    }

    call model {
        input:
            binarized = binarize.binarized,
            bin_size = bin_size,
            states = states
    }

    # if (!defined(markTable)) {
    #     call map_experiment {
    #         input: accession = epigenomics_accession
    #     }
    # }

    # if (defined(markTable)) {
    #     if (!defined(bams)) {
    #         call files_from_markTable {
    #             input: markTable = markTable
    #         }
    #     }
    # }
    #     markTable = select_first([markTable, map_experiment.markTable])
#     bams = select_first([bams, map_experiment.bams, files_from_markTable.bams])
#     # at this point, we have markTable and the bams
#     if (!defined(binarized)) {
#         call binarize {
#             input:
#                 bams = bams,
#                 markTable = markTable,
#                 bin_size = bin_size
#         }
#         binarized = binarized
#     }
#     call model {
#         input:
#             binarized = binarized,
#             bin_size = bin_size,
#             states = states
#     }

}

task binarize {
    Array[File] bams # when interpolated, will this give me a directory or a list?
    File markTable

     Int bin_size
     
    command {
        mkdir /bams
        mv ${bams sep=' /bams/; mv '} /bams/
        java -Xmx16G -jar /ChromHMM/ChromHMM.jar BinarizeBam -b ${bin_size} -gzip /ChromHMM/CHROMSIZES/hg38.txt /bams/ markTable binarize
    }

    output {
        Array[File] binarized = glob("binarize/*")
    }

     # runs fine at 128, might as well go double to play it safe
    runtime {
        cpu: 4
        memory: "20 GB"
        disks: "local-disk 250 SSD"
    }
}

task model {
    Array[File] binarized
     
     Int bin_size
     Int states
    command {
        mkdir /binarized
        mv ${bams sep=' /binarized/; mv '} /binarized/
        java -Xmx18G -jar /ChromHMM/ChromHMM.jar LearnModel -b ${bin_size} -p 0 /binarized OUTPUT ${states} hg38
     }

    output {
       Array[File] out = glob("OUTPUT/*")
    }

     # when I gave it 100 processors, load doesnt really break 7
    runtime {
        cpu: 8
        memory: "20 GB"
        disks: "local-disk 250 SSD"
    }
}