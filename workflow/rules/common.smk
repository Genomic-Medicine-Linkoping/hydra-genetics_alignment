__author__ = "Jonas Almlöf"
__copyright__ = "Copyright 2021, Jonas Almlöf"
__email__ = "jonas.almlof@scilifelab.uu.se"
__license__ = "GPL-3"


import pandas
import yaml
from snakemake.utils import validate
from snakemake.utils import min_version

from hydra_genetics.utils.resources import load_resources
from hydra_genetics.utils.misc import extract_chr
from hydra_genetics.utils.units import *
from hydra_genetics.utils.samples import *


min_version("6.10")


### Set and validate config file


configfile: "config.yaml"


validate(config, schema="../schemas/config.schema.yaml")
config = load_resources(config, config["resources"])
validate(config, schema="../schemas/resources.schema.yaml")


### Read and validate samples file

samples = pandas.read_table(config["samples"], dtype=str).set_index("sample", drop=False)
validate(samples, schema="../schemas/samples.schema.yaml")

### Read and validate units file

units = (
    pandas.read_table(config["units"], dtype=str)
    .set_index(["sample", "type", "flowcell", "lane", "barcode"], drop=False)
    .sort_index()
)
validate(units, schema="../schemas/units.schema.yaml")

### Validate reference schemas

sample_types = set().union(*[get_unit_types(units, sample) for sample in get_samples(samples)])
if not sample_types.isdisjoint(set(["N", "T"])):
    validate(config, schema="../schemas/config.dna_reference.schema.yaml")
if not sample_types.isdisjoint(set(["R"])):
    validate(config, schema="../schemas/config.rna_reference.schema.yaml")

### Set wildcard constraints


wildcard_constraints:
    barcode="[A-Z+]+",
    chr="[^_]+",
    flowcell="[A-Z0-9]+",
    lane="L[0-9]+",
    sample="|".join(get_samples(samples)),
    type="N|T|R",


if config.get("trimmer_software", "None") == "fastp_pe":
    alignment_input = lambda wilcards: [
        "prealignment/fastp_pe/{sample}_{flowcell}_{lane}_{barcode}_{type}_fastq1.fastq.gz",
        "prealignment/fastp_pe/{sample}_{flowcell}_{lane}_{barcode}_{type}_fastq2.fastq.gz",
    ]
elif config.get("trimmer_software", "None") == "None":
    alignment_input = lambda wildcards: [
        get_fastq_file(units, wildcards, "fastq1"),
        get_fastq_file(units, wildcards, "fastq2"),
    ]


def generate_read_group(wildcards):
    return "-R '@RG\\tID:{}\\tSM:{}\\tPL:{}\\tPU:{}\\tLB:{}' -v 1 ".format(
        "{}_{}.{}.{}".format(wildcards.sample, wildcards.type, wildcards.lane, wildcards.barcode),
        "{}_{}".format(wildcards.sample, wildcards.type),
        get_unit_platform(units, wildcards),
        "{}.{}.{}".format(wildcards.flowcell, wildcards.lane, wildcards.barcode),
        "{}_{}".format(wildcards.sample, wildcards.type),
    )


def compile_output_list(wildcards):
    files = {
        "alignment/samtools_merge_bam": [".bam"],
    }
    output_files = [
        "%s/%s_%s%s" % (prefix, sample, "N", suffix)
        for prefix in files.keys()
        for sample in get_samples(samples)
        if "N" in get_unit_types(units, sample)
        for suffix in files[prefix]
    ]
    files = {
        "alignment/star": [".bam", ".SJ.out.tab"],
    }
    output_files.append(
        [
            "%s/%s_%s%s" % (prefix, sample, "R", suffix)
            for prefix in files.keys()
            for sample in get_samples(samples)
            if "R" in get_unit_types(units, sample)
            for suffix in files[prefix]
        ]
    )
    return output_files
