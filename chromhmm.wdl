# Maintainer: Otto Jolanki

#CAPER docker quay.io/encode-dcc/chromhmm-pipeline:template
#CAPER singularity docker://quay.io/encode-dcc/chromhmm-pipeline:template

workflow chromhmm {
    #inputs if im using the auto find script, requiring this
    String epigenomics_accession

    # # if i have already generated markTable
    # File? markTable
    # Array[File]? bams # be able to generate this from markTable

    # # If I already have the binarized, just straight to learn?

    # File[Array]? binarized

    Int states = 10
    Int bin_size = 200

    call map_experiment {
            input: accession = epigenomics_accession
    }

    call binarize {
        input:
            bams = map_experiment.bams,
            markTable = map_experiment.markTable,
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

task map_experiment {
    String accession

    command {
        node $(which app.js) ${accession}
        mkdir bams
        cat fileList | while read line; do aws s3 cp $line bams/; done
    }

    output {
       File markTable = glob("markTable")[0]
        # Is this needed if I never use it outside of task?
        File fileList =  glob("fileList")[0]
        Array[File] bams = glob("bams/*")
    }

    runtime {
        cpu: 2
        memory: "8 GB"
        disks: "local-disk 250 SSD"
    }
}

task files_from_markTable {
    File markTable
    command {
        cat markTable| cut -f3-4| sed "s/     /\\
/g" | cut -d . -f1 | sort | uniq | while read line; do curl https://www.encodeproject.org/files/$line/\?format=json | jq -r ".s3_uri"; done > fileList
        mkdir bams
        cat fileList | while read line; do aws s3 cp $line bams/; done
    }
    output {
        # Is this needed if I never use it outside of task?
        File fileList =  glob("fileList")[0]
        Array[File] bams = glob("bams/*")
    }
    runtime {
        cpu: 2
        memory: "8GB"
        disks: "local-disk 250 SSD"
    }

}

task binarize {
    Array[File] bams # when interpolated, will this give me a directory or a list?
    File markTable

     Int bin_size
     
    command {
        java -Xmx16G -jar $(which ChromHMM.jar) BinarizeBam -b ${bin_size} ChromHMM/CHROMSIZES/hg38.txt ${bams} markTable binarize
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
        java -Xmx18G -jar $(which ChromHMM.jar) LearnModel -b ${bin_size} -p 0 ${binarized} OUTPUT ${states} hg38
     }

    output {
       Array[File] out = glob("OUTPUT/*")
    }

     # when i gave it infinite processors, load doesnt really break 7
    runtime {
        cpu: 8
        memory: "20 GB"
        disks: "local-disk 250 SSD"
    }
}