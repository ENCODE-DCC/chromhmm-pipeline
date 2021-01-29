import json
from enum import Enum
from functools import cache
from pathlib import Path
from typing import Any, Dict, List
from urllib.parse import urljoin

import httpx
import typer

from chromhmm_pipeline.make_cellmarkfiletable import BamPairWithMetadata

app = typer.Typer()


TARGETS = ["H3K27ac", "H3K27me3", "H3K36me3", "H3K4me1", "H3K4me3", "H3K9me3"]

PORTAL_URL = "https://www.encodeproject.org"


class Assembly(Enum):
    GRCh38 = "GRCh38"
    mm10 = "mm10"


ASSEMBLY_TO_CHROM_SIZES_URL = {
    Assembly.GRCh38: "/files/GRCh38_no_alt_analysis_set_GCA_000001405.15/@@download/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta.gz",
    Assembly.mm10: "/files/mm10_no_alt.chrom.sizes/@@download/mm10_no_alt.chrom.sizes.tsv",
}


@cache
def get_portal_json(relative_path: str) -> Dict[str, Any]:
    return httpx.get(urljoin(PORTAL_URL, relative_path)).json()


def get_input_json(
    assembly: Assembly, bam_pairs: List[BamPairWithMetadata]
) -> Dict[str, Any]:
    chrom_sizes = urljoin(PORTAL_URL, ASSEMBLY_TO_CHROM_SIZES_URL[assembly])
    chromhmm_assembly = get_chromhmm_assembly(assembly)
    return {
        "chromhmm.assembly": chromhmm_assembly,
        "chromhmm.bam_pairs": [bam_pair.dict() for bam_pair in bam_pairs],
        "chromhmm.chrom_sizes": chrom_sizes,
    }


def select_bam(bams: List[Dict[str, Any]]) -> Dict[str, Any]:
    current_best_bam = None
    max_mapped = -1
    max_award = ""
    for bam in bams:
        mapping_qcs = [
            get_portal_json(i)
            for i in bam["quality_metrics"]
            if (
                i.startswith("/samtools-flagstats")
                or i.startswith("/chip-alignment-quality-metrics")
            )
        ]
        filtered_qcs = [
            i for i in mapping_qcs if i.get("processing_stage") != "unfiltered"
        ]
        if len(filtered_qcs) != 1:
            raise ValueError(
                f"Expected one mapping quality metric for file {bam['@id']}, found {len(mapping_qcs)}"
            )
        qc = filtered_qcs[0]
        bam_mapped = qc.get("mapped_reads") or qc["mapped"]
        bam_award = get_portal_json(bam["award"])["rfa"]
        if bam_mapped > max_mapped and bam_award > max_award:
            current_best_bam = bam
            max_mapped = bam_mapped
            max_award = bam_award
    if current_best_bam is None:
        raise ValueError("Could not find best bam")
    return current_best_bam


def make_input_json(
    reference_epigenome: Dict[str, Any], assembly: Assembly
) -> Dict[str, Any]:
    cell_type = reference_epigenome["biosample_ontology"][0]["term_name"]
    bam_pairs = []
    for dataset in reference_epigenome["related_datasets"]:
        if (
            dataset["assay_title"] == "Histone ChIP-seq"
            and dataset["target"]["label"] in TARGETS
        ):
            best_bam = get_bams_and_select_best(dataset["files"], assembly)
            control_files = []
            possible_control_ids = [i["@id"] for i in dataset["possible_controls"]]
            # files not embedded in possible_controls.files
            for i in reference_epigenome["related_datasets"]:
                if i["@id"] in possible_control_ids:
                    control_files.extend(i["files"])
            best_control_bam = get_bams_and_select_best(control_files, assembly)
            bam_pairs.append(
                BamPairWithMetadata(
                    bam=get_http_url_from_file(best_bam),
                    control_bam=get_http_url_from_file(best_control_bam),
                    cell_type=cell_type,
                    chromatin_mark=dataset["target"]["label"],
                )
            )
    return get_input_json(bam_pairs=bam_pairs, assembly=assembly)


def get_chromhmm_assembly(assembly: Assembly) -> str:
    if assembly.name == "GRCh38":
        return "hg38"
    return assembly.name


def get_bams_and_select_best(
    files: List[Dict[str, Any]], assembly: Assembly
) -> Dict[str, Any]:
    possible_bams = []
    for file in files:
        if (
            file["file_format"] == "bam"
            and file["output_type"] == "alignments"
            and file["status"] == "released"
            and file["assembly"] == assembly.value
        ):
            possible_bams.append(file)
    if not possible_bams:
        raise ValueError("Cannot select a possible bam with no candidates found")
    best_bam = select_bam(possible_bams)
    return best_bam


def get_http_url_from_file(file: Dict[str, Any]) -> str:
    return urljoin(PORTAL_URL, file["href"])


def write_output_file(output_file_path: Path, data: Dict[str, Any]) -> None:
    output_file_path.write_text(json.dumps(data, indent=2, sort_keys=True))


@app.command(context_settings={"help_option_names": ["-h", "--help"]})
def main(
    reference_epigenome_accession: str = typer.Argument(
        ...,
        help="Accession of a reference epigenome on the ENCODE portal, e.g. ENCSR867OGI",
    ),
    assembly: Assembly = typer.Argument(
        ..., case_sensitive=False, help="Name of the genome assembly"
    ),
    output_file_path: Path = typer.Argument(
        ..., help="Name of file to write pipeline input JSON to"
    ),
) -> None:
    """
    Generate input JSON file for `chromhmm.wdl` from a reference epigenome on the ENCODE
    portal, see https://www.encodeproject.org/reference-epigenomes/.
    """
    reference_epigenome = get_portal_json(
        f"reference-epigenomes/{reference_epigenome_accession}"
    )
    input_json = make_input_json(reference_epigenome, assembly)
    write_output_file(output_file_path, input_json)


if __name__ == "__main__":
    app()
