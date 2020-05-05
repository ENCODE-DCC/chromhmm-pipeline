workflow chromhmm {
	#inputs if im using the auto find script
	String epigenomics_accession

	# if i have already generated markTable
	File markTable?
	Array[File] bams? # be able to generate this from markTable

	# If I already have the binarized, just straight to learn?

    File[Array] binarized?

	Int states = 10
	Int bin_size = 200

    if (!defined(markTable)){
        call map_experiment{
            accession: epigenomics_accession
        }
        markTable = map_experiment.markTable
        bams = map_experiment.bams
    } else {
        if (!defined(bams)){
            call files_from_markTable{
                markTable: markTable
            }
            bams = files_from_markTable.bams
        }
    }
    # at this point, we have markTable and the bams
    if (!defined(binarized)){
        call binarize{
        bams: bams
        markTable: markTable
        bin_size: bin_size
        }
        binarized = binarized
    }
    call model {
            binarized:binarized
            bin_size: bin_size
            states:states
    }

}

task map_experiment {
    String accession

    command {
        node node/app.js ${accession}
    }

    output {
       File markTable = glob("markTable")[0]
	   # Is this valid?
        Array[File] bams = read_lines("fileList")
    }

	# the node script pretty much needs nothing to run (raspberry pi handles it fine), this should be more than enough
    # doing 10gb since im only manipulating text files, no data being pulled
	# if there is a way to speed up api calls to ENCODE portal, that should probably go here
    runtime {
        cpu: 1
        memory: "4 GB"
        disks: "local-disk 10 SSD"
    }
}

task files_from_markTable {
    File markTable
    command {
        cat markTable| cut -f3-4| sed "s/	/\\
/g" | cut -d . -f1 | sort | uniq | while read line; do curl https://www.encodeproject.org/files/$line/\?format=json | jq -r ".s3_uri"; done > fileList
    }
    output {
        # Is this valid?
        Array[File] bams = read_lines("fileList")
    }
    runtime {
        cpu: 1
        memory: "4GB"
        disks: "local-disk 10 SSD"
    }

}

task binarize {
    Array[File] bams # when interpolated, will this give me a directory or a list?
	File markTable

	Int bin_size
	
    command {
        java -Xmx16G -jar ChromHMM/ChromHMM.jar BinarizeBam -b ${bin_size} ChromHMM/CHROMSIZES/hg38.txt ${bams} markTable binarize
    }

    output {
	   Array[File] binarized = glob("binarize/*")
    }

	# runs fine at 128, might as well go double to play it safe
    runtime {
        cpu: 4
        memory: "20 GB"
        disks: "local-disk 256 SSD"
    }
}

task model {
    Array[File] binarized
	
	Int bin_size
	Int states
    command {
        java -Xmx18G -jar ChromHMM/ChromHMM.jar LearnModel -b ${bin_size} -p 0 binarize OUTPUT ${states} hg38
	}

    output {
       Array[File] = glob("OUTPUT/*")
    }

	# when i gave it infinite processors, load doesnt really break 7
    runtime {
        cpu: 8
        memory: "20 GB"
        disks: "local-disk 256 SSD"
    }
}