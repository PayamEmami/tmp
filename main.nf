#!/usr/bin/env nextflow


process convertToUpper {

    output:
    stdout result

    """
    cat $PWD
    """
}

result.subscribe {
    println it.trim()
}
