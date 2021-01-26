import json

import pytest
from typer.testing import CliRunner

from chromhmm_pipeline.make_cellmarkfiletable import (
    BamPairWithMetadata,
    InputFile,
    app,
    process_row,
    process_rows,
)

runner = CliRunner()


@pytest.mark.filesystem
def test_app(tmp_path):
    fake_input = tmp_path / "input.json"
    fake_data = [
        {
            "bam": "/foo/bar.bam",
            "control_bam": "/bar/baz.bam",
            "chromatin_mark": "mark",
            "cell_type": "lung",
        },
    ]
    fake_input.write_text(json.dumps(fake_data))
    result = runner.invoke(
        app, ["-i", str(fake_input), "-o", str(tmp_path / "output.txt")]
    )
    assert result.exit_code == 0


def test_process_row():
    row = BamPairWithMetadata(
        bam="/foo/bar.bam",
        control_bam="/baz/qux.bam",
        chromatin_mark="H3K27ac",
        cell_type="K562",
    )
    result = process_row(row)
    assert result == ["K562", "H3K27ac", "bar.bam", "qux.bam"]


def test_process_rows():
    input_file = InputFile.parse_obj(
        [
            {
                "bam": "/foo/bar.bam",
                "control_bam": "/bar/baz.bam",
                "chromatin_mark": "mark",
                "cell_type": "lung",
            },
            {
                "bam": "/quux/corge.bam",
                "control_bam": "cool.bam",
                "chromatin_mark": "histone",
                "cell_type": "liver",
            },
        ]
    )
    result = process_rows(input_file)
    assert len(result) == 2
