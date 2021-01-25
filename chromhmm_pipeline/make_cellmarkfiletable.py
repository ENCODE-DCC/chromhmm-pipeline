import csv
from pathlib import Path
from typing import List, Optional

import typer
from pydantic import BaseModel

app = typer.Typer()


class BamPairWithMetadata(BaseModel):
    bam: str
    control_bam: Optional[str] = None
    cell_type: str
    chromatin_mark: str


class InputFile(BaseModel):
    """
    See https://github.com/samuelcolvin/pydantic/issues/675#issuecomment-513029543 for
    details on the __root__ trick, allows to directly parse List.
    """

    __root__: List[BamPairWithMetadata]

    @property
    def rows(self) -> List[BamPairWithMetadata]:
        return self.__root__


def process_row(bam_pair: BamPairWithMetadata) -> List[str]:
    bam_name = Path(bam_pair.bam).name
    control_bam_name = (
        Path(bam_pair.control_bam).name if bam_pair.control_bam is not None else ""
    )
    return [bam_pair.cell_type, bam_pair.chromatin_mark, bam_name, control_bam_name]


def process_rows(input_file: InputFile) -> List[List[str]]:
    return [process_row(row) for row in input_file.rows]


def write_output_file(rows: List[List[str]], output_path: Path) -> None:
    with output_path.open("w", newline="") as f:
        spamwriter = csv.writer(f, delimiter="\t")
        spamwriter.writerows(rows)


@app.command()
def main(
    input_file: Path = typer.Option(..., "-i", exists=True),
    output_path: Path = typer.Option(..., "-o"),
) -> None:
    data = InputFile.parse_file(input_file)
    rows = process_rows(data)
    write_output_file(rows, output_path)


if __name__ == "__main__":
    app()
