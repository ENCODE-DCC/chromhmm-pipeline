version 1.0

import "../../../chromhmm.wdl" as chromhmm

workflow test_learn_model {
    input {
        Array[File] binarized
        String assembly
        Int num_states
        Int bin_size
    }

    call chromhmm.learn_model { input:
        binarized = binarized,
        assembly = assembly,
        num_states = num_states,
        bin_size = bin_size,
    }
}
